"""Offline tests for fork_fixture.py. Run: uv run --no-project --with pytest pytest -q test_fork_fixture.py"""
import json
import pathlib
import subprocess
import sys

import pytest

from fork_fixture import build

SCRIPT = pathlib.Path(__file__).with_name('fork_fixture.py')


def write_session(d: pathlib.Path, rows: list[dict]) -> pathlib.Path:
    src = d / 'src.jsonl'
    src.write_text(''.join(json.dumps(r) + '\n' for r in rows))
    return src


ROWS = [
    {'type': 'session-owner'},
    {'type': 'user', 'uuid': 'u1', 'sessionId': 'old'},
    {'type': 'assistant', 'uuid': 'a1', 'sessionId': 'old'},
    {'type': 'user', 'uuid': 'r1', 'sessionId': 'old'},
    {'type': 'assistant', 'uuid': 'a2', 'sessionId': 'old'},
]


def test_build_cut_found_keeps_rows_through_cut_with_new_id(tmp_path):
    src = write_session(tmp_path, ROWS)
    before = src.read_bytes()
    sid, dst = build(src, 'r1')
    out = [json.loads(line) for line in dst.read_text().splitlines()]
    assert dst == tmp_path / f'{sid}.jsonl'
    assert [r.get('uuid') for r in out] == [None, 'u1', 'a1', 'r1']
    assert {r['sessionId'] for r in out if 'sessionId' in r} == {sid}
    assert 'sessionId' not in out[0]
    assert src.read_bytes() == before


def test_build_cut_missing_raises_and_writes_nothing(tmp_path):
    src = write_session(tmp_path, ROWS)
    with pytest.raises(LookupError):
        build(src, 'nope')
    assert sorted(p.name for p in tmp_path.iterdir()) == ['src.jsonl']


def test_build_blank_lines_skipped(tmp_path):
    src = tmp_path / 'src.jsonl'
    src.write_text('\n' + json.dumps(ROWS[1]) + '\n\n' + json.dumps(ROWS[2]) + '\n')
    _, dst = build(src, 'a1')
    assert len(dst.read_text().splitlines()) == 2


def test_cli_cut_missing_exits_nonzero(tmp_path):
    src = write_session(tmp_path, ROWS)
    r = subprocess.run([sys.executable, SCRIPT, src, 'nope'], capture_output=True, text=True)
    assert r.returncode == 1
    assert 'nope' in r.stderr


def test_cli_cut_found_prints_id_then_path(tmp_path):
    src = write_session(tmp_path, ROWS)
    r = subprocess.run([sys.executable, SCRIPT, src, 'a1'], capture_output=True, text=True, check=True)
    sid, path = r.stdout.splitlines()
    assert pathlib.Path(path) == tmp_path / f'{sid}.jsonl'
