#!/usr/bin/env python3
"""Read-only GitHub CI evidence for an exact SHA; development tools only.

Exit codes: passed=0, failed=1, pending=2, not_run=3, api_error=4,
unavailable=5. Local test results are never inferred from this reader.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess

REPOSITORY = "PikkuJanne/WinAudioClean"
WORKFLOW_PATH = ".github/workflows/windows-validation.yml"
WORKFLOW_NAME = "Windows validation"
REQUIRED_JOBS = frozenset(
    f"Windows {os_name} / {shell}"
    for os_name in ("windows-2022", "windows-2025")
    for shell in ("ps51", "ps7")
)
EXIT_CODES = {"passed": 0, "failed": 1, "pending": 2, "not_run": 3,
              "api_error": 4, "unavailable": 5}
STATUSES = {"queued", "requested", "waiting", "pending", "in_progress", "completed"}
CONCLUSIONS = {"", "success", "failure", "cancelled", "timed_out", "skipped",
               "neutral", "action_required", "stale", "startup_failure"}
LIST_FIELDS = "databaseId,headSha,event,workflowName,workflowDatabaseId"
VIEW_FIELDS = LIST_FIELDS + ",status,conclusion,jobs"


class CIReadError(Exception):
    """Public failure category; raw gh diagnostics never leave the reader."""

    def __init__(self, state, reason):
        super().__init__(reason)
        self.state = state


def gh_json(arguments):
    """Invoke only gh read commands, without a shell, logs or credential output."""
    try:
        completed = subprocess.run(
            ["gh", *arguments], stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            encoding="utf-8", timeout=45, check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise CIReadError("unavailable", "GitHub CLI is unavailable or timed out.") from exc
    except UnicodeError as exc:
        raise CIReadError("api_error", "GitHub CLI returned unreadable data.") from exc
    if completed.returncode != 0:
        raise CIReadError("api_error", "GitHub CLI could not read workflow evidence.")
    try:
        return json.loads(completed.stdout)
    except ValueError as exc:
        raise CIReadError("api_error", "GitHub CLI returned invalid JSON.") from exc


def positive_id(value):
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def matches_run(run, commit, event):
    return (run.get("headSha") == commit and run.get("event") == event
            and run.get("workflowName") == WORKFLOW_NAME)


def public_name(value):
    """Keep public job names printable and bounded; omit all other job metadata."""
    return "".join(char if char.isprintable() else "?" for char in value)[:160]


def inspect_ci(commit, event="pull_request", read_json=gh_json):
    """Return sanitized evidence; injected JSON readers permit offline tests."""
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("commit must be a full lowercase 40-hex SHA")
    if event not in {"pull_request", "push"}:
        raise ValueError("event must be pull_request or push")
    summary = {"repository": REPOSITORY, "headSha": commit,
               "event": event, "workflow": WORKFLOW_NAME, "workflowPath": WORKFLOW_PATH}

    def result(state, reason):
        return {**summary, "state": state, "reason": reason}

    try:
        runs = read_json(["run", "list", "--repo", REPOSITORY,
                          "--commit", commit, "--event", event,
                          "--limit", "100", "--json", LIST_FIELDS])
        if not isinstance(runs, list) or not all(isinstance(row, dict) for row in runs):
            raise CIReadError("api_error", "Workflow list has an invalid shape.")
        matching = [row for row in runs if matches_run(row, commit, event)]
        if not matching:
            return result("not_run", "No matching workflow run was returned for this SHA and event.")
        if any(not positive_id(row.get("databaseId"))
               or not positive_id(row.get("workflowDatabaseId")) for row in matching):
            raise CIReadError("api_error", "Matching workflow identity is incomplete.")
        # A later run must supersede earlier successes, including when it is pending.
        selected = max(matching, key=lambda row: row["databaseId"])
        # Filename lookup in gh run list resolves against the default branch;
        # an unmerged branch workflow must instead be checked by its actual ID.
        workflow = read_json(["api", "--method", "GET",
                              f"repos/{REPOSITORY}/actions/workflows/{selected['workflowDatabaseId']}"])
        if (not isinstance(workflow, dict) or not positive_id(workflow.get("id"))
                or workflow["id"] != selected["workflowDatabaseId"]
                or workflow.get("name") != WORKFLOW_NAME or workflow.get("path") != WORKFLOW_PATH):
            raise CIReadError("api_error", "Selected workflow does not match the required path and identity.")
        run = read_json(["run", "view", str(selected["databaseId"]),
                         "--repo", REPOSITORY, "--json", VIEW_FIELDS])
        if (not isinstance(run, dict) or not matches_run(run, commit, event)
                or not positive_id(run.get("databaseId"))
                or not positive_id(run.get("workflowDatabaseId"))
                or run.get("databaseId") != selected["databaseId"]
                or run.get("workflowDatabaseId") != selected["workflowDatabaseId"]):
            raise CIReadError("api_error", "Viewed run does not match the requested identity.")
        status, conclusion, jobs = run.get("status"), run.get("conclusion") or "", run.get("jobs")
        if (not isinstance(status, str) or status not in STATUSES
                or not isinstance(conclusion, str) or conclusion not in CONCLUSIONS
                or not isinstance(jobs, list)):
            raise CIReadError("api_error", "Workflow result has an invalid shape.")
        public_jobs = []
        names = []
        for job in jobs:
            if not isinstance(job, dict):
                raise CIReadError("api_error", "Job result has an invalid shape.")
            name, job_status = job.get("name"), job.get("status")
            job_conclusion = job.get("conclusion") or ""
            if (not isinstance(name, str) or not name.strip()
                    or not isinstance(job_status, str) or job_status not in STATUSES
                    or not isinstance(job_conclusion, str) or job_conclusion not in CONCLUSIONS):
                raise CIReadError("api_error", "Job result has an invalid shape.")
            names.append(name)
            public_jobs.append({"name": public_name(name), "status": job_status,
                                "conclusion": job_conclusion})
        summary["run"] = {"id": run["databaseId"], "workflowId": run["workflowDatabaseId"],
                          "url": f"https://github.com/{REPOSITORY}/actions/runs/{run['databaseId']}",
                          "status": status, "conclusion": conclusion, "jobs": public_jobs}
        if status != "completed":
            return result("pending", "The matching workflow has not completed.")
        if conclusion != "success":
            return result("failed", "The matching workflow did not conclude successfully.")
        if not jobs or not REQUIRED_JOBS.issubset(names) or len(names) != len(set(names)):
            return result("failed", "Completed workflow lacks unique required shell/build job evidence.")
        if any(job["status"] != "completed" or job["conclusion"] != "success" for job in jobs):
            return result("failed", "Every reported job must complete successfully; skips do not pass.")
        return result("passed", "Exact workflow SHA and all required shell/build jobs succeeded.")
    except CIReadError as exc:
        return result(exc.state, str(exc))


def full_sha(value):
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise argparse.ArgumentTypeError("use a full lowercase 40-hex commit SHA")
    return value


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--commit", required=True, type=full_sha,
                        help="exact tested source commit; abbreviated SHAs are rejected")
    parser.add_argument("--event", choices=("pull_request", "push"), default="pull_request")
    args = parser.parse_args(argv)
    evidence = inspect_ci(args.commit, args.event)
    print(json.dumps(evidence, indent=2, ensure_ascii=True))
    return EXIT_CODES[evidence["state"]]


if __name__ == "__main__":
    raise SystemExit(main())
