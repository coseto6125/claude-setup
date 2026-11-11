"""Offline tests for route.sh: a fake `claude` on PATH replaces every API call. Run: python3 -m pytest -q test_route.py
Set ROUTE_SCRIPT to test another copy of the script."""
import json
import os
import pathlib
import subprocess

import pytest

ROUTE = pathlib.Path(os.environ.get('ROUTE_SCRIPT') or pathlib.Path(__file__).with_name('route.sh'))

FAKE_CLAUDE = r'''#!/usr/bin/env bash
# Fake claude: logs the cwd and its CLAUDE.md, answers FAKE_ANSWER, fails when the prompt holds BOOM.
prompt="$2"
{ echo "cwd=$PWD"; echo "args=$*"; [ -f CLAUDE.md ] && echo "md=$(cat CLAUDE.md)"
  echo "skillfiles=$(cd "$CLAUDE_CONFIG_DIR/skills" && find . -type f | sort | tr '\n' ' ')"
  echo "rulefiles=$(cd "$CLAUDE_CONFIG_DIR" && [ -d rules ] && find rules -type f | sort | tr '\n' ' ')"
  echo "settings=$(cat "$CLAUDE_CONFIG_DIR/settings.json")"; [ -f "$CLAUDE_CONFIG_DIR/CLAUDE.md" ] && echo "usermd=$(cat "$CLAUDE_CONFIG_DIR/CLAUDE.md")"; } >> "$FAKE_LOG"
case "$prompt" in *BOOM*) echo "API Error: overloaded" >&2; exit 1 ;; esac
case "$prompt" in *EMPTY*) exit 0 ;; esac
echo "${FAKE_ANSWER:-alpha}"
'''
STUB_GATE = ('#!/usr/bin/env python3\nimport os, sys\n'
             'open(os.environ["FAKE_LOG"], "a").write("gate=" + " ".join(sys.argv[1:]) + "\\n")\n'
             'sys.exit(int(os.environ.get("GATE_RC", "0")))\n')


@pytest.fixture
def env(tmp_path):
    bindir = tmp_path / 'bin'
    bindir.mkdir()
    (bindir / 'claude').write_text(FAKE_CLAUDE)
    (bindir / 'claude').chmod(0o755)
    (tmp_path / 'gate.py').write_text(STUB_GATE)
    home = tmp_path / 'home'
    home.mkdir()
    skills = tmp_path / 'skills'
    (skills / 'alpha').mkdir(parents=True)
    (skills / 'alpha' / 'SKILL.md').write_text('---\nname: alpha\n---\n')
    log = tmp_path / 'fake.log'
    log.touch()
    e = dict(os.environ, PATH=f'{bindir}:{os.environ["PATH"]}', CLAUDE_HOME=str(home), FAKE_LOG=str(log),
             GATE=str(tmp_path / 'gate.py'))
    for k in ('SCENARIOS', 'WORK', 'PROJ_MD', 'ARM', 'WORKDIR', 'PRELOAD_USER', 'GATE_RC'):
        e.pop(k, None)
    return pathlib.Path(tmp_path), e


def run(env, *args, **extra):
    tmp, e = env
    return subprocess.run(['bash', str(ROUTE), *args], capture_output=True, text=True, timeout=60, env=dict(e, **extra), cwd=tmp)


def scenarios(tmp, text, name='scn.tsv'):
    p = tmp / name
    p.write_text(text)
    return str(p)


def test_route_passed_scenarios_file_is_used(env):
    tmp, _ = env
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tdo alpha thing\n'))
    assert r.returncode == 0, r.stderr
    assert 'OK=1 MISS=0 ERR=0' in r.stdout
    assert 'do alpha thing' in (tmp / 'fake.log').read_text()


def test_route_default_scenarios_file_used_when_unset(env):
    tmp, e = env
    d = tmp / 'copy'
    d.mkdir()
    (d / 'route.sh').write_text(ROUTE.read_text())
    (d / 'mirror_surface.py').write_text(ROUTE.with_name('mirror_surface.py').read_text())
    (d / 'scenarios.tsv').write_text('alpha\tfirst\nbeta\tsecond\n')
    r = subprocess.run(['bash', str(d / 'route.sh'), str(tmp / 'skills'), '1', 'm1'], capture_output=True, text=True, timeout=60, env=e, cwd=tmp)
    assert 'OK=1 MISS=1 ERR=0' in r.stdout, r.stdout + r.stderr


def test_route_work_dir_keeps_raw_rows_and_labels(env):
    tmp, _ = env
    work = tmp / 'run'
    r = run(env, str(tmp / 'skills'), '2', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\nbeta\ttwo\n'), WORK=str(work))
    assert r.returncode == 0, r.stderr
    rows = sorted(p for p in (work / 'raw').rglob('*.txt'))
    assert len(rows) == 4
    assert all(p.read_text().strip() == 'alpha' for p in rows)
    labels = (work / 'labels.tsv').read_text().splitlines()
    assert len(labels) == 4
    assert sorted(l.split('\t')[0] for l in labels) == ['MISS', 'MISS', 'OK', 'OK']


def test_route_failed_call_counts_as_err_not_miss(env):
    tmp, _ = env
    work = tmp / 'run'
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tBOOM\nalpha\tEMPTY\nalpha\tfine\n'), WORK=str(work))
    assert 'OK=1 MISS=0 ERR=2' in r.stdout, r.stdout + r.stderr
    statuses = [l.split('\t')[0] for l in (work / 'labels.tsv').read_text().splitlines()]
    assert sorted(statuses) == ['ERR', 'ERR', 'OK']


def test_route_proj_md_lands_in_probe_cwd(env):
    tmp, _ = env
    md = tmp / 'proj.md'
    md.write_text('# Project rules\n')
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'), PROJ_MD=str(md))
    assert r.returncode == 0, r.stderr
    log = (tmp / 'fake.log').read_text()
    assert 'md=# Project rules' in log
    assert 'cwd=/tmp/route-probe.' in log
    assert '--setting-sources user,project' in log


def test_route_no_proj_md_loads_user_sources_only(env):
    tmp, _ = env
    run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    log = (tmp / 'fake.log').read_text()
    assert '--setting-sources user ' in log and 'md=' not in log


def test_route_empty_scenarios_file_exits_2(env):
    tmp, _ = env
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, ''))
    assert r.returncode == 2 and 'no scenarios' in r.stderr


def test_route_whitespace_only_line_is_skipped(env):
    tmp, _ = env
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, '   \n\t\nalpha\tone\n  \t  \n'))
    assert r.returncode == 0, r.stderr
    assert 'OK=1 MISS=0 ERR=0' in r.stdout


def test_route_whitespace_only_file_exits_2(env):
    tmp, _ = env
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, '  \n\t\n'))
    assert r.returncode == 2 and 'no scenarios' in r.stderr


def test_route_missing_skills_dir_exits_2(env):
    tmp, _ = env
    r = run(env, str(tmp / 'nope'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert r.returncode == 2 and 'does not exist' in r.stderr


def test_route_help_lists_new_env_vars(env):
    r = run(env, '--help')
    assert r.returncode == 0
    for name in ('SCENARIOS', 'WORK', 'PROJ_MD'):
        assert name in r.stdout


def test_route_user_skill_overrides_mirrored_other_settings_dropped(env):
    tmp, e = env
    (pathlib.Path(e['CLAUDE_HOME']) / 'settings.json').write_text(
        '{"model": "opus", "skillOverrides": {"code-review": "user-invocable-only", "loop": "off"}}')
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert r.returncode == 0, r.stderr
    line = next(l for l in (tmp / 'fake.log').read_text().splitlines() if l.startswith('settings='))
    assert '"code-review": "user-invocable-only"' in line and '"loop": "off"' in line and 'model' not in line


@pytest.mark.parametrize('text', [None, '{}', '{"skillOverrides": {}}'])
def test_route_absent_or_empty_overrides_writes_empty_overrides(env, text):
    tmp, e = env
    if text is not None:
        (pathlib.Path(e['CLAUDE_HOME']) / 'settings.json').write_text(text)
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert r.returncode == 0, r.stderr
    line = next(l for l in (tmp / 'fake.log').read_text().splitlines() if l.startswith('settings='))
    assert json.loads(line.split('=', 1)[1])['skillOverrides'] == {}


@pytest.mark.parametrize('text', ['{not json', '{"skillOverrides": ["loop"]}'])
def test_route_unreadable_overrides_exits_2(env, text):
    tmp, e = env
    (pathlib.Path(e['CLAUDE_HOME']) / 'settings.json').write_text(text)
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert r.returncode == 2 and 'settings.json' in r.stderr


def test_route_preloads_user_claude_md_unless_disabled(env):
    tmp, e = env
    (pathlib.Path(e['CLAUDE_HOME']) / 'CLAUDE.md').write_text('# Global rules\n')
    run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert 'usermd=# Global rules' in (tmp / 'fake.log').read_text()
    (tmp / 'fake.log').write_text('')
    run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'), PRELOAD_USER='0')
    assert 'usermd=' not in (tmp / 'fake.log').read_text()


def test_route_gate_checks_skills_surface_without_proj_md(env):
    tmp, _ = env
    run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    gate = next(l for l in (tmp / 'fake.log').read_text().splitlines() if l.startswith('gate='))
    assert '--skills-surface' in gate and '--disable-slash-commands' not in gate


def test_route_failed_gate_exits_3_before_any_trial(env):
    tmp, _ = env
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'), GATE_RC='3')
    assert r.returncode == 3
    assert 'args=' not in (tmp / 'fake.log').read_text()


def test_route_copies_only_top_level_skill_md_files(env):
    tmp, _ = env
    alpha = tmp / 'skills' / 'alpha'
    (alpha / '.venv').mkdir()
    (alpha / '.venv' / 'big.bin').write_bytes(b'x' * 1024)
    (alpha / 'reference.md').write_text('ref')
    (alpha / 'extensions' / 'nested').mkdir(parents=True)
    (alpha / 'extensions' / 'nested' / 'SKILL.md').write_text('---\nname: nested\n---\n')
    beta_src = tmp / 'beta-src'
    beta_src.mkdir()
    (beta_src / 'SKILL.md').write_text('---\nname: beta\n---\n')
    (tmp / 'skills' / 'beta').symlink_to(beta_src)
    (tmp / 'skills' / 'notes.txt').write_text('loose file')
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert r.returncode == 0, r.stderr
    line = next(l for l in (tmp / 'fake.log').read_text().splitlines() if l.startswith('skillfiles='))
    assert line.split('=', 1)[1].split() == ['./alpha/SKILL.md', './beta/SKILL.md']


def test_route_skills_dir_without_skill_md_exits_2(env):
    tmp, _ = env
    empty = tmp / 'empty-skills'
    (empty / 'gamma').mkdir(parents=True)
    r = run(env, str(empty), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert r.returncode == 2 and 'SKILL.md' in r.stderr


def test_route_synced_skill_md_and_markers_copied_references_dropped(env):
    tmp, _ = env
    bucket = tmp / 'skills' / 'synced' / 'acct'
    (bucket / 'docs').mkdir(parents=True)
    (bucket / 'docs' / 'SKILL.md').write_text('---\nname: docs\n---\n')
    (bucket / 'docs' / 'guide.md').write_text('reference')
    (bucket / '.marketplaces.json').write_text('{}')
    (tmp / 'skills' / 'synced' / '.bucket-acct').write_text('')
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert r.returncode == 0, r.stderr
    files = next(l for l in (tmp / 'fake.log').read_text().splitlines() if l.startswith('skillfiles=')).split('=', 1)[1].split()
    assert files == ['./alpha/SKILL.md', './synced/.bucket-acct', './synced/acct/.marketplaces.json', './synced/acct/docs/SKILL.md']


def test_route_synced_only_tree_is_not_empty(env):
    tmp, _ = env
    tree = tmp / 'only-synced'
    (tree / 'synced' / 'acct' / 'docs').mkdir(parents=True)
    (tree / 'synced' / 'acct' / 'docs' / 'SKILL.md').write_text('---\nname: docs\n---\n')
    r = run(env, str(tree), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert r.returncode == 0, r.stderr


def test_route_user_rules_preloaded_unless_disabled(env):
    tmp, e = env
    rules = pathlib.Path(e['CLAUDE_HOME']) / 'rules'
    rules.mkdir()
    (rules / 'ctx.md').write_text('use ctx7\n')
    run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert 'rulefiles=rules/ctx.md' in (tmp / 'fake.log').read_text()
    (tmp / 'fake.log').write_text('')
    run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'), PRELOAD_USER='0')
    assert 'rulefiles=rules/' not in (tmp / 'fake.log').read_text()


def test_route_enabled_plugins_reach_arm_settings(env):
    tmp, e = env
    home = pathlib.Path(e['CLAUDE_HOME'])
    src = home / 'plugins' / 'cache' / 'm' / 'fd' / 'v1'
    (src / 'skills' / 'fd').mkdir(parents=True)
    (src / 'skills' / 'fd' / 'SKILL.md').write_text('---\nname: fd\n---\n')
    (home / 'plugins' / 'installed_plugins.json').write_text(json.dumps(
        {'version': 2, 'plugins': {'fd@m': [{'scope': 'user', 'installPath': str(src)}]}}))
    (home / 'settings.json').write_text('{"enabledPlugins": {"fd@m": true}}')
    r = run(env, str(tmp / 'skills'), '1', 'm1', SCENARIOS=scenarios(tmp, 'alpha\tone\n'))
    assert r.returncode == 0, r.stderr
    line = next(l for l in (tmp / 'fake.log').read_text().splitlines() if l.startswith('settings='))
    assert json.loads(line.split('=', 1)[1])['enabledPlugins'] == {'fd@m': True}
