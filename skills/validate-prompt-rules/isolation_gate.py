"""Isolation gate for preloaded.sh and agentic.sh: prove the probe process loads what the design says, once per CLI version.

usage: isolation_gate.py --script NAME --cfg DIR [--proj FILE] [--cwd-base DIR] [--force] -- <claude flags...>
Checks, each one claude-haiku-5-5 call from a fresh cwd under --cwd-base with the given flags and CLAUDE_CONFIG_DIR=DIR:
  skills  the model lists no invocable skill.
  preload the model quotes the first heading of DIR/CLAUDE.md when that file exists, and NONE when it does not.
  leak    the model finds no line with a word that only ~/.claude/rules/*.md holds.
A pass is cached per (CLI version, script, flags, whether a preload and a project file exist, cwd base) in ~/.cache/validate-prompt-rules/gate/.
Exit 0 on pass or cache hit, 3 on a failed check (the failing answer is printed).
"""
import argparse
import hashlib
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

MODEL = 'claude-haiku-5-5'
CACHE = pathlib.Path(os.environ.get('XDG_CACHE_HOME', pathlib.Path.home() / '.cache')) / 'validate-prompt-rules' / 'gate'


def ask(prompt, cfg, proj, cwd_base, flags):
    cwd = tempfile.mkdtemp(prefix='gate.', dir=cwd_base)
    try:
        if proj:
            shutil.copy(proj, pathlib.Path(cwd) / 'CLAUDE.md')
        r = subprocess.run(['claude', '-p', prompt, '--model', MODEL, *flags], cwd=cwd, capture_output=True, text=True,
                           timeout=180, env={**os.environ, 'CLAUDE_CONFIG_DIR': cfg})
        if r.returncode:  # an auth or rate-limit failure, not an isolation result: no answer can pass
            print(f'isolation gate: claude exited {r.returncode}: {r.stderr.strip()[:300]}', file=sys.stderr)
        out = '' if r.returncode else r.stdout
    finally:
        shutil.rmtree(cwd)
    return '\n'.join(l for l in out.splitlines() if not l.startswith('claude-wrap:')).strip()


def leak_word(cfg, proj):
    seen = ' '.join(p.read_text() for p in [*pathlib.Path(cfg).glob('*.md'), *([pathlib.Path(proj)] if proj else [])])
    words = [w for rule in sorted((pathlib.Path.home() / '.claude' / 'rules').glob('*.md'))
             for w in re.findall(r'\b[A-Za-z][A-Za-z0-9_]*[0-9_][A-Za-z0-9_]*\b', rule.read_text()) if len(w) >= 5 and w not in seen]
    return words[0] if words else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--script', required=True)
    ap.add_argument('--cfg', required=True)
    ap.add_argument('--proj', default='')
    ap.add_argument('--cwd-base', default='/tmp')
    ap.add_argument('--force', action='store_true')
    ap.add_argument('flags', nargs=argparse.REMAINDER)
    a = ap.parse_args()
    flags = [f for f in a.flags if f != '--']
    claude_md = pathlib.Path(a.cfg) / 'CLAUDE.md'
    version = subprocess.run(['claude', '--version'], capture_output=True, text=True).stdout.strip()
    key = hashlib.sha256('\0'.join([version, a.script, *flags, str(claude_md.exists()), str(bool(a.proj)), a.cwd_base]).encode()).hexdigest()[:16]
    stamp = CACHE / f'{key}.ok'
    if stamp.exists() and not a.force:
        print(f'isolation gate: cached pass ({version}, {a.script})')
        return 0

    heading = next((l.strip() for l in claude_md.read_text().splitlines() if l.startswith('# ')), None) if claude_md.exists() else None
    word = leak_word(a.cfg, a.proj)
    checks = {'skills': ('No tools. List every skill you can invoke with the Skill tool, comma-separated. If there is none, output exactly NONE.',
                         lambda r: r.strip().strip('.').upper() == 'NONE')}
    checks['preload'] = ('No tools. Quote verbatim the first markdown heading line (a line that starts with "# ") of your user-level instruction file. '
                         'If you have no user-level instruction file, output exactly NONE.',
                         (lambda r: heading.lstrip('# ') in r) if heading else (lambda r: r.strip().upper() == 'NONE'))
    if word:
        checks['leak'] = (f'No tools. Quote verbatim any line in your instructions that contains the word "{word}". If there is none, output exactly NONE.',
                          lambda r: r.strip().strip('.').upper() == 'NONE')
    else:
        print('isolation gate: no ~/.claude/rules/ word is absent from the arm, so the rules leak check is skipped', file=sys.stderr)
    with ThreadPoolExecutor(len(checks)) as pool:
        answers = dict(zip(checks, pool.map(lambda c: ask(c[0], a.cfg, a.proj, a.cwd_base, flags), checks.values())))
    failed = [n for n, (_, ok) in checks.items() if not ok(answers[n])]
    for n in failed:  # one retry absorbs a sampling slip; a real leak fails twice
        answers[n] = ask(checks[n][0], a.cfg, a.proj, a.cwd_base, flags)
    failed = [n for n in failed if not checks[n][1](answers[n])]
    if failed:
        for n in failed:
            print(f'isolation gate FAILED: {n}: {answers[n][:300]!r}', file=sys.stderr)
        return 3
    CACHE.mkdir(parents=True, exist_ok=True)
    tmp = stamp.with_suffix(f'.{os.getpid()}')
    tmp.write_text(f'{version}\n{a.script}\n')
    tmp.replace(stamp)
    print(f'isolation gate: pass ({version}, {a.script}, checks: {", ".join(checks)})')
    return 0


sys.exit(main())
