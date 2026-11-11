"""Mirror the deployed skill surface of a user config into a probe config dir.

usage: mirror_surface.py <user claude home> <probe config dir>
Writes <cfg>/settings.json with only skillOverrides and enabledPlugins. Copies each enabled user-scope plugin into
<cfg>/plugins/cache/ without its .in_use markers, because the CLI writes pid markers into the install path it loads,
and rewrites installed_plugins.json to the copies. A plugin whose install path is gone is skipped with a note.
Exit 2 with a one-line reason when settings.json or installed_plugins.json cannot be read.
"""
import json
import pathlib
import shutil
import sys


def fail(reason):
    print(f'mirror_surface: {reason}', file=sys.stderr)
    sys.exit(2)


def read_json(path, what):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as e:
        fail(f'cannot read {what} at {path}: {e}')


def mirror(home, cfg):
    settings = read_json(home / 'settings.json', 'settings.json') if (home / 'settings.json').exists() else {}
    overrides, enabled = settings.get('skillOverrides', {}), settings.get('enabledPlugins', {})
    if not isinstance(overrides, dict) or not isinstance(enabled, dict):
        fail(f'skillOverrides and enabledPlugins in {home / "settings.json"} must be objects')
    inst_path = home / 'plugins' / 'installed_plugins.json'
    copied = {}
    if inst_path.exists():
        inst = read_json(inst_path, 'installed_plugins.json')
        for name, entries in inst.get('plugins', {}).items():
            entry = next((e for e in entries if e.get('scope') == 'user'), None) if enabled.get(name) else None
            if entry is None:
                continue
            src = pathlib.Path(entry['installPath'])
            if not src.is_dir():
                print(f'mirror_surface: {name} is enabled but {src} is gone; skipped', file=sys.stderr)
                continue
            dst = cfg / 'plugins' / 'cache' / name.replace('/', '_') / src.name
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns('.in_use'))
            copied[name] = [dict(entry, installPath=str(dst))]
        (cfg / 'plugins').mkdir(exist_ok=True)
        (cfg / 'plugins' / 'installed_plugins.json').write_text(json.dumps({'version': inst.get('version', 2), 'plugins': copied}))
        if (home / 'plugins' / 'known_marketplaces.json').exists():
            shutil.copy(home / 'plugins' / 'known_marketplaces.json', cfg / 'plugins')
    (cfg / 'settings.json').write_text(json.dumps({'skillOverrides': overrides, 'enabledPlugins': {n: True for n in copied}}))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        fail(__doc__.splitlines()[2])
    mirror(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]))
