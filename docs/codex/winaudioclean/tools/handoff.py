#!/usr/bin/env python3
"""WinAudioClean handoff utilities. Python 3.10+, standard library, developer-only.

No command performs a git write, network upload, push, merge, or application edit.
install is preview-only unless --apply is explicitly passed. It creates missing
payload files exclusively and refuses to overwrite differing files.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
from typing import Any
from urllib.parse import urlsplit

EXPECTED_REPOSITORY = 'pikkujanne/winaudioclean'
BASELINE = '7dfe43361395908a277d7b513b1c9a4fd3cd192a'
MANIFEST_NAME = 'BUNDLE_MANIFEST.json'
SUMS_NAME = 'SHA256SUMS.txt'
DOC_REL = Path('docs/codex/winaudioclean')
TASK_STATES = {'todo', 'in_progress', 'blocked', 'done', 'deferred'}
CASE_STATES = {'not_run', 'pass', 'fail', 'blocked', 'not_applicable'}


class HandoffError(RuntimeError):
    """A failed safety precondition or invalid handoff."""


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as exc:
        raise HandoffError(f'Cannot read valid JSON: {path.name}: {exc}') from exc


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def safe_relative(value: str) -> Path:
    """Disallow absolute, Windows-drive, dot, traversal and metadata paths."""
    if not isinstance(value, str) or not value or value in {'.', '..'} or '\\' in value or ':' in value:
        raise HandoffError('Unsafe or non-portable relative path in handoff.')
    p = PurePosixPath(value)
    if p.is_absolute() or p.as_posix() != value or any(
        part.casefold() in {'.', '..', '.git'} for part in p.parts
    ):
        raise HandoffError(f'Unsafe relative path: {value!r}')
    return Path(*p.parts)


def link_or_reparse(path: Path) -> bool:
    try:
        info = path.lstat()
    except FileNotFoundError:
        return False
    return stat.S_ISLNK(info.st_mode) or bool(
        getattr(info, 'st_file_attributes', 0)
        & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0x400)
    )


def ensure_no_links(path: Path) -> None:
    """Reject symlink/junction redirection, including existing ancestors."""
    p = Path(os.path.abspath(path))
    for candidate in (p, *p.parents):
        if link_or_reparse(candidate):
            raise HandoffError(f'Symlink/junction path is not supported: {candidate}')


def safe_member(root: Path, relative: str) -> Path:
    member = root / safe_relative(relative)
    ensure_no_links(member)
    if not member.resolve().is_relative_to(root.resolve()):
        raise HandoffError('Path escapes the requested root.')
    return member


def payload_allowed(relative: str) -> bool:
    return relative == 'AGENTS.md' or relative.startswith('docs/codex/winaudioclean/')


def iter_bundle_files(root: Path):
    for p in sorted(root.rglob('*')):
        if '__pycache__' in p.parts or p.suffix == '.pyc':
            continue  # Local interpreter cache, never part of the distribution.
        if link_or_reparse(p):
            raise HandoffError('Bundle contains a symbolic link or reparse point.')
        if p.is_file():
            yield p


def verify_bundle(root: Path) -> dict:
    root = Path(os.path.abspath(root))
    ensure_no_links(root)
    manifest = read_json(root / MANIFEST_NAME)
    if manifest.get('schema_version') != 1 or manifest.get('repository') != 'PikkuJanne/WinAudioClean':
        raise HandoffError('Unexpected bundle manifest schema or repository.')
    entries = manifest.get('files')
    if not isinstance(entries, list) or not entries:
        raise HandoffError('Manifest file list is empty or invalid.')
    expected: dict[str, str] = {}
    for entry in entries:
        relative = entry.get('path', '')
        if relative in {MANIFEST_NAME, SUMS_NAME} or relative in expected:
            raise HandoffError('Duplicate or self-referential manifest entry.')
        p = safe_member(root, relative)
        if not p.is_file():
            raise HandoffError(f'Missing bundle file: {relative}')
        if not re.fullmatch(r'[0-9a-f]{64}', str(entry.get('sha256', ''))):
            raise HandoffError('Invalid SHA-256 in manifest.')
        if p.stat().st_size != entry.get('bytes') or digest(p) != entry['sha256']:
            raise HandoffError(f'Integrity check failed: {relative}')
        expected[relative] = entry['sha256']
    actual = {p.relative_to(root).as_posix() for p in iter_bundle_files(root)}
    if actual != set(expected) | {MANIFEST_NAME, SUMS_NAME}:
        raise HandoffError('Bundle file set differs from its manifest (extra/missing files).')
    sums: dict[str, str] = {}
    try:
        for line in (root / SUMS_NAME).read_text(encoding='utf-8').splitlines():
            match = re.fullmatch(r'([0-9a-f]{64})  (.+)', line)
            if not match or match[2] in sums:
                raise HandoffError('Malformed or duplicate SHA256SUMS entry.')
            safe_relative(match[2])
            sums[match[2]] = match[1]
    except OSError as exc:
        raise HandoffError('Cannot read SHA256SUMS.txt.') from exc
    wanted_sums = dict(expected)
    wanted_sums[MANIFEST_NAME] = digest(root / MANIFEST_NAME)
    if sums != wanted_sums:
        raise HandoffError('SHA256SUMS.txt does not match the manifest and payload.')
    for name in expected:
        if name.startswith('payload/') and not payload_allowed(name[len('payload/'):]):
            raise HandoffError(f'Out-of-scope payload entry: {name}')
    validate_plan(root / 'payload' / DOC_REL)
    return {'valid': True, 'files_verified': len(expected), 'repository': manifest['repository']}


def evidence_exists(root: Path, value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(
        isinstance(name, str) and safe_member(root, name).is_file() for name in value
    )


def validate_plan(root: Path) -> dict:
    plan = read_json(root / 'TASKS.yaml')  # JSON syntax is an intentional YAML 1.2 subset.
    accept = read_json(root / 'ACCEPTANCE.json')
    if plan.get('schema_version') != 1 or plan.get('repository') != 'PikkuJanne/WinAudioClean':
        raise HandoffError('Unexpected plan schema or repository.')
    if accept.get('schema_version') != 1:
        raise HandoffError('Unexpected acceptance schema.')
    task_list = plan.get('tasks', [])
    case_list = accept.get('cases', [])
    if not task_list or not case_list:
        raise HandoffError('Empty task or acceptance list.')
    tasks = {t.get('id'): t for t in task_list}
    cases = {c.get('id'): c for c in case_list}
    if len(tasks) != len(task_list) or len(cases) != len(case_list):
        raise HandoffError('Duplicate task or acceptance ID.')
    milestones = {m['id'] for m in plan.get('milestones', [])}
    if len(milestones) != len(plan.get('milestones', [])):
        raise HandoffError('Duplicate milestone ID.')
    covered: set[int] = set()
    for tid, task in tasks.items():
        if not isinstance(tid, str) or not re.fullmatch(r'WAC-M\d+-\d{2,}', tid):
            raise HandoffError('Invalid task ID.')
        if task.get('milestone') not in milestones or task.get('status') not in TASK_STATES:
            raise HandoffError(f'Unknown milestone/state: {tid}')
        if not (root / 'tasks' / f'{tid}.md').is_file():
            raise HandoffError(f'Missing task brief: {tid}')
        deps = task.get('depends_on', [])
        if len(deps) != len(set(deps)) or any(dep not in tasks or dep == tid for dep in deps):
            raise HandoffError(f'Invalid dependency: {tid}')
        ids = task.get('acceptance_ids', [])
        if not ids or len(ids) != len(set(ids)) or any(
            cid not in cases or cases[cid].get('task_id') != tid for cid in ids
        ):
            raise HandoffError(f'Invalid acceptance links: {tid}')
        improvements = task.get('improvements', [])
        if not improvements or any(type(i) is not int or i not in range(1, 21) for i in improvements):
            raise HandoffError(f'Invalid improvement mapping: {tid}')
        covered.update(improvements)
        state = task['status']
        if state == 'blocked' and not task.get('blocked_reason'):
            raise HandoffError(f'Blocked task needs a reason: {tid}')
        if state == 'deferred' and not (task.get('blocked_reason') and task.get('approval_ref')):
            raise HandoffError(f'Deferred task needs reason and owner approval: {tid}')
        if state == 'done':
            if not evidence_exists(root, task.get('evidence')):
                raise HandoffError(f'Done task needs existing evidence: {tid}')
            if any(tasks[d]['status'] not in {'done', 'deferred'} for d in deps):
                raise HandoffError(f'Done task has unfinished dependencies: {tid}')
            if any(cases[c]['status'] not in {'pass', 'not_applicable'} for c in ids):
                raise HandoffError(f'Done task has unaccepted cases: {tid}')
            if task.get('approval_required') and not task.get('approval_ref'):
                raise HandoffError(f'Approval-gated task lacks approval: {tid}')
    if covered != set(range(1, 21)):
        raise HandoffError('The plan does not cover all 20 improvement groups.')
    for cid, case in cases.items():
        if not isinstance(cid, str) or not re.fullmatch(r'AC-\d{3,}', cid):
            raise HandoffError('Invalid acceptance ID.')
        tid = case.get('task_id')
        if tid not in tasks or cid not in tasks[tid]['acceptance_ids']:
            raise HandoffError(f'Orphan acceptance case: {cid}')
        if case.get('status') not in CASE_STATES or not case.get('procedure') or not case.get('expected'):
            raise HandoffError(f'Invalid acceptance contract/state: {cid}')
        if case['status'] == 'pass' and not evidence_exists(root, case.get('evidence')):
            raise HandoffError(f'Passed case needs existing evidence: {cid}')
        if case['status'] in {'fail', 'blocked'} and not case.get('reason'):
            raise HandoffError(f'Failed/blocked case needs a reason: {cid}')
        if case['status'] == 'not_applicable' and not (case.get('reason') and case.get('disposition_ref')):
            raise HandoffError(f'Inapplicable case needs reason and approved disposition: {cid}')
    visiting: set[str] = set()
    visited: set[str] = set()
    def visit(tid: str):
        if tid in visiting:
            raise HandoffError('Task dependency cycle detected.')
        if tid in visited:
            return
        visiting.add(tid)
        for dep in tasks[tid]['depends_on']:
            visit(dep)
        visiting.remove(tid)
        visited.add(tid)
    for tid in tasks:
        visit(tid)
    return {'valid': True, 'tasks': len(tasks), 'acceptance_cases': len(cases), 'improvements': len(covered)}


def next_tasks(root: Path) -> dict:
    validate_plan(root)
    tasks = read_json(root / 'TASKS.yaml')['tasks']
    lookup = {t['id']: t for t in tasks}
    ready = [t for t in tasks if t['status'] in {'todo', 'in_progress'} and all(
        lookup[d]['status'] in {'done', 'deferred'} for d in t['depends_on'])]
    return {'ready': [{'id': t['id'], 'title': t['title'],
                       'approval_needed': bool(t.get('approval_required') and not t.get('approval_ref'))}
                      for t in ready],
            'blocked': [t['id'] for t in tasks if t['status'] == 'blocked']}


def normalize_origin(url: str) -> str:
    """Accept only ordinary GitHub transports, no embedded HTTPS credentials."""
    value = url.strip()
    scp = re.fullmatch(r'git@github\.com:([^\s]+)', value, re.I)
    if scp:
        path = scp[1]
    else:
        parsed = urlsplit(value)
        if parsed.hostname is None or parsed.hostname.lower() != 'github.com' or parsed.query or parsed.fragment:
            raise HandoffError('Origin is not the expected ordinary GitHub endpoint.')
        try:
            port = parsed.port
        except ValueError as exc:
            raise HandoffError('Invalid origin port.') from exc
        if parsed.scheme == 'https' and parsed.username is None and parsed.password is None and port in {None, 443}:
            path = parsed.path.lstrip('/')
        elif parsed.scheme == 'ssh' and parsed.username == 'git' and parsed.password is None and port in {None, 22}:
            path = parsed.path.lstrip('/')
        else:
            raise HandoffError('Unsupported origin transport/credentials/port; inspect without exposing credentials.')
    path = path.rstrip('/')
    if path.lower().endswith('.git'):
        path = path[:-4]
    if path.lower() != EXPECTED_REPOSITORY:
        raise HandoffError('Origin points to a different repository.')
    return EXPECTED_REPOSITORY


def run_git(repo: Path, *args: str, allowed=(0,)) -> str:
    env = os.environ.copy()
    env['GIT_TERMINAL_PROMPT'] = '0'
    env['GCM_INTERACTIVE'] = 'never'
    try:
        proc = subprocess.run(['git', '-C', str(repo), *args], capture_output=True,
                              text=True, encoding='utf-8', errors='replace',
                              timeout=45, check=False, env=env, shell=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise HandoffError(f'Git command unavailable/timed out: {args[0]}') from exc
    if proc.returncode not in allowed:
        # Do not print arbitrary Git stderr: URLs can contain credentials.
        raise HandoffError(f'Git {args[0]} failed (exit {proc.returncode}); inspect locally. NOT SYNCHRONIZED.')
    return proc.stdout.strip()


def inspect_repository(repo: Path) -> dict:
    repo = Path(os.path.abspath(repo))
    ensure_no_links(repo)
    actual = Path(run_git(repo, 'rev-parse', '--show-toplevel')).resolve()
    if actual != repo.resolve():
        raise HandoffError('--repo must be the exact existing repository root.')
    fetch = run_git(repo, 'remote', 'get-url', '--all', 'origin').splitlines()
    push = run_git(repo, 'remote', 'get-url', '--push', '--all', 'origin').splitlines()
    if len(fetch) != 1 or len(push) != 1:
        raise HandoffError('Exactly one verified effective origin fetch/push URL is required.')
    for url in fetch + push:
        normalize_origin(url)
    branch = run_git(repo, 'branch', '--show-current')
    if not branch:
        raise HandoffError('Detached HEAD; inspect and select an intended feature branch.')
    head = run_git(repo, 'rev-parse', 'HEAD')
    if not re.fullmatch(r'[0-9a-f]{40,64}', head):
        raise HandoffError('Unexpected Git HEAD identity.')
    dirty = bool(run_git(repo, 'status', '--porcelain', '--untracked-files=all'))
    return {'repository': 'PikkuJanne/WinAudioClean', 'branch': branch, 'head': head, 'clean': not dirty}


def install_bundle(bundle: Path, repo: Path, *, apply=False, expected_head=None, ack_reviewed_head=None) -> dict:
    verify_bundle(bundle)
    bundle = bundle.resolve()
    repo = Path(os.path.abspath(repo))
    info = inspect_repository(repo)
    if bundle.is_relative_to(repo.resolve()) or repo.resolve().is_relative_to(bundle):
        raise HandoffError('Extract the bundle outside and separate from the repository.')
    payload = bundle / 'payload'
    creates: list[tuple[Path, Path]] = []
    identical: list[str] = []
    conflicts: list[str] = []
    for source in sorted(payload.rglob('*')):
        if '__pycache__' in source.parts or source.suffix == '.pyc':
            continue
        if not source.is_file():
            continue
        relative = source.relative_to(payload).as_posix()
        if not payload_allowed(relative):
            raise HandoffError('Out-of-scope payload file.')
        target = safe_member(repo, relative)
        # Existing ancestor must be a directory, never an ordinary file.
        for parent in target.parents:
            if parent == repo:
                break
            if parent.exists() and not parent.is_dir():
                conflicts.append(relative + ' (ancestor is not a directory)')
                break
        else:
            pass
        if target.exists():
            if target.is_file() and digest(target) == digest(source):
                identical.append(relative)
            else:
                conflicts.append(relative)
        else:
            creates.append((source, target))
    result = {'mode': 'apply' if apply else 'preview', **info,
              'create': [t.relative_to(repo).as_posix() for _, t in creates],
              'identical': identical, 'conflicts': sorted(set(conflicts)),
              'drift_from_reviewed_baseline': info['head'] != BASELINE,
              'applied': False}
    if not apply:
        return result
    if conflicts:
        raise HandoffError('Existing files differ; merge governance additively. Nothing was written.')
    if not info['clean']:
        raise HandoffError('Dirty worktree: preserve/reconcile existing work first. Nothing was written.')
    if not info['branch'].startswith('codex/wac-'):
        raise HandoffError('Apply requires the intended codex/wac- feature branch, not main or unrelated work.')
    if expected_head != info['head']:
        raise HandoffError('--expected-head must equal the current inspected HEAD.')
    if info['head'] != BASELINE and ack_reviewed_head != info['head']:
        raise HandoffError('Newer/different HEAD: inspect drift and pass its exact --ack-reviewed-head.')
    # Recheck immediately before writing; this is a single-active-machine tool,
    # not a security boundary against hostile concurrent filesystem mutation.
    if inspect_repository(repo) != info:
        raise HandoffError('Repository state changed during preflight; preview again.')
    created: list[Path] = []
    try:
        for source, target in creates:
            ensure_no_links(target)
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as stream:
                created.append(target)
                stream.write(source.read_bytes())
            if digest(target) != digest(source):
                raise HandoffError('Post-copy verification failed.')
    except (OSError, HandoffError):
        for target in reversed(created):
            # Only files exclusively created by this run are candidates.
            if target.is_file() and not link_or_reparse(target):
                target.unlink()
        raise HandoffError('Apply failed; run-created files rolled back. Existing files were not overwritten.')
    result['applied'] = True
    return result


def sync_check(repo: Path) -> dict:
    info = inspect_repository(repo)
    if not info['clean']:
        raise HandoffError('Worktree is dirty. NOT SYNCHRONIZED as a complete checkpoint.')
    branch = info['branch']
    if not branch.startswith('codex/wac-'):
        raise HandoffError('Expected an intended codex/wac- delivery branch, not main or unrelated work.')
    upstream = run_git(repo, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}')
    if upstream != f'origin/{branch}':
        raise HandoffError('Upstream does not match the delivery branch on origin. NOT SYNCHRONIZED.')
    cached = run_git(repo, 'rev-parse', '@{upstream}')
    rows = run_git(repo, 'ls-remote', '--exit-code', 'origin', f'refs/heads/{branch}').splitlines()
    if len(rows) != 1:
        raise HandoffError('Live remote branch was not resolved uniquely. NOT SYNCHRONIZED.')
    parts = rows[0].split()
    if len(parts) != 2 or parts[1] != f'refs/heads/{branch}':
        raise HandoffError('Unexpected live remote response. NOT SYNCHRONIZED.')
    live = parts[0]
    if live != info['head'] or cached != info['head']:
        raise HandoffError('Local HEAD, upstream cache and live remote differ. Fetch/reconcile; NOT SYNCHRONIZED.')
    if inspect_repository(repo) != info:
        raise HandoffError('Local state changed during live verification. NOT SYNCHRONIZED.')
    return {**info, 'live_remote_head': live, 'upstream': upstream, 'synchronized': True,
            'note': 'Point-in-time branch verification only; PR/CI/publication state must be inspected separately.'}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('verify', help='Verify immutable extracted bundle hashes and plan.')
    p.add_argument('--bundle', type=Path, required=True)
    for command in ('validate-plan', 'next'):
        p = sub.add_parser(command)
        p.add_argument('--plan-root', type=Path, required=True)
    p = sub.add_parser('install', help='Preview (default) or exclusively create missing payload files.')
    p.add_argument('--bundle', type=Path, required=True)
    p.add_argument('--repo', type=Path, required=True)
    p.add_argument('--apply', action='store_true')
    p.add_argument('--expected-head')
    p.add_argument('--ack-reviewed-head')
    for command in ('inspect', 'sync-check'):
        p = sub.add_parser(command)
        p.add_argument('--repo', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'verify':
            result = verify_bundle(args.bundle)
        elif args.command == 'validate-plan':
            result = validate_plan(args.plan_root)
        elif args.command == 'next':
            result = next_tasks(args.plan_root)
        elif args.command == 'install':
            result = install_bundle(args.bundle, args.repo, apply=args.apply,
                                    expected_head=args.expected_head, ack_reviewed_head=args.ack_reviewed_head)
        elif args.command == 'inspect':
            result = inspect_repository(args.repo)
        else:
            result = sync_check(args.repo)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 2 if result.get('conflicts') else 0
    except (HandoffError, OSError, KeyError, TypeError, ValueError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
