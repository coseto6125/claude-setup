#!/usr/bin/env python3
"""Static audit of a SKILL.md against the measurable rules.

usage: audit.py <SKILL.md | skill-dir> ...     one or more skills
       audit.py --all [<skills-root>]          every skill under the root

Rules it can decide from the file alone. Rule 1 (does the label get the skill
opened) and rule 5 (are the shortcuts blocked) need a behaviour run instead:
skills/validate-prompt-rules/route.sh.
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path

FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.S)
# `description:` is a plain scalar, or a `>-`/`|` block whose lines are indented.
DESCRIPTION = re.compile(r"^description:[ \t]*(?:([>|][-+]?)\s*)?(.*?)(?=^\S|\Z)", re.M | re.S)
# CAPS that command, not CAPS that label a severity or an enum value.
SHOUT = re.compile(r"(?:^|[.!?—:]\s|\*\*)\s*(?:NEVER|ALWAYS|MUST|DO NOT|DON'T)\b")
OPENS_WITH_VERB = re.compile(r"^[A-Z][a-z]+(?:s|es)?\b")

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
    for hit in SHOUT.findall(text):
        found.append(f"rule 4: shouted command {hit.strip()!r}. State the consequence instead, unless this is a red line.")
    if len(desc) > DESC_MAX:
        found.append(f"rule 1: description is {len(desc)} chars (>{DESC_MAX}). A label says when to reach here; command tables belong in the body.")
    if len(desc) < DESC_MIN and not gated:
        found.append(f"rule 1: description is {len(desc)} chars and the skill is model-invocable. Either widen the trigger or set disable-model-invocation.")
    if desc and not gated and not OPENS_WITH_VERB.match(desc):
        found.append("rule 1: description opens with a noun phrase. Open with the verb that claims the work.")
    return [f"{skill.parent.name}: {f}" for f in found]


# A routing sentence names a skill; a usage sentence names a command or an agent
# type. Only the first shape is a cross-reference that can dangle.

CODE_BLOCK = re.compile(r"```[a-z]*\n(.*?)```", re.S)
USAGE = re.compile(r"^([a-z][a-z0-9_-]{2,})\s+([a-z][a-z0-9-]{2,})(?:\s+([a-z][a-z0-9-]{2,}))?", re.M)
# Orca overwrites these from its upstream repo, so a finding here is not actionable.
UPSTREAM = {"computer-use", "orca-cli", "orchestration"}


def help_subcommands(argv: list[str]) -> set[str] | None:
    """Subcommand names in `argv --help`, or None when the tool cannot answer."""
    try:
        proc = subprocess.run([*argv, "--help"], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError):
        return None
    text = proc.stdout + proc.stderr
    if not text.strip():
        return None
    names = set(re.findall(r"^ {2,6}([a-z][a-z0-9-]{2,})(?:\s{2,}|,|$)", text, re.M))
    names |= set(re.findall(r"^\s*\{([a-z0-9,|-]+)\}", text, re.M) and
                 re.findall(r"[a-z][a-z0-9-]{2,}", re.search(r"^\s*\{([a-z0-9,|-]+)\}", text, re.M).group(1)) or [])
    return names or None


def drift(paths: list[Path]) -> list[str]:
    """Commands a SKILL.md documents that its CLI does not have, and the reverse."""
    found = []
    for path in paths:
        skill = path.parent.name
        if skill in UPSTREAM:
            continue
        documented: dict[str, set[str]] = {}
        for block in CODE_BLOCK.findall(path.read_text(encoding="utf-8")):
            for tool, sub, _ in USAGE.findall(block):
                if shutil.which(tool):
                    documented.setdefault(tool, set()).add(sub)
        for tool, subs in documented.items():
            real = help_subcommands([tool])
            if real is None:
                found.append(f"{skill}: `{tool} --help` says nothing parseable. Check the tool by hand.")
                continue
            for sub in sorted(subs - real):
                found.append(f"{skill}: documents `{tool} {sub}`, which `{tool} --help` does not list. Rerun the help and fix the line.")
            for sub in sorted(real - subs):
                found.append(f"{skill}: `{tool} {sub}` exists and the skill never mentions it. Point at `{tool} --help` instead of listing commands.")
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


def refs(paths: list[Path], root: Path) -> list[str]:
    """Cross-references that point at a skill which is missing or not invocable."""
    live, gated = skill_state(root)
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


def main(argv: list[str]) -> int:
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

    print("\n".join(findings) if findings else "clean")
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
