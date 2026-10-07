#!/usr/bin/env python3
"""Read-only static metadata and artifact checks; development Python only.

The shipped website/tool has no Python dependency. Published fixture metadata
is constructed from an actual local package; optional fixture output is limited
to ignored local QA storage. No release URL is invented or probed and no network
request is made.
"""
from __future__ import annotations

import argparse
import copy
from datetime import date
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import zipfile

REPO = Path(__file__).resolve().parents[1]
CONSENT_FIELDS = ["assetSha256", "ownerPermission", "speakerPermission", "permittedUse",
                  "clearedOn", "reviewer", "withdrawalContact"]
SCHEMA_KEYS = {"$schema", "title", "description", "type", "additionalProperties", "required",
               "properties", "items", "const", "enum", "pattern", "minLength", "maxLength",
               "minItems", "uniqueItems", "minimum", "allOf", "if", "then"}


class WebsiteError(Exception):
    """Only fixed codes from this module reach public output."""


def require(condition, code):
    if not condition:
        raise WebsiteError(code)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(data):
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, "duplicate_json_field")
            result[key] = value
        return result

    def nonfinite(_):
        raise WebsiteError("nonfinite_json")

    try:
        return json.loads(data.decode("utf-8-sig"), object_pairs_hook=pairs,
                          parse_constant=nonfinite)
    except (ValueError, UnicodeError) as exc:
        raise WebsiteError("invalid_json") from exc


def json_equal(left, right):
    # Keep boolean 1/0 impostors out of enum/const checks.
    return type(left) is type(right) and left == right


def validate_schema(value, schema):
    """Validate the explicit subset used by release.schema.json, without packages.

    This is not a general JSON Schema engine. Unknown schema keywords fail so a
    later schema extension cannot silently bypass the local release gate.
    Cross-field date/URL/source/artifact checks are performed separately.
    """
    require(isinstance(schema, dict) and set(schema) <= SCHEMA_KEYS, "unsupported_schema")
    types = {"null": lambda v: v is None, "object": lambda v: type(v) is dict,
             "array": lambda v: type(v) is list, "string": lambda v: type(v) is str,
             "integer": lambda v: type(v) is int}
    if "type" in schema:
        choices = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
        require(all(choice in types for choice in choices), "unsupported_schema")
        require(any(types[choice](value) for choice in choices), "metadata_schema")
    if "const" in schema:
        require(json_equal(value, schema["const"]), "metadata_schema")
    if "enum" in schema:
        require(any(json_equal(value, choice) for choice in schema["enum"]), "metadata_schema")
    if type(value) is dict:
        require(all(key in value for key in schema.get("required", [])), "metadata_schema")
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            require(set(value) <= set(properties), "metadata_schema")
        for key in set(value) & set(properties):
            validate_schema(value[key], properties[key])
    if type(value) is list:
        require(len(value) >= schema.get("minItems", 0), "metadata_schema")
        if schema.get("uniqueItems"):
            require(len({json.dumps(item, sort_keys=True) for item in value}) == len(value),
                    "metadata_schema")
        if "items" in schema:
            for item in value:
                validate_schema(item, schema["items"])
    if type(value) is str:
        require(len(value) >= schema.get("minLength", 0) and
                len(value) <= schema.get("maxLength", len(value)), "metadata_schema")
        if "pattern" in schema:
            require(re.fullmatch(schema["pattern"], value) is not None, "metadata_schema")
    if type(value) is int and "minimum" in schema:
        require(value >= schema["minimum"], "metadata_schema")
    for subschema in schema.get("allOf", []):
        validate_schema(value, subschema)
    if "if" in schema:
        try:
            validate_schema(value, schema["if"])
        except WebsiteError as exc:
            if str(exc) != "metadata_schema":
                raise
        else:
            if "then" in schema:
                validate_schema(value, schema["then"])


def package_module(repo):
    spec = importlib.util.spec_from_file_location("wac_website_package", repo / "scripts/Test-ReleasePackage.py")
    module = importlib.util.module_from_spec(spec)
    previous = sys.dont_write_bytecode
    sys.dont_write_bytecode = True
    try:
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = previous
    module.REPO = repo
    return module


def validate_release(metadata, schema, source_version=None):
    validate_schema(metadata, schema)
    if source_version is not None:
        require(metadata["version"] == source_version, "source_version_mismatch")
    # A nonempty whitespace-only requirements string is not useful guidance.
    requirements = metadata["requirements"]
    require(all(item.strip() for item in requirements["platforms"]) and
            all(requirements[key].strip() for key in ("ffmpeg", "installation", "privacy")),
            "empty_requirements")
    if metadata["status"] == "draft":
        return {"status": "draft", "download_enabled": False, "version": metadata["version"]}
    try:
        require(date.fromisoformat(metadata["date"]).isoformat() == metadata["date"], "invalid_date")
    except ValueError as exc:
        raise WebsiteError("invalid_date") from exc
    download = metadata["download"]
    expected_name = "WinAudioClean-%s-%s-tool-only.zip" % (metadata["version"], metadata["source"]["commit"][:12])
    require(download["fileName"] == expected_name, "download_name_mismatch")
    url = download["url"]
    allowed_remote = r"https://github\.com/PikkuJanne/WinAudioClean/releases/download/[A-Za-z0-9][A-Za-z0-9._-]*/" + re.escape(expected_name)
    require(url == expected_name or re.fullmatch(allowed_remote, url) is not None, "download_url_mismatch")
    return {"status": "published", "download_enabled": True, "version": metadata["version"]}


def inspect_package(metadata, archive, repo, schema=None):
    schema = schema or read_json((repo / "website/release.schema.json").read_bytes())
    validate_release(metadata, schema)
    require(metadata["status"] == "published", "package_requires_published_metadata")
    archive = Path(archive).resolve()
    package = package_module(repo)
    try:
        package.ordinary_path(archive, file=True)
        expected, blobs = package.expected_source(metadata["source"]["commit"])
        require(metadata["version"] == expected["version"] and
                metadata["source"]["tree"] == expected["source_tree"], "package_source_mismatch")
        _, facts = package.inspect_archive(archive, expected, blobs)
    except package.CheckError as exc:
        raise WebsiteError("package_" + str(exc)) from exc
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        raise WebsiteError("package_unreadable") from exc
    require(metadata["download"]["fileName"] == archive.name, "package_name_mismatch")
    require(metadata["download"]["sha256"] == facts["zip_sha256"], "package_hash_mismatch")
    require(metadata["download"]["bytes"] == archive.stat().st_size, "package_size_mismatch")
    return dict(facts, zip_bytes=archive.stat().st_size)


def metadata_from_package(archive, repo, draft, schema):
    """Return an in-memory published-like fixture bound to existing package bytes."""
    package = package_module(repo)
    try:
        package.ordinary_path(Path(archive).resolve(), file=True)
        with zipfile.ZipFile(archive) as stream:
            manifest = read_json(stream.read("PACKAGE-MANIFEST.json"))
        commit = manifest["source_commit"]
        require(type(commit) is str and re.fullmatch(r"[0-9a-f]{40}", commit), "fixture_source_invalid")
        source_date = package.git("show", "-s", "--format=%cs", commit).decode("ascii").strip()
        fixture = copy.deepcopy(draft)
        fixture.update(status="published", version=manifest["version"], date=source_date,
                       source={"commit": commit, "tree": manifest["source_tree"]},
                       download={"url": Path(archive).name, "fileName": Path(archive).name,
                                 "sha256": digest(Path(archive).read_bytes()), "bytes": Path(archive).stat().st_size})
        inspect_package(fixture, archive, repo, schema)
        return fixture
    except (OSError, KeyError, ValueError, zipfile.BadZipFile, package.CheckError) as exc:
        raise WebsiteError("fixture_package_invalid") from exc


def validate_assets(registry, website, repo):
    require(type(registry) is dict and set(registry) == {"schemaVersion", "branding", "screenshots", "audio"} and
            type(registry["schemaVersion"]) is int and registry["schemaVersion"] == 1, "asset_registry_schema")
    branding = registry["branding"]
    require(type(branding) is dict and set(branding) == {"status", "path", "source", "license", "rights", "sha256"} and
            branding["status"] == "available" and branding["path"] == "WinAudioClean_icon.png" and
            branding["source"] == "WinAudioClean_icon.png" and branding["license"] == "LICENSE" and
            branding["rights"] == "Repository MIT license; copyright (c) 2025 Janne Vuorela", "branding_rights")
    for key in ("screenshots", "audio"):
        entry = registry[key]
        keys = {"status", "items", "reason"} | ({"consent"} if key == "audio" else set())
        require(type(entry) is dict and set(entry) == keys and entry["status"] == "pending" and
                type(entry["items"]) is list and entry["items"] == [] and
                type(entry["reason"]) is str and bool(entry["reason"].strip()), "uncleared_asset")
    require(registry["audio"]["consent"] == {"requiredBeforePublication": True, "recordFields": CONSENT_FIELDS} and
            type(registry["audio"]["consent"].get("requiredBeforePublication")) is bool, "audio_consent_policy")
    try:
        icon = (website / branding["path"]).read_bytes()
        source = (repo / branding["source"]).read_bytes()
        license_bytes = (website / "LICENSE").read_bytes()
        require(icon == source and digest(icon) == branding["sha256"], "branding_bytes_mismatch")
        require(license_bytes == (repo / "LICENSE").read_bytes(), "branding_license_mismatch")
    except OSError as exc:
        raise WebsiteError("branding_asset_missing") from exc
    return {"branding_sha256": digest(icon), "license_sha256": digest(license_bytes),
            "screenshots": "pending", "audio": "pending", "consent_required": True}


def fixture_checks(fixture, archive, repo, schema):
    """Corrupt each independent binding while retaining a real positive package."""
    checks = []
    for case in ("draft_with_download", "invalid_date", "wrong_url", "wrong_name", "wrong_hash", "wrong_size", "wrong_tree"):
        invalid = copy.deepcopy(fixture)
        if case == "draft_with_download":
            invalid["status"] = "draft"
        elif case == "invalid_date":
            invalid["date"] = "2026-02-30"
        elif case == "wrong_url":
            invalid["download"]["url"] = "https://example.invalid/" + invalid["download"]["fileName"]
        elif case == "wrong_name":
            short_commit = invalid["source"]["commit"][:12]
            wrong_commit = ("0" if short_commit[0] != "0" else "1") + short_commit[1:]
            invalid["download"]["fileName"] = invalid["download"]["fileName"].replace(short_commit, wrong_commit)
        elif case == "wrong_hash":
            hash_value = invalid["download"]["sha256"]
            invalid["download"]["sha256"] = ("0" if hash_value[0] != "0" else "1") + hash_value[1:]
        elif case == "wrong_size":
            invalid["download"]["bytes"] += 1
        elif case == "wrong_tree":
            tree = invalid["source"]["tree"]
            invalid["source"]["tree"] = ("0" if tree[0] != "0" else "1") + tree[1:]
        try:
            inspect_package(invalid, archive, repo, schema)
        except WebsiteError as exc:
            checks.append({"id": case, "rejected": True, "code": str(exc)})
        else:
            raise WebsiteError("fixture_mutation_not_rejected")
    return checks


def write_fixture(fixture, output, repo):
    # Fixture publication is restricted to local task scratch space, and never
    # replaces prior bytes. Committed release metadata remains unchanged.
    original_output = output.absolute()
    output = original_output.resolve(strict=False)
    task_root = (repo / ".wac-local/WAC-M5-01").resolve(strict=False)
    require(output.is_relative_to(task_root) and output.suffix == ".json", "fixture_output_scope")
    package = package_module(repo)
    try:
        package.ordinary_path(original_output.parent)
        package.ordinary_path(output.parent)
        require(not output.exists(), "fixture_output_exists")
        with output.open("xb") as stream:
            stream.write((json.dumps(fixture, indent=2) + "\n").encode("utf-8"))
    except package.CheckError as exc:
        raise WebsiteError("fixture_" + str(exc)) from exc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=REPO)
    parser.add_argument("--release", type=Path, help="Default: repository website/release.json")
    parser.add_argument("--package", type=Path, help="Actual ZIP required when checking published metadata")
    parser.add_argument("--fixture-package", type=Path, help="Validate a published-like in-memory fixture from this actual ZIP")
    parser.add_argument("--fixture-output", type=Path, help="Optional new JSON file beneath ignored .wac-local/WAC-M5-01 for browser QA")
    args = parser.parse_args()
    repo = args.repo.resolve()
    try:
        schema = read_json((repo / "website/release.schema.json").read_bytes())
        metadata = read_json((args.release or repo / "website/release.json").read_bytes())
        package = package_module(repo)
        try:
            version = package.source_version((repo / "WinAudioClean.ps1").read_bytes())
        except package.CheckError as exc:
            raise WebsiteError("source_" + str(exc)) from exc
        release = validate_release(metadata, schema, version)
        summary = {"schema_version": 1, "passed": True, "python_version": sys.version.split()[0],
                   "release": release, "assets": validate_assets(read_json((repo / "website/assets.json").read_bytes()), repo / "website", repo),
                   "metadata_sha256": digest((args.release or repo / "website/release.json").read_bytes()),
                   "schema_sha256": digest((repo / "website/release.schema.json").read_bytes())}
        if metadata["status"] == "published":
            require(args.package is not None, "published_package_required")
            summary["package"] = inspect_package(metadata, args.package, repo, schema)
        if args.fixture_package is not None:
            fixture = metadata_from_package(args.fixture_package, repo, metadata, schema)
            summary["published_like_fixture"] = dict(inspect_package(fixture, args.fixture_package, repo, schema),
                                                       served=False, published=False,
                                                       mutations=fixture_checks(fixture, args.fixture_package, repo, schema))
            if args.fixture_output is not None:
                write_fixture(fixture, args.fixture_output, repo)
                summary["published_like_fixture"]["local_fixture_written"] = True
        else:
            require(args.fixture_output is None, "fixture_package_required")
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 0
    except (WebsiteError, OSError) as exc:
        code = str(exc) if isinstance(exc, WebsiteError) else "required_file_unavailable"
        print(json.dumps({"schema_version": 1, "passed": False, "code": code}, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
