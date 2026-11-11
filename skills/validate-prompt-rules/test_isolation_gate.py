"""Live tests for isolation_gate.py: each one spends claude-haiku-5-5 calls. Run: uv run --no-project --with pytest pytest -q test_isolation_gate.py"""
import pathlib
import shutil
import subprocess
import sys
import tempfile

import pytest

GATE = pathlib.Path(__file__).with_name('isolation_gate.py')
FLAGS = ['--setting-sources', 'user,project', '--disable-slash-commands', '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}']
HOME_CLAUDE = pathlib.Path.home() / '.claude'


@pytest.fixture
def cfg():
    d = pathlib.Path(tempfile.mkdtemp(prefix='gate-test-cfg.', dir='/tmp'))
    (d / 'settings.json').write_text('{}')
    for name in ('.credentials.json', 'CLAUDE.md', 'RTK.md', 'ECP.md'):
        shutil.copy(HOME_CLAUDE / name, d)
    yield d
    shutil.rmtree(d)


def run_gate(cfg, flags, cwd_base='/tmp', extra=()):
    return subprocess.run([sys.executable, '-I', str(GATE), '--script', 'test', '--cfg', str(cfg), '--cwd-base', cwd_base, '--force', *extra, '--', *flags],
                          capture_output=True, text=True, timeout=600)


def test_gate_scripted_flags_pass(cfg):
    r = run_gate(cfg, FLAGS)
    assert r.returncode == 0, r.stderr


def test_gate_without_disable_slash_commands_fails_skills(cfg):
    r = run_gate(cfg, [f for f in FLAGS if f != '--disable-slash-commands'])
    assert r.returncode == 3 and 'skills' in r.stderr, r.stdout + r.stderr


def test_gate_project_only_sources_fails_preload(cfg):
    r = run_gate(cfg, ['--setting-sources', 'project', *FLAGS[2:]])
    assert r.returncode == 3 and 'preload' in r.stderr, r.stdout + r.stderr


def test_gate_cwd_under_home_fails_leak(cfg):
    base = tempfile.mkdtemp(prefix='gate-test-home.', dir=pathlib.Path.home() / '.cache')
    try:
        r = run_gate(cfg, FLAGS, cwd_base=base)
    finally:
        shutil.rmtree(base)
    assert r.returncode == 3 and 'leak' in r.stderr, r.stdout + r.stderr


ROUTE_FLAGS = ['--setting-sources', 'user', '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}']


def test_gate_skills_surface_route_flags_pass(cfg):
    r = run_gate(cfg, ROUTE_FLAGS, extra=['--skills-surface'])
    assert r.returncode == 0, r.stdout + r.stderr
    assert 'shadow' in r.stdout and 'surface' in r.stdout


def test_gate_skills_surface_with_skills_disabled_fails_surface(cfg):
    r = run_gate(cfg, [*ROUTE_FLAGS, '--disable-slash-commands'], extra=['--skills-surface'])
    assert r.returncode == 3 and 'surface' in r.stderr, r.stdout + r.stderr


def test_gate_mirrored_rules_count_as_preload_not_leak(cfg):
    shutil.copytree(HOME_CLAUDE / 'rules', cfg / 'rules')
    r = run_gate(cfg, FLAGS)
    assert r.returncode == 0, r.stdout + r.stderr


@pytest.mark.parametrize('mirror_rules', [False, True])
def test_gate_cwd_base_under_home_fails_leak_before_any_call(cfg, mirror_rules):
    if mirror_rules:
        shutil.copytree(HOME_CLAUDE / 'rules', cfg / 'rules')
    base = tempfile.mkdtemp(prefix='gate-test-home.', dir=pathlib.Path.home() / '.cache')
    try:
        r = subprocess.run([sys.executable, '-I', str(GATE), '--script', 'test', '--cfg', str(cfg), '--cwd-base', base, '--', *FLAGS],
                           capture_output=True, text=True, timeout=30, env={'PATH': '/usr/bin:/bin', 'HOME': str(pathlib.Path.home())})
    finally:
        shutil.rmtree(base)
    assert r.returncode == 3 and 'leak' in r.stderr and 'under' in r.stderr, r.stdout + r.stderr
