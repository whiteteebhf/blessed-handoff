#!/usr/bin/env python3
"""Frontmatter checks: the example handoff doc and both skills must have
parseable YAML frontmatter with the required keys.

Run from the repo root (needs pyyaml):
    python3 tests/check-docs.py
"""
import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
failures = 0


def frontmatter(path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    assert lines and lines[0].strip() == "---", "no frontmatter block"
    end = lines[1:].index("---") + 1
    return yaml.safe_load("\n".join(lines[1:end]))


def check(name, fn):
    global failures
    try:
        fn()
        print(f"PASS: {name}")
    except Exception as exc:  # report any assertion/parse failure and continue
        print(f"FAIL: {name}: {exc}")
        failures += 1


# --- example handoff doc ---
example = ROOT / "examples" / "HANDOFF-checkout-refactor-2026-07-13.md"
REQUIRED = [
    "handoff", "date", "project", "branch", "head_sha", "validity",
    "supersedes", "chain", "next_action", "do_not", "open_tasks",
]
fm = {}


def example_parses():
    global fm
    fm = frontmatter(example)
    assert isinstance(fm, dict), "frontmatter is not a mapping"


def example_keys():
    missing = [k for k in REQUIRED if k not in fm]
    assert not missing, f"missing keys: {missing}"


def example_next_action():
    # Intentional drift-catch: this pins the example's exact prose so the
    # check breaks if the header and body are edited out of sync. Update this
    # string deliberately when the example is reworded.
    assert str(fm.get("next_action", "")).strip(), "next_action is empty"
    assert str(fm["next_action"]).startswith("Fix the failing idempotency-key test"), \
        "next_action drifted from the doc body"


def example_open_tasks():
    assert isinstance(fm.get("open_tasks"), int), "open_tasks should be an int"


check("example doc frontmatter parses as YAML", example_parses)
check("example doc has all required header keys", example_keys)
check("example doc next_action is non-empty and matches the body", example_next_action)
check("example doc open_tasks is an int", example_open_tasks)


# --- skills ---
def skill_check(path, expected_name):
    sfm = frontmatter(path)
    assert isinstance(sfm, dict), "frontmatter is not a mapping"
    assert sfm.get("name") == expected_name, f"name is {sfm.get('name')!r}"
    assert str(sfm.get("description", "")).strip(), "description is empty"


for skill in ("handoff", "handoff-resume"):
    path = ROOT / "skills" / skill / "SKILL.md"
    check(f"skills/{skill}/SKILL.md frontmatter (name, description)",
          lambda path=path, skill=skill: skill_check(path, skill))


# --- plugin manifest canary: the seatbelt must stay opt-in forever ---
def plugin_declares_no_hooks():
    import json
    plugin = json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))
    assert "hooks" not in plugin, \
        "plugin.json declares hooks — the PreCompact seatbelt is documented as never auto-installed"


check("plugin.json declares no hooks (seatbelt stays opt-in)", plugin_declares_no_hooks)

print()
if failures:
    print(f"{failures} check(s) FAILED.")
    sys.exit(1)
print("All frontmatter checks passed.")
