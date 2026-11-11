"""Isolation gate for preloaded.sh and agentic.sh: prove the probe process loads what the design says, once per CLI version.

usage: isolation_gate.py --script NAME --cfg DIR [--proj FILE] [--cwd-base DIR] [--skills-surface] [--force] -- <claude flags...>
Checks, each one claude-haiku-5-5 call from a fresh cwd under --cwd-base with the given flags and CLAUDE_CONFIG_DIR=DIR:
  skills  the model lists no invocable skill. --skills-surface replaces it with two checks of the deployed surface instead:
  shadow  a skill planted under DIR/skills/ with a bundled skill's name shows the planted description.
  surface a planted skill is listed, and a planted skill that DIR/settings.json skillOverrides sets to off is not.
          --skills-surface writes those plants into DIR, so pass a config dir made for the gate.
  preload the model quotes the first heading of DIR/CLAUDE.md when that file exists, and NONE when it does not.
  leak    the model finds no line with a word that only ~/.claude/rules/*.md holds; DIR/rules/ counts as loaded on purpose.
          A --cwd-base under $HOME fails this check at once, with no call and no cache: the CLI walks up from such a cwd
          and loads the live ~/.claude/CLAUDE.md and rules/ as project files.
A pass is cached per (CLI version, script, flags, whether a preload and a project file exist, cwd base, --skills-surface) in ~/.cache/validate-prompt-rules/gate/.
Exit 0 on pass or cache hit, 3 on a failed check (the failing answer is printed).
"""
import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

MODEL = 'claude-haiku-5-5'
LIST = 'No tools. List every skill you can invoke with the Skill tool, comma-separated, names only. If there is none, output exactly NONE.'
SENTINEL = 'GATE-SHADOW-SENTINEL'
VISIBLE, HIDDEN = 'gate-visible-probe', 'gate-hidden-probe'
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
    return out.strip()


def names(listing):
    return {n.strip(' `*-.') for n in re.split(r'[,\n]', listing)} - {''}


def plant(cfg, name, description):
    d = pathlib.Path(cfg) / 'skills' / name
    d.mkdir(parents=True, exist_ok=True)
    (d / 'SKILL.md').write_text(f'---\nname: {name}\ndescription: "{description}"\n---\n\nIsolation gate probe.\n')


def surface_checks(cfg, ask_cfg):
    """Plant the probes for --skills-surface and return its checks."""
    bundled = sorted(n for n in names(ask_cfg(LIST)) if re.fullmatch(r'[a-z][a-z0-9-]*', n))
    for name in (VISIBLE, HIDDEN):
        plant(cfg, name, f'{name} probe. Use it when the user asks for a {name} run.')
    settings = pathlib.Path(cfg) / 'settings.json'
    data = json.loads(settings.read_text()) if settings.exists() else {}
    data.setdefault('skillOverrides', {})[HIDDEN] = 'off'
    settings.write_text(json.dumps(data))
    checks = {'surface': (LIST, lambda r: VISIBLE in names(r) and HIDDEN not in names(r))}
    if bundled:
        plant(cfg, bundled[0], f'{SENTINEL} review skill. Use it when the user asks for a sentinel review.')
        checks['shadow'] = (f'No tools. Quote verbatim the description of the skill named "{bundled[0]}" as your skill list gives it. Nothing else.',
                            lambda r: SENTINEL in r)
    else:
        print('isolation gate: no bundled skill is listed, so the shadow check is skipped', file=sys.stderr)
    return checks


def leak_word(cfg, proj):
    seen = ' '.join(p.read_text() for p in [*pathlib.Path(cfg).glob('*.md'), *pathlib.Path(cfg).glob('rules/**/*.md'),
                                             *([pathlib.Path(proj)] if proj else [])])
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
    ap.add_argument('--skills-surface', action='store_true')
    ap.add_argument('flags', nargs=argparse.REMAINDER)
    a = ap.parse_args()
    flags = [f for f in a.flags if f != '--']
    if pathlib.Path(a.cwd_base).resolve().is_relative_to(pathlib.Path.home().resolve()):
        print(f'isolation gate FAILED: leak: cwd base {a.cwd_base} is under $HOME, so the CLI loads the live ~/.claude as project files',
              file=sys.stderr)
        return 3
    claude_md = pathlib.Path(a.cfg) / 'CLAUDE.md'
    version = subprocess.run(['claude', '--version'], capture_output=True, text=True).stdout.strip()
    key = hashlib.sha256('\0'.join([version, a.script, *flags, str(claude_md.exists()), str(bool(a.proj)), a.cwd_base, str(a.skills_surface)]).encode()).hexdigest()[:16]
    stamp = CACHE / f'{key}.ok'
    if stamp.exists() and not a.force:
        print(f'isolation gate: cached pass ({version}, {a.script})')
        return 0

    heading = next((l.strip() for l in claude_md.read_text().splitlines() if l.startswith('# ')), None) if claude_md.exists() else None
    word = leak_word(a.cfg, a.proj)
    if a.skills_surface:
        checks = surface_checks(a.cfg, lambda prompt: ask(prompt, a.cfg, a.proj, a.cwd_base, flags))
    else:
        checks = {'skills': (LIST, lambda r: r.strip().strip('.').upper() == 'NONE')}
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
