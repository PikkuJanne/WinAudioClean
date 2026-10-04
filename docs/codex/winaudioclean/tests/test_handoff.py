"""Tests for the handoff helpers, NOT WinAudioClean application acceptance.

All writes/Git operations occur in temporary fixture directories. Live-sync
responses are mocked except one explicitly local bare-repository round trip.
No GitHub writes, downloads or private audio are used.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import wave

DOC = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(DOC / 'tools'))
import handoff as h
import generate_fixtures as f


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def make_manifest(bundle):
    files=[]
    for path in h.iter_bundle_files(bundle):
        rel=path.relative_to(bundle).as_posix()
        if rel in {h.MANIFEST_NAME, h.SUMS_NAME}:
            continue
        files.append({'path':rel,'bytes':path.stat().st_size,'sha256':h.digest(path)})
    write_json(bundle/h.MANIFEST_NAME, {'schema_version':1,'repository':'PikkuJanne/WinAudioClean','files':files})
    sums={e['path']:e['sha256'] for e in files}
    sums[h.MANIFEST_NAME]=h.digest(bundle/h.MANIFEST_NAME)
    (bundle/h.SUMS_NAME).write_text(''.join(f'{v}  {k}\n' for k,v in sorted(sums.items())),encoding='utf-8')


def git(repo, *args):
    p=subprocess.run(['git','-C',str(repo),*args],capture_output=True,text=True,
                     encoding='utf-8',errors='replace',check=True)
    return p.stdout.strip()


class CanonicalPlanTests(unittest.TestCase):
    def test_current_plan_is_valid(self):
        # Validate real task progress without assuming an initial todo state.
        self.assertTrue(h.validate_plan(DOC)['valid'])


class PlanTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name)/'plan'
        shutil.copytree(DOC,self.root,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
        self.plan=json.loads((self.root/'TASKS.yaml').read_text(encoding='utf-8-sig'))
        self.accept=json.loads((self.root/'ACCEPTANCE.json').read_text(encoding='utf-8-sig'))
        # State-machine cases start fresh only in this temporary fixture.
        # Canonical task progress is checked separately and never reset.
        for task in self.plan['tasks']:
            task.update(status='todo',evidence=[],blocked_reason=None)
            task.pop('approval_ref',None)
        for case in self.accept['cases']:
            case.update(status='not_run',evidence=[])
            case.pop('reason',None)
            case.pop('disposition_ref',None)
        self.save()
    def tearDown(self): self.temp.cleanup()
    def save(self):
        write_json(self.root/'TASKS.yaml',self.plan)
        write_json(self.root/'ACCEPTANCE.json',self.accept)
    def bad(self):
        self.save()
        with self.assertRaises(h.HandoffError): h.validate_plan(self.root)
    def test_initial_plan(self):
        result=h.validate_plan(self.root)
        self.assertEqual((result['tasks'],result['acceptance_cases'],result['improvements']),(30,90,20))
    def test_next_is_governance_only(self):
        self.assertEqual([t['id'] for t in h.next_tasks(self.root)['ready']],['WAC-M0-01'])
    def test_duplicate_task_rejected(self):
        self.plan['tasks'].append(self.plan['tasks'][0].copy()); self.bad()
    def test_duplicate_acceptance_rejected(self):
        self.accept['cases'].append(self.accept['cases'][0].copy()); self.bad()
    def test_missing_dependency_rejected(self):
        self.plan['tasks'][0]['depends_on']=['WAC-M9-99']; self.bad()
    def test_cycle_rejected(self):
        self.plan['tasks'][0]['depends_on']=['WAC-M0-02']; self.bad()
    def test_missing_brief_rejected(self):
        (self.root/'tasks/WAC-M0-01.md').unlink()
        with self.assertRaises(h.HandoffError): h.validate_plan(self.root)
    def test_orphan_case_rejected(self):
        self.accept['cases'][0]['task_id']='WAC-M0-02'; self.bad()
    def test_unknown_state_rejected(self):
        self.plan['tasks'][0]['status']='verified_by_assumption'; self.bad()
    def test_done_without_evidence_rejected(self):
        self.plan['tasks'][0]['status']='done'; self.bad()
    def test_pass_without_evidence_rejected(self):
        self.accept['cases'][0]['status']='pass'; self.bad()
    def test_skip_without_reason_rejected(self):
        self.accept['cases'][0]['status']='not_applicable'; self.bad()
    def test_blocked_without_reason_rejected(self):
        self.plan['tasks'][0]['status']='blocked'; self.bad()
    def test_deferred_without_approval_rejected(self):
        self.plan['tasks'][0]['status']='deferred'
        self.plan['tasks'][0]['blocked_reason']='not available'; self.bad()
    def test_evidence_path_traversal_rejected(self):
        self.accept['cases'][0].update(status='pass',evidence=['../outside.txt']); self.bad()
    def test_done_with_real_evidence_unlocks_next(self):
        (self.root/'evidence/test.md').write_text('Fixture test evidence, not product evidence.',encoding='utf-8')
        self.plan['tasks'][0].update(status='done',evidence=['evidence/test.md'])
        for c in self.accept['cases'][:3]: c.update(status='pass',evidence=['evidence/test.md'])
        self.save()
        h.validate_plan(self.root)
        self.assertEqual(h.next_tasks(self.root)['ready'][0]['id'],'WAC-M0-02')
    def test_done_before_dependencies_rejected(self):
        (self.root/'evidence/test.md').write_text('Fixture evidence',encoding='utf-8')
        self.plan['tasks'][1].update(status='done',evidence=['evidence/test.md'])
        for c in self.accept['cases'][3:6]: c.update(status='pass',evidence=['evidence/test.md'])
        self.bad()
    def test_all_improvements_required(self):
        for t in self.plan['tasks']:
            t['improvements']=[i for i in t['improvements'] if i!=20] or [19]
        self.bad()
    def test_publication_is_approval_gated(self):
        self.assertTrue(self.plan['tasks'][-1]['approval_required'])
        self.assertFalse(self.plan['tasks'][-1].get('approval_ref'))


class PathAndOriginTests(unittest.TestCase):
    def test_safe_paths(self):
        for value in ['AGENTS.md','docs/codex/winaudioclean/README.md','input [mix] äö Å.txt']:
            self.assertEqual(h.safe_relative(value).as_posix(),value)
    def test_unsafe_paths(self):
        for value in ['', '.', '..', '../x', '/x', 'C:/x', 'a\\b', 'a/../b','a//b','.git/config']:
            with self.subTest(value=value),self.assertRaises(h.HandoffError): h.safe_relative(value)
    def test_supported_origin_forms(self):
        for value in ['git@github.com:PikkuJanne/WinAudioClean.git','https://github.com/PikkuJanne/WinAudioClean.git','ssh://git@github.com/PikkuJanne/WinAudioClean.git']:
            self.assertEqual(h.normalize_origin(value),h.EXPECTED_REPOSITORY)
    def test_bad_origins(self):
        for value in ['https://github.com/PikkuJanne/Other.git','https://user:secret@github.com/PikkuJanne/WinAudioClean.git','http://github.com/PikkuJanne/WinAudioClean.git','git@evil.example:PikkuJanne/WinAudioClean.git','/tmp/local.git','https://github.com.evil.example/PikkuJanne/WinAudioClean.git']:
            with self.subTest(value=value),self.assertRaises(h.HandoffError): h.normalize_origin(value)
    def test_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); (root/'a').mkdir()
            try: (root/'b').symlink_to(root/'a',target_is_directory=True)
            except OSError: self.skipTest('Symlink privileges unavailable')
            with self.assertRaises(h.HandoffError): h.safe_member(root,'b/file')
    def test_payload_is_governance_only(self):
        self.assertTrue(h.payload_allowed('AGENTS.md'))
        self.assertTrue(h.payload_allowed('docs/codex/winaudioclean/STATUS.md'))
        self.assertFalse(h.payload_allowed('WinAudioClean.ps1'))
        self.assertFalse(h.payload_allowed('README.md'))


class BundleAndInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.base=Path(self.temp.name)
        self.bundle=self.base/'bundle'; self.bundle.mkdir()
        self.doc=self.bundle/'payload'/h.DOC_REL
        shutil.copytree(DOC,self.doc,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
        (self.bundle/'payload/AGENTS.md').write_text('Fixture governance\n',encoding='utf-8')
        (self.bundle/'README.md').write_text('Fixture bundle\n',encoding='utf-8')
        make_manifest(self.bundle)
        self.repo=self.base/'repo'; self.repo.mkdir()
        git(self.repo,'init','-b','main')
        git(self.repo,'config','user.name','Handoff test')
        git(self.repo,'config','user.email','test@example.invalid')
        git(self.repo,'remote','add','origin','https://github.com/PikkuJanne/WinAudioClean.git')
        self.product_files=('WinAudioClean.ps1','WinAudioClean.bat','README.md')
        for name in self.product_files:
            (self.repo/name).write_text(f'Fixture {name}; must stay unchanged\n',encoding='utf-8')
        git(self.repo,'add',*self.product_files); git(self.repo,'commit','-m','fixture baseline')
        git(self.repo,'switch','-c','codex/wac-test')
        self.head=git(self.repo,'rev-parse','HEAD')
    def tearDown(self): self.temp.cleanup()
    def apply(self,**kwargs):
        return h.install_bundle(self.bundle,self.repo,apply=True,expected_head=self.head,
                                ack_reviewed_head=self.head,**kwargs)
    def snapshot(self):
        members=[p for p in self.repo.rglob('*') if '.git' not in p.relative_to(self.repo).parts]
        return {
            'head':git(self.repo,'rev-parse','HEAD'),
            'branch':git(self.repo,'branch','--show-current'),
            'status':git(self.repo,'status','--porcelain','--untracked-files=all'),
            'files':{p.relative_to(self.repo).as_posix():p.read_bytes() for p in members if p.is_file()},
            'directories':sorted(p.relative_to(self.repo).as_posix() for p in members if p.is_dir()),
        }
    def assert_apply_rejected_unchanged(self):
        before=self.snapshot()
        with self.assertRaises(h.HandoffError): self.apply()
        self.assertEqual(self.snapshot(),before)
    def test_valid_bundle(self): self.assertTrue(h.verify_bundle(self.bundle)['valid'])
    def test_tampered_file_rejected(self):
        (self.bundle/'README.md').write_text('tampered')
        with self.assertRaises(h.HandoffError): h.verify_bundle(self.bundle)
    def test_extra_file_rejected(self):
        (self.bundle/'extra').write_text('extra')
        with self.assertRaises(h.HandoffError): h.verify_bundle(self.bundle)
    def test_tampered_sums_rejected(self):
        (self.bundle/h.SUMS_NAME).write_text('wrong')
        with self.assertRaises(h.HandoffError): h.verify_bundle(self.bundle)
    def test_runtime_payload_rejected(self):
        (self.bundle/'payload/WinAudioClean.ps1').write_text('must not import')
        make_manifest(self.bundle)
        with self.assertRaises(h.HandoffError): h.verify_bundle(self.bundle)
    def test_preview_is_read_only(self):
        before=self.snapshot()
        result=h.install_bundle(self.bundle,self.repo)
        self.assertFalse(result['applied']); self.assertTrue(result['create'])
        self.assertEqual(self.snapshot(),before)
        self.assertFalse((self.repo/'AGENTS.md').exists())
    def test_apply_preserves_application(self):
        before={name:(self.repo/name).read_bytes() for name in self.product_files}
        self.assertTrue(self.apply()['applied'])
        self.assertEqual({name:(self.repo/name).read_bytes() for name in self.product_files},before)
        self.assertTrue((self.repo/'AGENTS.md').exists())
    def test_repeat_after_checkpoint_is_idempotent(self):
        self.apply(); git(self.repo,'add','AGENTS.md','docs'); git(self.repo,'commit','-m','fixture governance')
        self.head=git(self.repo,'rev-parse','HEAD')
        before=self.snapshot()
        result=self.apply()
        self.assertEqual(result['create'],[]); self.assertFalse(git(self.repo,'status','--porcelain'))
        self.assertEqual(self.snapshot(),before)
    def test_differing_agents_never_overwritten(self):
        (self.repo/'AGENTS.md').write_text('Existing rules\n',encoding='utf-8')
        git(self.repo,'add','AGENTS.md');git(self.repo,'commit','-m','existing rules');self.head=git(self.repo,'rev-parse','HEAD')
        before=self.snapshot()
        preview=h.install_bundle(self.bundle,self.repo)
        self.assertIn('AGENTS.md',preview['conflicts'])
        self.assertEqual(self.snapshot(),before)
        self.assert_apply_rejected_unchanged()
        self.assertEqual((self.repo/'AGENTS.md').read_text(encoding='utf-8'),'Existing rules\n')
        self.assertFalse((self.repo/'docs').exists())
    def test_dirty_apply_rejected(self):
        (self.repo/'personal_note.txt').write_text('Do not lose this',encoding='utf-8')
        self.assert_apply_rejected_unchanged()
        self.assertTrue((self.repo/'personal_note.txt').exists())
    def test_main_apply_rejected(self):
        git(self.repo,'switch','main')
        self.assert_apply_rejected_unchanged()
    def test_detached_head_rejected(self):
        git(self.repo,'checkout','--detach')
        self.assert_apply_rejected_unchanged()
    def test_wrong_origin_rejected(self):
        git(self.repo,'remote','set-url','origin','https://github.com/PikkuJanne/Other.git')
        self.assert_apply_rejected_unchanged()
    def test_multiple_push_destinations_rejected(self):
        git(self.repo,'config','--add','remote.origin.pushurl','https://github.com/PikkuJanne/WinAudioClean.git')
        git(self.repo,'config','--add','remote.origin.pushurl','https://github.com/PikkuJanne/Other.git')
        with self.assertRaises(h.HandoffError): h.inspect_repository(self.repo)
    def test_expected_head_mismatch_rejected(self):
        with self.assertRaises(h.HandoffError):
            h.install_bundle(self.bundle,self.repo,apply=True,expected_head='0'*40,ack_reviewed_head=self.head)
    def test_unreviewed_drift_rejected(self):
        with self.assertRaises(h.HandoffError):
            h.install_bundle(self.bundle,self.repo,apply=True,expected_head=self.head)
    def test_subdirectory_is_not_repository_root(self):
        sub=self.repo/'nested';sub.mkdir()
        with self.assertRaises(h.HandoffError): h.inspect_repository(sub)
    def test_copy_failure_rolls_back_only_new_files(self):
        original=Path.open
        def injected(path,mode='r',*args,**kwargs):
            if mode=='xb' and path.name=='AUDIT.md': raise PermissionError('fixture injection')
            return original(path,mode,*args,**kwargs)
        with mock.patch.object(Path,'open',injected):
            with self.assertRaises(h.HandoffError): self.apply()
        self.assertTrue((self.repo/'WinAudioClean.ps1').exists())
        self.assertFalse((self.repo/'AGENTS.md').exists())


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.info={'repository':'PikkuJanne/WinAudioClean','branch':'codex/wac-test','head':'a'*40,'clean':True}
    def response(self,repo,*args,**kwargs):
        if args[0]=='rev-parse' and '--abbrev-ref' in args:return 'origin/codex/wac-test'
        if args[0]=='rev-parse':return 'a'*40
        if args[0]=='ls-remote':return 'a'*40+'\trefs/heads/codex/wac-test'
        raise AssertionError(args)
    def test_equal_live_head_passes(self):
        with mock.patch.object(h,'inspect_repository',return_value=self.info),mock.patch.object(h,'run_git',side_effect=self.response):
            self.assertTrue(h.sync_check(Path('.'))['synchronized'])
    def test_stale_live_head_rejected(self):
        def response(repo,*args,**kwargs):
            if args[0]=='ls-remote':return 'b'*40+'\trefs/heads/codex/wac-test'
            return self.response(repo,*args,**kwargs)
        with mock.patch.object(h,'inspect_repository',return_value=self.info),mock.patch.object(h,'run_git',side_effect=response):
            with self.assertRaises(h.HandoffError):h.sync_check(Path('.'))
    def test_empty_live_ref_rejected(self):
        def response(repo,*args,**kwargs):
            return '' if args[0]=='ls-remote' else self.response(repo,*args,**kwargs)
        with mock.patch.object(h,'inspect_repository',return_value=self.info),mock.patch.object(h,'run_git',side_effect=response):
            with self.assertRaises(h.HandoffError):h.sync_check(Path('.'))
    def test_network_failure_not_success(self):
        def response(repo,*args,**kwargs):
            if args[0]=='ls-remote':raise h.HandoffError('network unavailable')
            return self.response(repo,*args,**kwargs)
        with mock.patch.object(h,'inspect_repository',return_value=self.info),mock.patch.object(h,'run_git',side_effect=response):
            with self.assertRaises(h.HandoffError):h.sync_check(Path('.'))
    def test_dirty_checkpoint_rejected(self):
        self.info['clean']=False
        with mock.patch.object(h,'inspect_repository',return_value=self.info):
            with self.assertRaises(h.HandoffError):h.sync_check(Path('.'))
    def test_wrong_upstream_rejected(self):
        with mock.patch.object(h,'inspect_repository',return_value=self.info),mock.patch.object(h,'run_git',return_value='other/branch'):
            with self.assertRaises(h.HandoffError):h.sync_check(Path('.'))
    def test_actual_local_bare_round_trip(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); bare=root/'remote.git';bare.mkdir();git(bare,'init','--bare')
            repo=root/'repo';repo.mkdir();git(repo,'init','-b','codex/wac-test')
            git(repo,'config','user.name','Handoff test');git(repo,'config','user.email','test@example.invalid')
            git(repo,'remote','add','origin',str(bare))
            (repo/'marker.txt').write_text('local fixture only')
            git(repo,'add','marker.txt');git(repo,'commit','-m','fixture checkpoint')
            git(repo,'push','--set-upstream','origin','HEAD:refs/heads/codex/wac-test')
            # Override endpoint normalization only inside this local fixture.
            # Every git operation including ls-remote is real, with no GitHub access.
            with mock.patch.object(h,'normalize_origin',return_value=h.EXPECTED_REPOSITORY):
                self.assertTrue(h.sync_check(repo)['synchronized'])
                (repo/'marker.txt').write_text('local ahead')
                git(repo,'add','marker.txt');git(repo,'commit','-m','unpushed fixture')
                with self.assertRaises(h.HandoffError):h.sync_check(repo)


class FixtureTests(unittest.TestCase):
    def test_fixture_format_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as td:
            out=Path(td)/'fixtures';result=f.generate(out)
            self.assertEqual(len(result['fixtures']),5)
            with wave.open(str(out/'synthetic_stereo_48k.wav'),'rb') as w:
                self.assertEqual((w.getframerate(),w.getnchannels(),w.getnframes()),(48000,2,384000))
            with self.assertRaises(FileExistsError): f.generate(out)
    def test_repeatable_pcm(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)
            a=f.write_pcm(p/'a.wav',rate=44100,channels=1,seconds=.1,kind='varying_tones')
            b=f.write_pcm(p/'b.wav',rate=44100,channels=1,seconds=.1,kind='varying_tones')
            self.assertEqual(a['sha256'],b['sha256'])
    def test_existing_file_preserved(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'a.wav';p.write_bytes(b'original')
            with self.assertRaises(FileExistsError): f.write_pcm(p,rate=48000,channels=1,seconds=.1,kind='silence')
            self.assertEqual(p.read_bytes(),b'original')


if __name__=='__main__':unittest.main()
