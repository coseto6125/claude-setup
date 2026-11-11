"""Build a resume fixture: a real session's transcript cut at one entry, under a new session id.

usage: fork_fixture.py <session.jsonl> <cut-uuid>
Writes <the session's project dir>/<new id>.jsonl with every row up to and including the row whose uuid is <cut-uuid>,
each row's sessionId set to the new id. Prints the new id, then the fixture path. The source file is only read.
Exit 1 when no row carries <cut-uuid>; nothing is written then.

Run each trial from the source session's cwd, so the CLI finds the fixture in that project dir:
  claude -p --resume <new id> --no-session-persistence --system-prompt-snapshot off --model <full id> --output-format json "<prompt>"
--no-session-persistence keeps the fixture unchanged, so every trial resumes the same history.
--system-prompt-snapshot off makes the trial build the system prompt now, so --append-system-prompt takes effect.
Delete the fixture by its printed literal path when the run is done.
"""
import json
import pathlib
import sys
import uuid


def build(src: pathlib.Path, cut: str) -> tuple[str, pathlib.Path]:
    """Write the cut fixture beside src.

    Args:
        src: the source session transcript.
        cut: the uuid of the last row to keep.

    Returns:
        The new session id and the fixture path.

    Raises:
        LookupError: no row in src carries the uuid cut.
    """
    new_id = str(uuid.uuid4())
    rows = []
    with src.open(encoding='utf-8') as f:
        for line in f:
            if not line.strip():
                continue
            row = json.loads(line)
            if 'sessionId' in row:
                row['sessionId'] = new_id
            rows.append(json.dumps(row, ensure_ascii=False))
            if row.get('uuid') == cut:
                break
        else:
            raise LookupError(f'no row with uuid {cut} in {src}')
    dst = src.with_name(f'{new_id}.jsonl')
    dst.write_text('\n'.join(rows) + '\n', encoding='utf-8')
    return new_id, dst


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] in ('-h', '--help'):
        sys.exit(__doc__)
    try:
        sid, path = build(pathlib.Path(sys.argv[1]), sys.argv[2])
    except LookupError as e:
        sys.exit(str(e))
    print(sid)
    print(path)
