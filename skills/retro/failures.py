#!/usr/bin/env python3
"""
Count tool failures across the sessions of one Claude Code project.

usage: failures.py [<project-dir>] [--session ID] [--min-sessions N]

<project-dir>   ~/.claude/projects/<dir>; default: the dir of the working directory
--session ID    keep only the signatures that failed in session ID
--min-sessions  keep only the signatures that failed in N sessions or more (default 2)

Prints TSV, one row per signature: the sessions of the project that show it, its
failures in the project, its failures in --session (`here`), and an example. With
--session the example comes from that session, so every row is a failure to quote.
A call the user rejected gets the signature `<tool>: rejected by user`, plus the
command head for Bash, and its example is the command.
A signature is the tool name plus a normalised error. For Bash it is the head of
the last command in the list and the exit code, so `grep (exit 1)` stays apart
from a real grep error. Sub-agent transcripts count toward their parent session.
hooks/loop-guard.py imports iter_failures, signature, PATH and DIGITS: keep their shapes.
"""

import json
import re
import shlex
import sys
from collections import defaultdict
from collections.abc import Iterator
from pathlib import Path

LIST_OPS = frozenset({";", "&&", "||", "&", ";;"})
NEVER_FAILS = frozenset({"echo", "printf", "true", ":"})
SKIP_SEGMENT = frozenset({"for", "case", "done", "fi", "esac", "}", ")"})
DROP_WORDS = frozenset(
    {"rtk", "bypass", "proxy", "sudo", "env", "timeout", "nice", "time", "exec"}
    | {"(", ")", "{", "!", "if", "then", "else", "elif", "while", "until", "do"}
)
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")
SUBCOMMAND = re.compile(r"[a-z][a-z0-9_-]*")
SUBCOMMAND_PROGRAMS = frozenset(
    {"git", "gh", "uv", "npm", "npx", "pnpm", "yarn", "bun", "cargo", "docker", "pip", "go"}
    | {"kubectl", "systemctl", "ecp", "orca", "claude", "codex", "mpm", "pyci-check", "command"}
)
EXIT_CODE = re.compile(r"(?:Error: )?Exit code (\d+)")
PATH = re.compile(r"(?:~|/)[\w.@+-]*(?:/[\w.@+-]*)+")
DIGITS = re.compile(r"\d+")
TAG = re.compile(r"</?tool_use_error>")
REJECTED = "The user doesn't want to proceed"


def project_dir(cwd: str) -> Path:
    """Map a working directory to its Claude Code transcript directory."""
    return Path.home() / ".claude" / "projects" / re.sub(r"[^A-Za-z0-9]", "-", cwd)


def segment_words(segment: list[str]) -> list[str]:
    """Return the command words of one list segment; empty for a loop or branch header and its end."""
    if not segment or segment[0] in SKIP_SEGMENT:
        return []
    segment = segment[: segment.index("|")] if "|" in segment else segment
    words = [w for w in segment if w not in DROP_WORDS and not ASSIGNMENT.match(w) and not w.isdigit()]
    return [] if words and words[0] in NEVER_FAILS else words


def command_head(command: str) -> str:
    """Return `program subcommand` of the last command in a shell list."""
    command = command.split("<<", 1)[0].replace("\n", " ; ")
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        tokens = command.split()
    segments = [[]]
    for token in tokens:
        if token in LIST_OPS:
            segments.append([])
        else:
            segments[-1].append(token)
    words = next(filter(None, map(segment_words, reversed(segments))), [])
    if not words:
        return "?"
    head = Path(words[0]).name
    if head in SUBCOMMAND_PROGRAMS and len(words) > 1 and SUBCOMMAND.fullmatch(words[1]):
        head += f" {words[1]}"
    return head


def result_text(content: object) -> str:
    """Flatten a tool_result content field to text."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(b.get("text", "") for b in content if isinstance(b, dict))
    return ""


def signature(name: str, tool_input: dict, text: str) -> tuple[str, str]:
    """Return (signature, example error line) for one failed tool call."""
    lines = [line.strip() for line in TAG.sub("", text).splitlines() if line.strip()]
    first = lines[0] if lines else ""
    if first.startswith(REJECTED):
        command = tool_input.get("command", "")
        head = f": {command_head(command)}" if name == "Bash" else ""
        return f"{name}: rejected by user{head}", " ".join(command.split())[:120]
    if name == "Bash" and (code := EXIT_CODE.fullmatch(first)):
        example = lines[-1] if len(lines) > 1 else ""
        return f"Bash: {command_head(tool_input.get('command', ''))} (exit {code[1]})", example[:120]
    message = DIGITS.sub("N", PATH.sub("<path>", first.removeprefix("Error: ")))
    return f"{name}: {message[:100]}", first[:120]


def iter_failures(path: Path) -> Iterator[tuple[str, str, str]]:
    """
    Read one transcript and yield its failed tool calls in order.

    Yields:
        (tool_use_id, signature, example error line) for each failed call.
    """
    calls: dict[str, tuple[str, dict]] = {}
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"tool_use' not in line:
                continue
            try:
                blocks = json.loads(line).get("message", {}).get("content")
            except (ValueError, AttributeError):
                continue
            if not isinstance(blocks, list):
                continue
            for block in blocks:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_use":
                    calls[block.get("id", "")] = (block.get("name", "?"), block.get("input") or {})
                elif block.get("type") == "tool_result" and block.get("is_error"):
                    use_id = block.get("tool_use_id", "")
                    name, tool_input = calls.get(use_id, ("?", {}))
                    yield use_id, *signature(name, tool_input, result_text(block.get("content")))


def scan(root: Path) -> dict[str, dict[str, list[str]]]:
    """Map signature -> session id -> example error lines, over every transcript under root."""
    found: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))
    for path in [*root.glob("*.jsonl"), *root.glob("*/subagents/*.jsonl")]:
        session = path.stem if path.parent == root else path.parent.parent.name
        for _, sig, example in iter_failures(path):
            found[sig][session].append(example)
    return found


def report(found: dict[str, dict[str, list[str]]], session: str | None, min_sessions: int) -> list[str]:
    """Return TSV rows, most sessions first."""
    rows = []
    for sig, sessions in found.items():
        if (session and session not in sessions) or len(sessions) < min_sessions:
            continue
        example_session = session or next(iter(sessions))
        here = len(sessions[session]) if session else ""
        total = sum(map(len, sessions.values()))
        rows.append((len(sessions), total, here, sig, example_session, sessions[example_session][0]))
    rows.sort(key=lambda r: (-r[0], -r[1], r[3]))
    header = "sessions\tfailures\there\tsignature\texample_session\texample"
    return [header, *("\t".join(map(str, r)) for r in rows)]


def main(argv: list[str]) -> int:
    args, session, min_sessions = [], None, 2
    it = iter(argv)
    for arg in it:
        match arg:
            case "--session":
                session = next(it, None)
            case "--min-sessions":
                min_sessions = int(next(it, "2"))
            case "-h" | "--help":
                print(__doc__.strip())
                return 0
            case _:
                args.append(arg)
    root = Path(args[0]).expanduser() if args else project_dir(Path.cwd())
    if not root.is_dir():
        print(f"no transcript directory: {root}", file=sys.stderr)
        return 2
    print("\n".join(report(scan(root), session, min_sessions)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
