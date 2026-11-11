"""Offline tests for mirror_surface.py. Run: uv run --no-project --with pytest pytest -q test_mirror_surface.py"""
import json
import pathlib
import subprocess
import sys

import pytest

SCRIPT = pathlib.Path(__file__).with_name('mirror_surface.py')
PLUGIN = 'alpha@market'


def mirror(home, cfg):
    return subprocess.run([sys.executable, '-I', str(SCRIPT), str(home), str(cfg)], capture_output=True, text=True, timeout=30)


def install(home, name=PLUGIN, scope='user', exists=True):
    src = home / 'plugins' / 'cache' / 'market' / name.split('@')[0] / 'v1'
    if exists:
        (src / 'skills' / 'alpha').mkdir(parents=True)
        (src / 'skills' / 'alpha' / 'SKILL.md').write_text('---\nname: alpha\n---\n')
        (src / '.in_use').mkdir()
        (src / '.in_use' / '123').write_text('pid')
    inst = home / 'plugins' / 'installed_plugins.json'
    data = json.loads(inst.read_text()) if inst.exists() else {'version': 2, 'plugins': {}}
    data['plugins'].setdefault(name, []).append({'scope': scope, 'installPath': str(src), 'version': 'v1'})
    inst.parent.mkdir(parents=True, exist_ok=True)
    inst.write_text(json.dumps(data))
    return src


@pytest.fixture
def dirs(tmp_path):
    home, cfg = tmp_path / 'home', tmp_path / 'cfg'
    home.mkdir()
    cfg.mkdir()
    return home, cfg


def settings(home, data):
    (home / 'settings.json').write_text(json.dumps(data))


def test_mirror_overrides_kept_other_settings_dropped(dirs):
    home, cfg = dirs
    settings(home, {'model': 'opus', 'skillOverrides': {'loop': 'off'}})
    assert mirror(home, cfg).returncode == 0
    assert json.loads((cfg / 'settings.json').read_text()) == {'skillOverrides': {'loop': 'off'}, 'enabledPlugins': {}}


def test_mirror_no_settings_file_writes_empty_surface(dirs):
    home, cfg = dirs
    assert mirror(home, cfg).returncode == 0
    assert json.loads((cfg / 'settings.json').read_text()) == {'skillOverrides': {}, 'enabledPlugins': {}}


@pytest.mark.parametrize('text', ['{not json', '{"skillOverrides": ["loop"]}', '{"enabledPlugins": ["x"]}'])
def test_mirror_unreadable_settings_exits_2(dirs, text):
    home, cfg = dirs
    (home / 'settings.json').write_text(text)
    r = mirror(home, cfg)
    assert r.returncode == 2 and 'settings.json' in r.stderr


def test_mirror_enabled_user_plugin_copied_with_rewritten_path_and_no_in_use(dirs):
    home, cfg = dirs
    settings(home, {'enabledPlugins': {PLUGIN: True}})
    install(home)
    (home / 'plugins' / 'known_marketplaces.json').write_text('{"market": {}}')
    assert mirror(home, cfg).returncode == 0, 'mirror failed'
    entry = json.loads((cfg / 'plugins' / 'installed_plugins.json').read_text())['plugins'][PLUGIN][0]
    dst = pathlib.Path(entry['installPath'])
    assert dst.is_relative_to(cfg) and (dst / 'skills' / 'alpha' / 'SKILL.md').exists()
    assert not (dst / '.in_use').exists()
    assert json.loads((cfg / 'settings.json').read_text())['enabledPlugins'] == {PLUGIN: True}
    assert (cfg / 'plugins' / 'known_marketplaces.json').read_text() == '{"market": {}}'


@pytest.mark.parametrize('enabled', [{PLUGIN: False}, {}])
def test_mirror_disabled_or_unlisted_plugin_not_copied(dirs, enabled):
    home, cfg = dirs
    settings(home, {'enabledPlugins': enabled})
    install(home)
    assert mirror(home, cfg).returncode == 0
    assert json.loads((cfg / 'plugins' / 'installed_plugins.json').read_text())['plugins'] == {}
    assert json.loads((cfg / 'settings.json').read_text())['enabledPlugins'] == {}


def test_mirror_project_scope_only_plugin_not_copied(dirs):
    home, cfg = dirs
    settings(home, {'enabledPlugins': {PLUGIN: True}})
    install(home, scope='project')
    assert mirror(home, cfg).returncode == 0
    assert json.loads((cfg / 'plugins' / 'installed_plugins.json').read_text())['plugins'] == {}


def test_mirror_missing_install_path_skipped_with_note(dirs):
    home, cfg = dirs
    settings(home, {'enabledPlugins': {PLUGIN: True}})
    install(home, exists=False)
    r = mirror(home, cfg)
    assert r.returncode == 0 and PLUGIN in r.stderr
    assert json.loads((cfg / 'settings.json').read_text())['enabledPlugins'] == {}


def test_mirror_no_installed_plugins_file_writes_no_plugins_dir(dirs):
    home, cfg = dirs
    settings(home, {'enabledPlugins': {PLUGIN: True}})
    assert mirror(home, cfg).returncode == 0
    assert not (cfg / 'plugins').exists()
    assert json.loads((cfg / 'settings.json').read_text())['enabledPlugins'] == {}


def test_mirror_unreadable_installed_plugins_exits_2(dirs):
    home, cfg = dirs
    settings(home, {'enabledPlugins': {PLUGIN: True}})
    (home / 'plugins').mkdir()
    (home / 'plugins' / 'installed_plugins.json').write_text('{broken')
    r = mirror(home, cfg)
    assert r.returncode == 2 and 'installed_plugins.json' in r.stderr


def test_mirror_wrong_argument_count_exits_2(dirs):
    r = subprocess.run([sys.executable, '-I', str(SCRIPT)], capture_output=True, text=True)
    assert r.returncode == 2 and 'usage' in r.stderr
