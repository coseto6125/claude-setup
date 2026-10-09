#!/usr/bin/env python3
"""
Static audit of a SKILL.md against the measurable rules.

usage: audit.py <SKILL.md | skill-dir> ...     one or more skills
       audit.py --all [<skills-root>]          every skill under the root
       audit.py spans <old> <new>              code spans a rewrite dropped

Rules it can decide from the file alone. Rule 1 (does the label get the skill
opened) and rule 5 (are the shortcuts blocked) need a behaviour run instead:
skills/validate-prompt-rules/route.sh.
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path

FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)
# `description:` is a plain scalar, or a `>-`/`|` block whose lines are indented.
DESCRIPTION = re.compile(r"^description:[ \t]*(?:([>|][-+]?)\s*)?(.*?)(?=^\S|\Z)", re.MULTILINE | re.DOTALL)
# CAPS that command, not CAPS that label a severity or an enum value.
SHOUT = re.compile(r"(?:^|[.!?—:]\s|\*\*)\s*(?:NEVER|ALWAYS|MUST|DO NOT|DON'T)\b")
OPENS_WITH_VERB = re.compile(r"^[A-Z][a-z]+(?:s|es)?\b")
# A measurement labelled `haiku` cannot be traced once the alias moves to the next release.
FAMILY = r"(?:haiku|sonnet|opus|fable|mythos)"
VERSION = r"\d+(?:[.-]\d+)*"
FULL_ID = re.compile(rf"\bclaude-{FAMILY}-{VERSION}\b", re.IGNORECASE)
# "Opus 5.5" names a version. "haiku 0/5" and "haiku 9%" are scores, not versions.
BARE_ALIAS = re.compile(rf"\b{FAMILY}\b(?!\s*-?\s*{VERSION}(?![\d/%]))", re.IGNORECASE)
# A run of N backticks closes on the next run of exactly N (a CommonMark code span).
INLINE_SPAN = re.compile(r"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)")
QUOTE_MARK = re.compile(r"^[ \t]{0,3}>[ \t]?")

BODY_MAX = 200          # every skill measured so far sits under this
DESC_MAX = 800          # a label longer than this carries body content
DESC_MIN = 105          # a label thinner than this needs a hard trigger
DENSE_BODY = 120        # long body with nothing beside it: rule 3 question


def audit(path: Path) -> list[str]:
    skill = path / "SKILL.md" if path.is_dir() else path
    if not skill.is_file():
        return [f"{path}: no SKILL.md"]

    text = skill.read_text(encoding="utf-8")
    match = FRONTMATTER.match(text)
    if match is None:
        return [f"{skill}: no frontmatter"]

    head, body = match.group(1), text[match.end():]
    found_desc = DESCRIPTION.search(head + "\n")
    desc = " ".join((found_desc.group(2) if found_desc else "").split()).strip("'\"")
    gated = "disable-model-invocation: true" in head
    root = skill.parent
    scripts = [p for p in root.rglob("*") if p.suffix in {".py", ".sh", ".ts", ".js"} and "__pycache__" not in str(p)]
    refs = [p for p in root.rglob("*.md") if p.name != "SKILL.md"]
    lines = body.count("\n")

    found = []
    if lines > BODY_MAX:
        found.append(f"rule 2: body is {lines} lines (>{BODY_MAX}). Move detail to a reference file the model opens on demand.")
    if lines > DENSE_BODY and not scripts and not refs:
        found.append(f"rule 3: {lines} lines with no script and no reference file. Check whether a fixed-answer step belongs in a script.")
    found.extend(f"rule 4: shouted command {hit.strip()!r}. State the consequence instead, unless this is a red line." for hit in SHOUT.findall(text))
    if len(desc) > DESC_MAX:
        found.append(f"rule 1: description is {len(desc)} chars (>{DESC_MAX}). A label says when to reach here; command tables belong in the body.")
    if len(desc) < DESC_MIN and not gated:
        found.append(f"rule 1: description is {len(desc)} chars and the skill is model-invocable. Either widen the trigger or set disable-model-invocation.")
    if desc and not gated and not OPENS_WITH_VERB.match(desc):
        found.append("rule 1: description opens with a noun phrase. Open with the verb that claims the work.")
    for line_no, alias in measured_aliases(text):
        found.append(f"rule 6: line {line_no} labels a measurement {alias!r}, an alias. Write the full model ID the run reported.")
    return [f"{skill.parent.name}: {f}" for f in found]


def measured_aliases(text: str) -> list[tuple[int, str]]:
    """(line, alias) for each `> Measured` blockquote that names a model family without a full ID."""
    # A fenced example of a bad label is documentation, not a measurement. Keep its line count.
    lines = CODE_BLOCK.sub(lambda m: "\n" * m.group(0).count("\n"), text).splitlines()
    found, i, n = [], 0, len(lines)
    while i < n:
        if not (QUOTE_MARK.match(lines[i]) and QUOTE_MARK.sub("", lines[i], count=1).startswith("Measured")):
            i += 1
            continue
        j = i
        while j < n and QUOTE_MARK.match(lines[j]):
            j += 1
        # Strip the `>` markers before joining, so "Opus" on one line and "5.5" on the next still read as a version.
        prose = " ".join(QUOTE_MARK.sub("", line, count=1) for line in lines[i:j])
        block = FULL_ID.sub("", INLINE_SPAN.sub("", prose))
        if hit := BARE_ALIAS.search(block):
            found.append((i + 1, hit.group(0)))
        i = j
    return found


def code_spans(text: str) -> set[str]:
    """Inline code spans, plus each non-blank line of a fenced block."""
    spans = {m.group(2).strip() for m in INLINE_SPAN.finditer(CODE_BLOCK.sub("", text))}
    for _, block in CODE_BLOCK.findall(text):
        spans.update(stripped for line in block.splitlines() if (stripped := line.strip()))
    return spans


def lost_spans(old: Path, new: Path) -> list[str]:
    """Code spans in `old` that `new` no longer carries anywhere."""
    gone = code_spans(old.read_text(encoding="utf-8")) - code_spans(new.read_text(encoding="utf-8"))
    return [f"spans: `{span}` is in {old} but not in {new}. Move it into the rule it serves, or confirm it is dead." for span in sorted(gone)]


# A routing sentence names a skill; a usage sentence names a command or an agent
# type. Only the first shape is a cross-reference that can dangle.

# A fence opens with 3+ backticks or tildes plus any info string, and closes on the same run.
CODE_BLOCK = re.compile(r"^[ \t]{0,3}(`{3,}|~{3,})[^\n]*\n(.*?)^[ \t]{0,3}\1[ \t]*$", re.MULTILINE | re.DOTALL)
# A word followed by `.`, `/` or `-` is a file or a path (`cat draft.md`, `git foo-bar.md`), not a subcommand.
USAGE = re.compile(r"^([a-z][a-z0-9_-]{2,})\s+([a-z][a-z0-9-]{2,})(?![\w./-])(?:\s+([a-z][a-z0-9-]{2,}))?", re.MULTILINE)
# Orca overwrites these from its upstream repo, so a finding here is not actionable.
UPSTREAM = {"computer-use", "orca-cli", "orchestration"}


def help_subcommands(argv: list[str]) -> set[str] | None:
    """Subcommand names in `argv --help`, or None when the tool cannot answer."""
    try:
        # argv[0] comes from a local SKILL.md and passed shutil.which; only `--help` runs.
        proc = subprocess.run([*argv, "--help"], capture_output=True, text=True, timeout=15, check=False)  # ruff: ignore[subprocess-without-shell-equals-true]
    except (OSError, subprocess.SubprocessError):
        return None
    text = proc.stdout + proc.stderr
    if not text.strip():
        return None
    names = set(re.findall(r"^ {2,6}([a-z][a-z0-9-]{2,})(?:\s{2,}|,|$)", text, re.MULTILINE))
    names |= set((re.findall(r"^\s*\{([a-z0-9,|-]+)\}", text, re.MULTILINE) and
                 re.findall(r"[a-z][a-z0-9-]{2,}", re.search(r"^\s*\{([a-z0-9,|-]+)\}", text, re.MULTILINE).group(1))) or [])
    names.discard(Path(argv[0]).name)  # an Examples line that repeats the tool's own name
    return names or None


def drift(paths: list[Path]) -> list[str]:
    """Commands a SKILL.md documents that its CLI does not have, and the reverse."""
    found = []
    for path in paths:
        skill = path.parent.name
        if skill in UPSTREAM:
            continue
        documented: dict[str, set[str]] = {}
        for _, block in CODE_BLOCK.findall(path.read_text(encoding="utf-8")):
            for tool, sub, _ in USAGE.findall(block):
                if shutil.which(tool):
                    documented.setdefault(tool, set()).add(sub)
        for tool, subs in documented.items():
            real = help_subcommands([tool])
            if real is None:
                # A tool with no subcommand list (setsid, jq, curl) has nothing to drift against.
                continue
            found.extend(f"{skill}: documents `{tool} {sub}`, which `{tool} --help` does not list. Rerun the help and fix the line." for sub in sorted(subs - real))
            # The reverse direction only matters for a skill that acts as a cheat sheet:
            # it copied the help output, so it inherits the duty to stay in sync. A skill
            # that names two commands in passing owes nothing to the rest of the CLI.
            missing = sorted(real - subs)
            if len(subs) >= 5 and missing:
                found.append(
                    f"{skill}: documents {len(subs)} `{tool}` commands and misses {len(missing)} "
                    f"({', '.join(missing[:4])}…). Point at `{tool} --help` instead of keeping a copy."
                )
    return found


REF = re.compile(
    r"(?:hand off to|handed off to)\s+`([a-z][a-z0-9-]+)`"
    r"|`([a-z][a-z0-9-]+)`\s+(?:skill\b|instead\b)"
    r"|(?:the|this)\s+`([a-z][a-z0-9-]+)`\s+skill"
)


def skill_state(root: Path) -> tuple[set[str], set[str]]:
    """Names that exist under `root`, and the subset the model cannot invoke."""
    live, gated = set(), set()
    for d in root.iterdir():
        skill = d / "SKILL.md"
        if not skill.is_file():
            continue
        live.add(d.name)
        if "disable-model-invocation: true" in skill.read_text(encoding="utf-8"):
            gated.add(d.name)
    return live, gated


BUNDLED = Path.home() / ".cache/claude-tmp"


def bundled_skills(base: Path = BUNDLED) -> set[str]:
    """
    Skills the CLI ships, by the directory it extracts under `<base>/<uid>/bundled-skills/<version>/<hash>/`.

    The SKILL.md body stays inside the CLI binary, so only the directory name is on disk.
    """
    # Older CLI versions leave their directories behind. Only the newest version is the live set.
    versions = [v for v in base.glob("*/bundled-skills/*") if v.is_dir() and re.fullmatch(r"\d+(?:\.\d+)*", v.name)]
    if not versions:
        return set()
    newest = max(versions, key=lambda v: tuple(int(x) for x in v.name.split(".")))
    return {p.name for p in newest.glob("*/*") if p.is_dir()}


def refs(paths: list[Path], root: Path, bundled: set[str] | None = None) -> list[str]:
    """Cross-references that point at a skill which is missing or not invocable."""
    live, gated = skill_state(root)
    live |= bundled_skills() if bundled is None else bundled
    found = []
    for path in paths:
        if not path.is_file():
            continue
        where = path.parent.name if path.parent != path.parent.parent else path.name
        named = {g for m in REF.finditer(path.read_text(encoding="utf-8")) for g in m.groups() if g}
        for name in sorted(named):
            if not re.fullmatch(r"[a-z]+(?:-[a-z]+)+", name) or name == where:
                continue
            if name not in live:
                found.append(f"{where}: points at `{name}`, which is not a skill here. Update or drop the reference.")
            elif name in gated:
                found.append(f"{where}: points at `{name}`, which the user invokes by hand. The model cannot route there.")
    return found


EXEMPTIONS = Path(__file__).parent / "audit-exemptions.md"


def exempt() -> set[tuple[str, str]]:
    """(skill, rule) pairs a human already judged and wrote a reason for."""
    if not EXEMPTIONS.is_file():
        return set()
    pairs = set()
    for line in EXEMPTIONS.read_text(encoding="utf-8").splitlines():
        parts = [p.strip() for p in line.split("|")]
        if len(parts) == 3 and parts[1].startswith("rule"):
            pairs.add((parts[0], parts[1]))
    return pairs


def drop_exempt(findings: list[str]) -> tuple[list[str], int]:
    """Split findings into the ones to report and the count already accounted for."""
    known, kept = exempt(), []
    held = 0
    for finding in findings:
        skill, _, rest = finding.partition(": ")
        rule = rest.split(":", 1)[0].strip()
        if (skill, rule) in known:
            held += 1
        else:
            kept.append(finding)
    return kept, held


def main(argv: list[str]) -> int:
    if argv and argv[0] == "spans":
        if len(argv) != 3 or not all(Path(a).is_file() for a in argv[1:]):
            print("usage: audit.py spans <old file> <new file>")
            return 2
        findings = lost_spans(Path(argv[1]), Path(argv[2]))
        print("\n".join(findings) if findings else "clean")
        return 1 if findings else 0
    if argv and argv[0] == "drift":
        base = Path(argv[1]) if len(argv) > 1 else Path.home() / ".claude/skills"
        findings = drift(sorted(base.glob("*/SKILL.md")))
    elif argv and argv[0] == "refs":
        base = Path(argv[1]) if len(argv) > 1 else Path.home() / ".claude/skills"
        targets = sorted(base.glob("*/SKILL.md"))
        if len(argv) == 1:  # the real tree also carries the always-loaded file
            targets.append(Path.home() / ".claude/CLAUDE.md")
        findings = refs(targets, base)
    elif argv and argv[0] == "--all":
        base = Path(argv[1]) if len(argv) > 1 else Path.home() / ".claude/skills"
        findings = [f for t in sorted(p for p in base.iterdir() if (p / "SKILL.md").is_file()) for f in audit(t)]
    elif argv:
        base = Path(argv[0])
        base = base.parent if base.name == "SKILL.md" else base
        findings = [f for t in [Path(a) for a in argv] for f in audit(t)]
        findings += refs([Path(a) if Path(a).name == "SKILL.md" else Path(a) / "SKILL.md" for a in argv], base.parent)
    else:
        print(__doc__)
        return 2

    findings, held = drop_exempt(findings)
    if findings:
        print("\n".join(findings))
    else:
        print(f"clean ({held} exempt)" if held else "clean")
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
