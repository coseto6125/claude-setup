import importlib.util
import json
import subprocess
import sys
from pathlib import Path

_path = Path(__file__).with_name("loop-guard.py")
_spec = importlib.util.spec_from_file_location("loop_guard", _path)
lg = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(lg)


def write_transcript(path: Path, failures: list[tuple[str, str, dict, str]]) -> Path:
    """Write a transcript of failed calls: each item is (tool_use_id, tool, input, error text)."""
    lines = []
    for use_id, name, tool_input, text in failures:
        use = {"type": "tool_use", "id": use_id, "name": name, "input": tool_input}
        result = {"type": "tool_result", "tool_use_id": use_id, "content": text, "is_error": True}
        lines += [json.dumps({"message": {"content": [use]}}), json.dumps({"message": {"content": [result]}})]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def event(transcript: Path, use_id: str, command: str = "pytest -q", error: str = "Exit code 1\n1 failed") -> dict:
    return {
        "tool_name": "Bash",
        "tool_input": {"command": command},
        "tool_use_id": use_id,
        "error": error,
        "transcript_path": str(transcript),
    }


def pytest_fail(use_id: str) -> tuple[str, str, dict, str]:
    return (use_id, "Bash", {"command": "pytest -q"}, "Exit code 1\n1 failed")


def test_note_third_identical_failure_fires(tmp_path):
    t = write_transcript(tmp_path / "s.jsonl", [pytest_fail("a"), pytest_fail("b")])
    text = lg.note(event(t, "c"))
    assert text is not None and "`Bash: pytest (exit 1)` has now failed 3 times" in text


def test_note_second_failure_is_silent(tmp_path):
    t = write_transcript(tmp_path / "s.jsonl", [pytest_fail("a")])
    assert lg.note(event(t, "b")) is None


def test_note_fourth_failure_is_silent(tmp_path):
    t = write_transcript(tmp_path / "s.jsonl", [pytest_fail("a"), pytest_fail("b"), pytest_fail("c")])
    assert lg.note(event(t, "d")) is None


def test_note_current_call_already_in_transcript_counts_once(tmp_path):
    t = write_transcript(tmp_path / "s.jsonl", [pytest_fail("a"), pytest_fail("b"), pytest_fail("c")])
    assert lg.note(event(t, "c")) is not None


def test_note_different_signatures_do_not_add_up(tmp_path):
    other = ("a", "Bash", {"command": "make"}, "Exit code 2\nboom")
    t = write_transcript(tmp_path / "s.jsonl", [other, pytest_fail("b")])
    assert lg.note(event(t, "c")) is None


def test_note_same_command_other_error_does_not_add_up(tmp_path):
    other = ("a", "Bash", {"command": "pytest -q"}, "Exit code 1\nModuleNotFoundError: No module named 'x'")
    t = write_transcript(tmp_path / "s.jsonl", [other, pytest_fail("b")])
    assert lg.note(event(t, "c")) is None


def test_note_error_line_differs_only_in_numbers_and_paths_adds_up(tmp_path):
    a = ("a", "Bash", {"command": "pytest -q"}, "Exit code 1\nFAILED /x/a.py:12 - 2 failed")
    b = ("b", "Bash", {"command": "pytest -q"}, "Exit code 1\nFAILED /y/a.py:40 - 3 failed")
    t = write_transcript(tmp_path / "s.jsonl", [a, b])
    assert lg.note(event(t, "c", error="Exit code 1\nFAILED /z/a.py:7 - 1 failed")) is not None


def test_note_grep_no_match_never_fires(tmp_path):
    grep = [(i, "Bash", {"command": "grep x f"}, "Exit code 1\n") for i in "ab"]
    t = write_transcript(tmp_path / "s.jsonl", grep)
    assert lg.note(event(t, "c", command="grep x f", error="Exit code 1\n")) is None


def test_note_grep_real_error_fires(tmp_path):
    grep = [(i, "Bash", {"command": "grep x f"}, "Exit code 2\nno such file") for i in "ab"]
    t = write_transcript(tmp_path / "s.jsonl", grep)
    assert lg.note(event(t, "c", command="grep x f", error="Exit code 2\nno such file")) is not None


def test_note_edit_tool_failure_fires(tmp_path):
    edit = [(i, "Edit", {"file_path": "/a.py"}, "<tool_use_error>String to replace not found in file.</tool_use_error>") for i in "ab"]
    t = write_transcript(tmp_path / "s.jsonl", edit)
    e = {"tool_name": "Edit", "tool_input": {"file_path": "/a.py"}, "tool_use_id": "c",
         "error": "String to replace not found in file.", "transcript_path": str(t)}
    assert lg.note(e) is not None


def test_note_interrupt_is_silent(tmp_path):
    t = write_transcript(tmp_path / "s.jsonl", [pytest_fail("a"), pytest_fail("b")])
    assert lg.note({**event(t, "c"), "is_interrupt": True}) is None


def test_note_missing_transcript_is_silent(tmp_path):
    assert lg.note(event(tmp_path / "gone.jsonl", "c")) is None


def test_note_absent_transcript_field_is_silent():
    assert lg.note({"tool_name": "Bash", "tool_input": {"command": "x"}, "error": "Exit code 1\n"}) is None


def test_is_no_match_other_exit_code_is_failure():
    assert lg.is_no_match("Bash: grep (exit 1)") and not lg.is_no_match("Bash: grep (exit 2)")
    assert not lg.is_no_match("Bash: pytest (exit 1)")


def run_hook(stdin: str) -> subprocess.CompletedProcess:
    return subprocess.run(  # ruff: ignore[subprocess-without-shell-equals-true] - runs this repo's own hook script
        [sys.executable, str(_path)], input=stdin, capture_output=True, text=True, timeout=30, check=False
    )


def test_main_third_failure_prints_hook_json(tmp_path):
    t = write_transcript(tmp_path / "s.jsonl", [pytest_fail("a"), pytest_fail("b")])
    r = run_hook(json.dumps(event(t, "c")))
    out = json.loads(r.stdout)
    assert r.returncode == 0
    assert out["hookSpecificOutput"]["hookEventName"] == "PostToolUseFailure"
    assert "Loop guard" in out["hookSpecificOutput"]["additionalContext"]


def test_main_malformed_stdin_prints_nothing():
    r = run_hook("{not json")
    assert (r.returncode, r.stdout) == (0, "")


def test_main_empty_stdin_prints_nothing():
    r = run_hook("")
    assert (r.returncode, r.stdout) == (0, "")
