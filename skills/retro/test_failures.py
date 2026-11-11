import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from failures import command_head, main, project_dir, report, scan, signature


def write_session(root: Path, session: str, events: list[tuple[str, dict, str, bool]], sub: str | None = None) -> None:
    """Write one transcript: each event is (tool, input, result text, is_error)."""
    path = root / session / "subagents" / f"{sub}.jsonl" if sub else root / f"{session}.jsonl"
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = []
    for i, (name, tool_input, text, is_error) in enumerate(events):
        use = {"type": "tool_use", "id": f"t{i}", "name": name, "input": tool_input}
        result = {"type": "tool_result", "tool_use_id": f"t{i}", "content": text, "is_error": is_error}
        lines += [json.dumps({"message": {"content": [use]}}), json.dumps({"message": {"content": [result]}})]
    path.write_text("\n".join(lines) + "\n")


def bash_fail(command: str, code: int = 1, out: str = "boom") -> tuple[str, dict, str, bool]:
    return ("Bash", {"command": command}, f"Exit code {code}\n{out}", True)


def test_command_head_last_list_segment_wins():
    assert command_head("cd /x && git status; pytest -q") == "pytest"


def test_command_head_strips_wrappers_and_assignments():
    assert command_head("FOO=1 rtk proxy timeout 60 git diff --stat") == "git diff"


def test_command_head_rtk_bypass_strips_wrapper():
    assert command_head("rtk bypass git diff --stat") == "git diff"


def test_command_head_pipeline_keeps_first_element():
    assert command_head("uv run pytest 2>&1 | tail -5") == "uv run"


def test_command_head_loop_end_is_skipped():
    assert command_head("for f in a b; do grep -q x $f; done") == "grep"


def test_command_head_heredoc_body_is_ignored():
    assert command_head("python3 - <<'EOF'\nimport os; rm -rf\nEOF") == "python3"


def test_command_head_unbalanced_quote_falls_back():
    assert command_head("grep 'oops") == "grep"


def test_command_head_trailing_echo_is_skipped():
    assert command_head("cmp a b && echo same; echo ---") == "cmp"


def test_command_head_plain_program_drops_its_argument():
    assert command_head("which qpdf") == "which"


def test_command_head_path_program_uses_basename():
    assert command_head("/usr/bin/ls /nope") == "ls"


def test_command_head_empty_returns_placeholder():
    assert command_head("   ") == "?"


def test_signature_bash_keeps_exit_code_apart():
    assert signature("Bash", {"command": "grep x f"}, "Exit code 1\n")[0] == "Bash: grep (exit 1)"
    assert signature("Bash", {"command": "grep x f"}, "Exit code 2\nno such file")[0] == "Bash: grep (exit 2)"


def test_signature_other_tool_normalises_paths_and_digits():
    sig, example = signature("Read", {}, "<tool_use_error>File does not exist: /a/b/c.py line 12</tool_use_error>")
    assert sig == "Read: File does not exist: <path> line N"
    assert example == "File does not exist: /a/b/c.py line 12"


def test_signature_list_content_is_flattened(tmp_path):
    write_session(tmp_path, "s1", [])
    content = [{"type": "text", "text": "Error: String to replace not found in file."}]
    (tmp_path / "s1.jsonl").write_text(
        json.dumps({"message": {"content": [{"type": "tool_use", "id": "a", "name": "Edit", "input": {}}]}})
        + "\n"
        + json.dumps({"message": {"content": [{"type": "tool_result", "tool_use_id": "a", "content": content, "is_error": True}]}})
    )
    assert list(scan(tmp_path)) == ["Edit: String to replace not found in file."]


def test_scan_empty_dir_returns_nothing(tmp_path):
    assert scan(tmp_path) == {}


def test_scan_skips_malformed_and_successful_lines(tmp_path):
    write_session(tmp_path, "s1", [("Bash", {"command": "ls"}, "ok", False)])
    with (tmp_path / "s1.jsonl").open("a") as fh:
        fh.write('{"tool_use" broken\n["tool_use"]\n')
    assert scan(tmp_path) == {}


def test_scan_result_without_matching_use_is_unknown_tool(tmp_path):
    line = {"message": {"content": [{"type": "tool_result", "tool_use_id": "gone", "content": "x", "is_error": True}]}}
    (tmp_path / "s1.jsonl").write_text(json.dumps(line) + "\n")
    assert list(scan(tmp_path)) == ["?: x"]


def test_scan_subagent_counts_toward_parent_session(tmp_path):
    write_session(tmp_path, "parent", [])
    write_session(tmp_path, "parent", [bash_fail("pytest")], sub="agent-1")
    assert set(scan(tmp_path)["Bash: pytest (exit 1)"]) == {"parent"}


def test_report_counts_sessions_once_and_failures_each(tmp_path):
    write_session(tmp_path, "s1", [bash_fail("pytest"), bash_fail("pytest")])
    write_session(tmp_path, "s2", [bash_fail("pytest")])
    write_session(tmp_path, "s3", [bash_fail("make")])
    rows = report(scan(tmp_path), None, 2)
    assert rows[1:] == ["2\t3\t\tBash: pytest (exit 1)\ts1\tboom"]


def test_report_session_filter_takes_example_from_that_session(tmp_path):
    write_session(tmp_path, "now", [bash_fail("pytest", out="here"), bash_fail("pytest", out="again")])
    write_session(tmp_path, "old", [bash_fail("pytest", out="there"), bash_fail("make")])
    write_session(tmp_path, "older", [bash_fail("make")])
    rows = report(scan(tmp_path), "now", 1)
    assert rows[1:] == ["2\t3\t2\tBash: pytest (exit 1)\tnow\there"]


def test_signature_rejected_bash_keeps_command_head():
    text = "The user doesn't want to proceed with this tool use. The tool use was rejected."
    assert signature("Bash", {"command": "command sleep 110"}, text) == ("Bash: rejected by user: command sleep", "command sleep 110")


def test_signature_rejected_other_tool_has_no_head():
    text = "The user doesn't want to proceed with this tool use."
    assert signature("Edit", {"file_path": "/a"}, text)[0] == "Edit: rejected by user"


def test_report_min_sessions_one_keeps_singletons(tmp_path):
    write_session(tmp_path, "s1", [bash_fail("make")])
    assert len(report(scan(tmp_path), None, 1)) == 2


def test_main_missing_dir_exits_2(tmp_path, capsys):
    assert main([str(tmp_path / "nope")]) == 2
    assert "no transcript directory" in capsys.readouterr().err


def test_main_prints_header_for_empty_project(tmp_path, capsys):
    assert main([str(tmp_path), "--min-sessions", "1"]) == 0
    assert capsys.readouterr().out.startswith("sessions\tfailures\there\tsignature")


def test_project_dir_replaces_every_non_alnum():
    assert project_dir("/home/a_b/c.d").name == "-home-a-b-c-d"


def test_command_head_command_lookup_keeps_program():
    assert command_head("command -v orca-ide") == "command"


def test_command_head_command_wrapper_keeps_wrapped_program():
    assert command_head("command sleep 110") == "command sleep"
