#!/usr/bin/env python3
"""Read-only structural acceptance coverage check. Python is a development tool."""
from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath
import re
import sys

DOC = Path("docs/codex/winaudioclean")
CASE_ID = re.compile(r"AC-\d{3}\Z")


class CoverageError(ValueError):
    """A missing, stale or unsafe coverage reference."""


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as exc:
        raise CoverageError(f"Cannot read {path.name}: {exc}") from exc


def require(condition, message):
    if not condition:
        raise CoverageError(message)


def strings(value, label):
    require(isinstance(value, list) and all(isinstance(item, str) and item.strip()
            for item in value), f"{label} must be an array of nonempty strings")
    require(len(value) == len(set(value)), f"{label} contains duplicates")
    return value


def reference(repo: Path, value: str):
    require(isinstance(value, str) and value and "\\" not in value and ":" not in value,
            "References must be portable repository-relative paths")
    path = PurePosixPath(value)
    require(not path.is_absolute() and path.as_posix() == value and
            not any(part in {".", "..", ".git", ".wac-local"} for part in path.parts),
            f"Unsafe coverage reference: {value}")
    candidate = repo.joinpath(*path.parts)
    require(candidate.is_file(), f"Missing coverage reference: {value}")
    require(candidate.resolve().is_relative_to(repo.resolve()),
            f"Coverage reference escapes repository: {value}")


def index(items, label):
    require(isinstance(items, list), f"{label} must be an array")
    result = {}
    for item in items:
        require(isinstance(item, dict), f"{label} item must be an object")
        key = item.get("id")
        require(isinstance(key, str) and key.strip(), f"{label} needs a nonempty id")
        require(key not in result, f"Duplicate {label} id: {key}")
        result[key] = item
    return result


def validate(repo: Path):
    """Check references and completeness, without accepting a case or running tests."""
    repo = repo.resolve()
    coverage = read_json(repo / DOC / "COVERAGE.json")
    acceptance = read_json(repo / DOC / "ACCEPTANCE.json")
    tasks = read_json(repo / DOC / "TASKS.yaml")
    require(isinstance(coverage, dict) and coverage.get("schema_version") == 1,
            "Unsupported coverage schema")
    canonical = index(acceptance.get("cases"), "acceptance")
    task_index = index(tasks.get("tasks"), "task")
    active = coverage.get("active_task")
    require(active in task_index, "Coverage active_task is not a canonical task")
    mapped = index(coverage.get("cases"), "coverage case")
    commands = index(coverage.get("commands"), "command")
    reviews = index(coverage.get("reviews"), "review")
    gaps = index(coverage.get("gaps"), "gap")
    required = {case["id"] for case in canonical.values()
                if task_index.get(case.get("task_id"), {}).get("status") == "done"
                or case.get("task_id") == active}
    require(required <= mapped.keys(),
            "Unmapped implemented/current acceptance IDs: " + ", ".join(sorted(required - mapped.keys())))
    for command in commands.values():
        require(isinstance(command.get("command"), str) and command["command"].strip(),
                f"Empty command: {command['id']}")
        for path in strings(command.get("files"), f"{command['id']}.files"):
            reference(repo, path)
    for review in reviews.values():
        require(review.get("status") in {"complete", "scope_limited", "not_performed"},
                f"Review must disclose its status: {review['id']}")
        require(isinstance(review.get("scope"), str) and review["scope"].strip(),
                f"Review must disclose scope: {review['id']}")
        paths = strings(review.get("reports"), f"{review['id']}.reports")
        require(paths, f"Review has no report: {review['id']}")
        for path in paths:
            reference(repo, path)
    for gap in gaps.values():
        require(gap.get("status") == "not_run",
                f"Gap must remain explicitly not_run until its evidence is reconciled: {gap['id']}")
        require(isinstance(gap.get("required_for"), str) and gap["required_for"].strip(),
                f"Gap needs a concrete gate: {gap['id']}")
        require(isinstance(gap.get("reason"), str) and gap["reason"].strip(),
                f"Gap needs a concrete reason: {gap['id']}")
        require(strings(gap.get("cases"), f"{gap['id']}.cases"),
                f"Gap has no related case: {gap['id']}")
        for case_id in gap["cases"]:
            require(case_id in mapped, f"Gap references unmapped case: {case_id}")
            require(gap["id"] in mapped[case_id].get("gaps", []),
                    f"Case {case_id} omits its declared gap {gap['id']}")
        for path in strings(gap.get("reports"), f"{gap['id']}.reports"):
            reference(repo, path)
    for case_id, case in mapped.items():
        require(CASE_ID.fullmatch(case_id) and case_id in canonical,
                f"Unknown acceptance ID: {case_id}")
        require(case.get("task_id") == canonical[case_id]["task_id"],
                f"Stale task association: {case_id}")
        require(case.get("title") == canonical[case_id]["title"], f"Stale acceptance title: {case_id}")
        require(isinstance(case.get("scope"), str) and case["scope"].strip(),
                f"Coverage scope is empty: {case_id}")
        case_commands = strings(case.get("commands"), f"{case_id}.commands")
        case_reports = strings(case.get("reports"), f"{case_id}.reports")
        case_reviews = strings(case.get("reviews"), f"{case_id}.reviews")
        case_gaps = strings(case.get("gaps"), f"{case_id}.gaps")
        require(case_commands or case_reports or case_reviews, f"No evidence or command mapped: {case_id}")
        for command_id in case_commands:
            require(command_id in commands, f"Unknown command {command_id} for {case_id}")
        for review_id in case_reviews:
            require(review_id in reviews, f"Unknown review {review_id} for {case_id}")
        for gap_id in case_gaps:
            require(gap_id in gaps and case_id in gaps[gap_id]["cases"],
                    f"Unknown or unlinked gap {gap_id} for {case_id}")
        for path in case_reports:
            reference(repo, path)
    return {"mapped_cases": len(mapped), "required_cases": len(required),
            "commands": len(commands), "named_reviews": len(reviews),
            "retained_gaps": len(gaps),
            "scope": "Structural traceability only; commands are available coverage, not execution results."}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args(argv)
    try:
        print(json.dumps(validate(args.repo), indent=2))
        print("Coverage traceability passed")
        return 0
    except (CoverageError, KeyError, TypeError, AttributeError) as exc:
        print(f"Coverage check failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
