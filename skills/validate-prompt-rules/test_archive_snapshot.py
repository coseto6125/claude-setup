"""Offline tests for snapshot.sh (preload snapshot) and archive.sh (durable copy of a run). No claude calls.
Run: uv run --no-project --with pytest pytest -q test_archive_snapshot.py"""
import os
import pathlib
import subprocess

import pytest

HERE = pathlib.Path(__file__).parent
SNAPSHOT = HERE / 'snapshot.sh'
ARCHIVE = HERE / 'archive.sh'


@pytest.fixture
def env(tmp_path):
    home = tmp_path / 'home'
    (home / '.claude').mkdir(parents=True)
    for name in ('CLAUDE.md', 'RTK.md', 'ECP.md'):
        (home / '.claude' / name).write_text(f'{name} v1\n')
    work = tmp_path / 'work'
    work.mkdir()
    script = tmp_path / 'runner.sh'
    script.write_text('echo v1\n')
    return {'home': home, 'work': work, 'script': script, 'root': tmp_path / 'runs', 'tmp': tmp_path}


def snap(env, proj=''):
    code = f'. "{SNAPSHOT}"; PROJ_MD="{proj}"; preload_snapshot "{env["work"]}" "{env["script"]}"; rc=$?; echo "DIR=$PRELOAD_DIR"; echo "PROJ=$PROJ_MD"; exit $rc'
    return subprocess.run(['bash', '-c', code], capture_output=True, text=True, env={**os.environ, 'HOME': str(env['home'])})


def archive(env, *args):
    return subprocess.run(['bash', str(ARCHIVE), *args], capture_output=True, text=True, env={**os.environ, 'ARCHIVE_ROOT': str(env['root'])})


def test_preload_snapshot_firstRun_copiesUserFiles(env):
    r = snap(env)
    assert r.returncode == 0, r.stderr
    p = env['work'] / 'preload'
    assert f'DIR={p}' in r.stdout
    assert (p / 'CLAUDE.md').read_text() == 'CLAUDE.md v1\n'
    assert (p / 'ECP.md').exists() and (p / 'RTK.md').exists()


def test_preload_snapshot_liveEditedAfterFirstRun_keepsSnapshot(env):
    snap(env)
    (env['home'] / '.claude' / 'CLAUDE.md').write_text('CLAUDE.md v2\n')
    r = snap(env)
    assert r.returncode == 0, r.stderr
    assert (env['work'] / 'preload' / 'CLAUDE.md').read_text() == 'CLAUDE.md v1\n'


def test_preload_snapshot_projMd_rewrittenToSnapshot(env):
    proj = env['tmp'] / 'project.md'
    proj.write_text('project v1\n')
    r = snap(env, proj)
    snapped = env['work'] / 'preload' / 'project.md'
    assert f'PROJ={snapped}' in r.stdout
    proj.write_text('project v2\n')
    snap(env, proj)
    assert snapped.read_text() == 'project v1\n'


def test_preload_snapshot_projMdAddedOnLaterRun_copiedThen(env):
    snap(env)
    proj = env['tmp'] / 'project.md'
    proj.write_text('project v1\n')
    r = snap(env, proj)
    assert r.returncode == 0, r.stderr
    assert (env['work'] / 'preload' / 'project.md').read_text() == 'project v1\n'


def test_preload_snapshot_noProjMd_leavesProjEmpty(env):
    r = snap(env)
    assert 'PROJ=\n' in r.stdout


def test_preload_snapshot_scriptChanged_warns(env):
    snap(env)
    env['script'].write_text('echo v2\n')
    r = snap(env)
    assert r.returncode == 0
    assert 'changed since' in r.stderr


def test_preload_snapshot_scriptUnchanged_noWarning(env):
    snap(env)
    r = snap(env)
    assert r.stderr == ''


def test_preload_snapshot_missingUserFile_failsWithoutSnapshot(env):
    (env['home'] / '.claude' / 'ECP.md').unlink()
    r = snap(env)
    assert r.returncode != 0
    assert not (env['work'] / 'preload').exists()


def test_preload_snapshot_existingSnapshot_reusedNotNested(env):
    snap(env)
    snap(env)
    assert not (env['work'] / 'preload' / 'preload').exists()
    assert not list((env['work'] / 'preload').glob('.preload.*'))


def test_archive_copiesDurableFiles_skipsRaw(env):
    w = env['work']
    (w / 'probes').mkdir()
    (w / 'probes' / '01.json').write_text('{}')
    (w / 'raw').mkdir()
    (w / 'raw' / 'row.txt').write_text('answer')
    (w / 'iso').mkdir()
    for name in ('PREDECLARED.md', 'score.py', 'labels.tsv', 'A.md'):
        (w / name).write_text('x')
    r = archive(env, str(w), 'demo')
    assert r.returncode == 0, r.stderr
    dest = pathlib.Path(r.stdout.strip())
    assert dest.parent == env['root'] and dest.name.endswith('-demo')
    assert (dest / 'probes' / '01.json').exists()
    for name in ('PREDECLARED.md', 'score.py', 'labels.tsv', 'A.md'):
        assert (dest / name).exists(), name
    assert not (dest / 'raw').exists() and not (dest / 'iso').exists()


def test_archive_defaultName_usesWorkBasename(env):
    r = archive(env, str(env['work']))
    assert pathlib.Path(r.stdout.strip()).name.endswith('-work')


def test_archive_rerunOnLaterDay_reusesSameDirAndOverwrites(env):
    old = env['root'] / '2026-01-01-demo'
    old.mkdir(parents=True)
    (old / 'labels.tsv').write_text('old')
    (env['work'] / 'labels.tsv').write_text('new')
    r = archive(env, str(env['work']), 'demo')
    assert pathlib.Path(r.stdout.strip()) == old
    assert (old / 'labels.tsv').read_text() == 'new'


def test_archive_rerun_probesNotNested(env):
    (env['work'] / 'probes').mkdir()
    (env['work'] / 'probes' / '01.json').write_text('{}')
    archive(env, str(env['work']), 'demo')
    r = archive(env, str(env['work']), 'demo')
    assert not (pathlib.Path(r.stdout.strip()) / 'probes' / 'probes').exists()


def test_archive_fileOver1MB_skipped(env):
    (env['work'] / 'big.tsv').write_bytes(b'x' * (1024 * 1024 + 1))
    (env['work'] / 'small.tsv').write_text('x')
    dest = pathlib.Path(archive(env, str(env['work']), 'demo').stdout.strip())
    assert (dest / 'small.tsv').exists() and not (dest / 'big.tsv').exists()


@pytest.mark.parametrize('name', ['../x', 'a/b', '   ', '.hidden'])
def test_archive_badName_refused(env, name):
    r = archive(env, str(env['work']), name)
    assert r.returncode == 2
    assert not env['root'].exists() or not any(env['root'].iterdir())


def test_archive_missingWork_exits2(env):
    assert archive(env, str(env['tmp'] / 'nope'), 'demo').returncode == 2


def test_archive_noArgs_printsUsageExits2(env):
    r = archive(env)
    assert r.returncode == 2 and 'usage' in r.stderr


def test_archive_labelsInSubdir_copiedWithPath(env):
    (env['work'] / 'blind').mkdir()
    (env['work'] / 'blind' / 'labels.tsv').write_text('x')
    dest = pathlib.Path(archive(env, str(env['work']), 'demo').stdout.strip())
    assert (dest / 'blind' / 'labels.tsv').exists()


def test_archive_hiddenAndCredentialFiles_neverCopied(env):
    (env['work'] / '.credentials.json').write_text('secret')
    (env['work'] / 'cfg_A').mkdir()
    (env['work'] / 'cfg_A' / '.credentials.json').write_text('secret')
    (env['work'] / 'cfg_A' / 'settings.json').write_text('{}')
    dest = pathlib.Path(archive(env, str(env['work']), 'demo').stdout.strip())
    assert not list(dest.rglob('.credentials.json'))
    assert not (dest / 'cfg_A').exists()


def test_archive_rawSubdirAtAnyDepth_skipped(env):
    (env['work'] / 'raw' / 'p1').mkdir(parents=True)
    (env['work'] / 'raw' / 'p1' / 'row.json').write_text('{}')
    (env['work'] / 'raw.ctl1').mkdir()
    (env['work'] / 'raw.ctl1' / 'row.txt').write_text('x')
    dest = pathlib.Path(archive(env, str(env['work']), 'demo').stdout.strip())
    assert not (dest / 'raw').exists() and not (dest / 'raw.ctl1').exists()


def test_archive_nameIsSuffixOfOtherRun_getsOwnDir(env):
    other = env['root'] / '2026-01-01-claude-md-ae'
    other.mkdir(parents=True)
    dest = pathlib.Path(archive(env, str(env['work']), 'ae').stdout.strip())
    assert dest != other and dest.name.endswith('-ae') and len(dest.name) == len('2026-01-01-ae')


def test_archive_rawDirs_packedIntoTarballWithoutHidden(env):
    import tarfile
    (env['work'] / 'raw' / 'p1').mkdir(parents=True)
    (env['work'] / 'raw' / 'p1' / 'row.json').write_text('{}')
    (env['work'] / 'raw' / '.credentials.json').write_text('secret')
    (env['work'] / 'raw.ctl1').mkdir()
    (env['work'] / 'raw.ctl1' / 'row.txt').write_text('x')
    dest = pathlib.Path(archive(env, str(env['work']), 'demo').stdout.strip())
    names = tarfile.open(dest / 'raw.tar.gz').getnames()
    assert 'raw/p1/row.json' in names and 'raw.ctl1/row.txt' in names
    assert not any('.credentials' in n for n in names)


def test_archive_noRawDirs_noTarball(env):
    dest = pathlib.Path(archive(env, str(env['work']), 'demo').stdout.strip())
    assert not (dest / 'raw.tar.gz').exists()


@pytest.mark.parametrize('flag', ['-h', '--help'])
def test_archive_helpFlag_printsUsageExits0(env, flag):
    r = archive(env, flag)
    assert r.returncode == 0 and 'usage' in r.stderr
    assert not env['root'].exists()


def test_preload_snapshot_liveDiffersFromSnapshot_printsNote(env):
    snap(env)
    (env['home'] / '.claude' / 'CLAUDE.md').write_text('CLAUDE.md v2\n')
    r = snap(env)
    assert 'CLAUDE.md differs' in r.stderr


def test_preload_snapshot_liveUnchanged_noNote(env):
    snap(env)
    assert 'differs' not in snap(env).stderr


def test_archive_agenticPatch_copied(env):
    run = env['work'] / 'runs' / 'control.1'
    run.mkdir(parents=True)
    (run / 'diff.patch').write_text('--- a\n+++ b\n')
    r = archive(env, str(env['work']), 'ag')
    assert r.returncode == 0, r.stderr
    assert (pathlib.Path(r.stdout.strip()) / 'runs' / 'control.1' / 'diff.patch').exists()


def test_archive_baseRepoSnapshot_skipped(env):
    cfg = env['work'] / 'base' / 'config'
    cfg.mkdir(parents=True)
    (cfg / 'credentials.json').write_text('{"key": "x"}\n')
    r = archive(env, str(env['work']), 'b')
    assert r.returncode == 0, r.stderr
    assert not (pathlib.Path(r.stdout.strip()) / 'base').exists()


def test_preload_snapshot_copyFails_leavesNoStagingDir(env):
    (env['home'] / '.claude' / 'RTK.md').unlink()
    snap(env)
    snap(env)
    assert [p.name for p in env['work'].iterdir()] == []


def test_preload_snapshot_preloadIsRegularFile_fails(env):
    (env['work'] / 'preload').write_text('not a dir\n')
    r = snap(env)
    assert r.returncode != 0
    assert [p.name for p in env['work'].iterdir()] == ['preload']


def test_archive_baseDirBelowTop_kept(env):
    arm = env['work'] / 'probes' / 'base'
    arm.mkdir(parents=True)
    (arm / 'probe.md').write_text('p\n')
    r = archive(env, str(env['work']), 'bb')
    assert r.returncode == 0, r.stderr
    assert (pathlib.Path(r.stdout.strip()) / 'probes' / 'base' / 'probe.md').exists()
