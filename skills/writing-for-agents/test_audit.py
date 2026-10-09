import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from audit import audit, bundled_skills, drift, help_subcommands, lost_spans, main, measured_aliases, refs

SKILL_HEAD = "---\nname: probe\ndescription: Use when a test needs a skill file with a description long enough to clear the minimum length check.\n---\n"


def test_measured_aliases_bare_lowercase_alias_reported():
    assert measured_aliases("> Measured 2026-10-09: inert on opus, 0/6 to 6/6.") == [(1, "opus")]


def test_measured_aliases_capitalised_alias_reported():
    assert measured_aliases("> Measured 2026-10-09: Haiku control 0/5.") == [(1, "Haiku")]


def test_measured_aliases_full_id_only_clean():
    assert measured_aliases("> Measured 2026-10-09 on claude-haiku-5-5: 9/15.") == []


def test_measured_aliases_full_id_and_bare_alias_reported():
    text = "> Measured 2026-10-09 on claude-opus-5-5: 5/5. On haiku it was 0/5."
    assert measured_aliases(text) == [(1, "haiku")]


def test_measured_aliases_versioned_display_name_clean():
    assert measured_aliases("> Measured 2026-10-09: Anthropic's Opus 5.5 guidance agrees.") == []


def test_measured_aliases_alias_in_code_span_clean():
    assert measured_aliases("> Measured 2026-09-23: `--model opus` resolved to claude-opus-5-5.") == []


def test_measured_aliases_alias_on_continuation_line_reported_at_block_start():
    text = "intro\n\n> Measured 2026-10-09 on claude-opus-5-5: 5/5.\n> The reverse held on sonnet.\n"
    assert measured_aliases(text) == [(3, "sonnet")]


def test_measured_aliases_no_model_named_clean():
    assert measured_aliases("> Measured: rayon cut the wall time from 4.1 s to 1.3 s.") == []


def test_measured_aliases_other_blockquote_with_alias_clean():
    assert measured_aliases("> Note: haiku sub-agents read this file too.") == []


def test_measured_aliases_empty_text_clean():
    assert measured_aliases("") == []


def test_audit_alias_label_emits_rule_6(tmp_path):
    (tmp_path / "SKILL.md").write_text(SKILL_HEAD + "Body.\n\n> Measured 2026-10-09: inert on opus.\n", encoding="utf-8")
    assert [f for f in audit(tmp_path) if "rule 6" in f] == [
        f"{tmp_path.name}: rule 6: line 7 labels a measurement 'opus', an alias. Write the full model ID the run reported."
    ]


def test_lost_spans_identical_files_clean(tmp_path):
    (tmp_path / "a.md").write_text("Run `check --ack <id>` first.\n", encoding="utf-8")
    assert lost_spans(tmp_path / "a.md", tmp_path / "a.md") == []


def test_lost_spans_dropped_inline_span_reported(tmp_path):
    (tmp_path / "old.md").write_text("Run `check --ack <id>` after `status`.\n", encoding="utf-8")
    (tmp_path / "new.md").write_text("Run `status`.\n", encoding="utf-8")
    assert lost_spans(tmp_path / "old.md", tmp_path / "new.md") == [
        f"spans: `check --ack <id>` is in {tmp_path / 'old.md'} but not in {tmp_path / 'new.md'}. Move it into the rule it serves, or confirm it is dead."
    ]


def test_lost_spans_span_moved_to_other_paragraph_clean(tmp_path):
    (tmp_path / "old.md").write_text("> Measured: `check --ack` held.\n\nAck each delivery.\n", encoding="utf-8")
    (tmp_path / "new.md").write_text("Ack each delivery with `check --ack`.\n", encoding="utf-8")
    assert lost_spans(tmp_path / "old.md", tmp_path / "new.md") == []


def test_lost_spans_dropped_fenced_line_reported(tmp_path):
    (tmp_path / "old.md").write_text("```bash\nrtk gain\nrtk discover\n```\n", encoding="utf-8")
    (tmp_path / "new.md").write_text("```bash\nrtk gain\n```\n", encoding="utf-8")
    assert lost_spans(tmp_path / "old.md", tmp_path / "new.md") == [
        f"spans: `rtk discover` is in {tmp_path / 'old.md'} but not in {tmp_path / 'new.md'}. Move it into the rule it serves, or confirm it is dead."
    ]


def test_lost_spans_empty_old_file_clean(tmp_path):
    (tmp_path / "old.md").write_text("", encoding="utf-8")
    (tmp_path / "new.md").write_text("Run `status`.\n", encoding="utf-8")
    assert lost_spans(tmp_path / "old.md", tmp_path / "new.md") == []


def test_main_spans_missing_file_returns_usage_error(tmp_path, capsys):
    (tmp_path / "old.md").write_text("`x`\n", encoding="utf-8")
    assert main(["spans", str(tmp_path / "old.md"), str(tmp_path / "absent.md")]) == 2
    assert "usage" in capsys.readouterr().out


def test_main_spans_wrong_argument_count_returns_usage_error(capsys):
    assert main(["spans", "only-one.md"]) == 2
    assert "usage" in capsys.readouterr().out


def test_main_spans_lost_span_returns_one(tmp_path, capsys):
    (tmp_path / "old.md").write_text("`gone`\n", encoding="utf-8")
    (tmp_path / "new.md").write_text("nothing\n", encoding="utf-8")
    assert main(["spans", str(tmp_path / "old.md"), str(tmp_path / "new.md")]) == 1
    assert "`gone`" in capsys.readouterr().out


def _stub_tool(tmp_path, monkeypatch, help_text):
    """Put a fake `demo` CLI first on PATH, so the tests do not read the host's real tools."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    tool = bin_dir / "demo"
    tool.write_text(f"#!/bin/sh\ncat <<'HELP'\n{help_text}\nHELP\n", encoding="utf-8")
    tool.chmod(0o755)
    monkeypatch.setenv("PATH", f"{bin_dir}:{os.environ['PATH']}")


DEMO_HELP = "Usage: demo <command>\n\nCommands:\n  build      Build it\n  check      Check it\n\nExamples:\n  demo       Run demo"


def _skill_with_block(tmp_path, block):
    (tmp_path / "probe").mkdir()
    (tmp_path / "probe" / "SKILL.md").write_text(f"```bash\n{block}\n```\n", encoding="utf-8")
    return tmp_path / "probe" / "SKILL.md"


def test_help_subcommands_examples_line_with_tool_name_dropped(tmp_path, monkeypatch):
    _stub_tool(tmp_path, monkeypatch, DEMO_HELP)
    assert help_subcommands(["demo"]) == {"build", "check"}


def test_help_subcommands_only_tool_name_listed_returns_none(tmp_path, monkeypatch):
    _stub_tool(tmp_path, monkeypatch, "Usage: demo [FILE]\n\nExamples:\n  demo       Copy input")
    assert help_subcommands(["demo"]) is None


def test_drift_filename_argument_not_a_subcommand(tmp_path, monkeypatch):
    _stub_tool(tmp_path, monkeypatch, DEMO_HELP)
    assert drift([_skill_with_block(tmp_path, "demo draft.md")]) == []


def test_drift_hyphenated_filename_not_a_subcommand(tmp_path, monkeypatch):
    _stub_tool(tmp_path, monkeypatch, DEMO_HELP)
    assert drift([_skill_with_block(tmp_path, "demo foo-bar.md")]) == []


def test_drift_unknown_subcommand_still_reported(tmp_path, monkeypatch):
    _stub_tool(tmp_path, monkeypatch, DEMO_HELP)
    assert drift([_skill_with_block(tmp_path, "demo frobnicate")]) == [
        "probe: documents `demo frobnicate`, which `demo --help` does not list. Rerun the help and fix the line."
    ]


def test_bundled_skills_extracted_dir_without_skill_md_found(tmp_path):

    skill = tmp_path / "claude-1000/bundled-skills/2.1.295/abc123/claude-api"
    skill.mkdir(parents=True)
    assert bundled_skills(tmp_path) == {"claude-api"}


def test_bundled_skills_missing_cache_returns_empty(tmp_path):

    assert bundled_skills(tmp_path / "absent") == set()


def test_refs_bundled_skill_not_reported(tmp_path):

    (tmp_path / "probe").mkdir()
    (tmp_path / "probe" / "SKILL.md").write_text("Use the `claude-api` skill for prices.\n", encoding="utf-8")
    assert refs([tmp_path / "probe" / "SKILL.md"], tmp_path, bundled={"claude-api"}) == []


def test_refs_unknown_skill_still_reported(tmp_path):

    (tmp_path / "probe").mkdir()
    (tmp_path / "probe" / "SKILL.md").write_text("Use the `no-such-skill` skill.\n", encoding="utf-8")
    assert refs([tmp_path / "probe" / "SKILL.md"], tmp_path, bundled=set()) == [
        "probe: points at `no-such-skill`, which is not a skill here. Update or drop the reference."
    ]


def test_measured_aliases_alias_followed_by_score_reported():
    assert measured_aliases("> Measured on haiku 0/5.") == [(1, "haiku")]


def test_measured_aliases_unversioned_full_id_reported():
    assert measured_aliases("> Measured on claude-opus-latest.") == [(1, "opus")]


def test_measured_aliases_dated_full_id_clean():
    assert measured_aliases("> Measured on claude-haiku-4-5-20251001: 5/5.") == []


def test_measured_aliases_indented_blockquote_reported():
    assert measured_aliases(" > Measured on opus.") == [(1, "opus")]


def test_measured_aliases_version_split_across_lines_clean():
    assert measured_aliases("> Measured on Opus\n> 5.5: 5/5.") == []


def test_measured_aliases_alias_in_double_backtick_span_clean():
    assert measured_aliases("> Measured on claude-opus-5-5: ``--model opus`` resolved.") == []


def test_lost_spans_double_backtick_span_reported(tmp_path):
    (tmp_path / "old.md").write_text("Run ``check --ack`` now.\n", encoding="utf-8")
    (tmp_path / "new.md").write_text("", encoding="utf-8")
    assert [f.split("`")[1] for f in lost_spans(tmp_path / "old.md", tmp_path / "new.md")] == ["check --ack"]


def test_lost_spans_tilde_fence_with_info_string_reported(tmp_path):
    (tmp_path / "old.md").write_text("~~~c++\nrtk gain\n~~~\n", encoding="utf-8")
    (tmp_path / "new.md").write_text("", encoding="utf-8")
    assert [f.split("`")[1] for f in lost_spans(tmp_path / "old.md", tmp_path / "new.md")] == ["rtk gain"]


def test_lost_spans_four_backtick_fence_keeps_inner_fence_line(tmp_path):
    (tmp_path / "old.md").write_text("````md\n```bash\nrtk gain\n```\n````\n", encoding="utf-8")
    (tmp_path / "new.md").write_text("", encoding="utf-8")
    spans = sorted(f.split("`")[1] for f in lost_spans(tmp_path / "old.md", tmp_path / "new.md") if "rtk" in f)
    assert spans == ["rtk gain"]


def test_measured_aliases_score_with_percent_reported():
    assert measured_aliases("> Measured on haiku 9% of runs.") == [(1, "haiku")]


def test_measured_aliases_example_inside_fence_clean():
    assert measured_aliases("```\n> Measured: haiku\n```\n") == []


def test_measured_aliases_list_nested_blockquote_reported():
    assert measured_aliases("- item\n  > Measured: haiku failed") == [(2, "haiku")]


def test_measured_aliases_line_number_after_fence_kept():
    assert measured_aliases("```\na\nb\n```\n> Measured: opus 5/5") == [(5, "opus")]


def test_lost_spans_same_basename_names_both_paths(tmp_path):
    (tmp_path / "a").mkdir()
    (tmp_path / "b").mkdir()
    (tmp_path / "a" / "SKILL.md").write_text("`gone`\n", encoding="utf-8")
    (tmp_path / "b" / "SKILL.md").write_text("\n", encoding="utf-8")
    [finding] = lost_spans(tmp_path / "a" / "SKILL.md", tmp_path / "b" / "SKILL.md")
    assert f"is in {tmp_path / 'a' / 'SKILL.md'} but not in {tmp_path / 'b' / 'SKILL.md'}" in finding


def test_bundled_skills_only_newest_version_counts(tmp_path):
    (tmp_path / "claude-1000/bundled-skills/2.1.288/h1/retired-skill").mkdir(parents=True)
    (tmp_path / "claude-1000/bundled-skills/2.1.295/h2/claude-api").mkdir(parents=True)
    assert bundled_skills(tmp_path) == {"claude-api"}


def test_bundled_skills_version_compared_numerically(tmp_path):
    (tmp_path / "claude-1000/bundled-skills/2.1.99/h1/old-skill").mkdir(parents=True)
    (tmp_path / "claude-1000/bundled-skills/2.1.100/h2/new-skill").mkdir(parents=True)
    assert bundled_skills(tmp_path) == {"new-skill"}


def test_bundled_skills_non_version_dir_ignored(tmp_path):
    (tmp_path / "claude-1000/bundled-skills/tmp-extract/h1/stray").mkdir(parents=True)
    assert bundled_skills(tmp_path) == set()
