# Static product page

This directory is a portable presentation package: HTML, CSS, JavaScript, local
JSON metadata, the existing repository icon and its MIT license. It contains no
hosting configuration, upload form, accounts, processing service, analytics or
updater. The PowerShell/BAT application never reads this directory or contacts
the page. Website requests are limited to its static files and deliberate links.

Copy this complete directory to a future tools website when publication is
separately approved. GitHub `v1.0.0` publication is explicitly approved; website
hosting remains deferred to the future multi-tool project. During preparation,
committed `release.json` remains a **draft**: version 1.0.0 comes from the existing
`scriptVersion` assignment, and its release date, source identity, URL, filename,
checksum and archive size are explicitly unavailable. A local candidate ZIP is
not a published release. The page starts with download disabled, validates all
metadata before enabling it, and retains the disabled state after load or
validation failure. Opening `index.html` with a `file:` URL may block JSON loads;
the pending/unavailable fallback still works.

## Local preview and validation

Development-only Python can serve this directory on loopback:

```powershell
python -m http.server 8765 --bind 127.0.0.1 --directory website
```

Open `http://127.0.0.1:8765/`. This server only previews the static page; Python
and a server are not tool installation requirements. Stop it with Ctrl+C.

From the repository root, validate the schema, current script version, original
icon/license bytes and pending sample-consent registry:

```powershell
python scripts/Test-Website.py --repo .
python -m unittest discover -s docs/codex/winaudioclean/tests -p test_website.py -v
```

To check a real candidate, add `--fixture-package <actual-tool-only-ZIP>` to the
first command. The validator builds a published-like fixture from the actual
archive's version/commit/tree and source date, with a **local basename**, measured
size and measured SHA256. It checks all committed payload bytes, the generated
manifest, checksum sidecar and provenance with the existing package inspector,
then rejects seven independently altered metadata fixtures. It never invents or
tests a remote release URL. Fixtures remain in memory unless `--fixture-output`
names a new JSON file below ignored `.wac-local/WAC-M5-01` for local browser QA;
create that parent directory first. Fixture success establishes package identity,
not authorization or remote availability, and never edits committed metadata.

`release.schema.json` uses JSON Schema draft 2020-12. The standard-library
validator implements only its explicitly documented keyword subset and rejects
unknown schema keywords. Additional cross-field checks bind filename to version
and source commit and check the calendar date. `published` requires every
artifact field, plus either the exact relative ZIP basename beside the metadata
or an HTTPS GitHub release asset URL for `PikkuJanne/WinAudioClean`. No query,
fragment, credentials, different host/repository or parent-path traversal is
accepted. `--package <actual-ZIP>` is mandatory when the metadata being checked
claims `published`. Publication still needs the existing explicit approval for
the exact revision, target and consequential action.

## Assets and consent

`WinAudioClean_icon.png` and `LICENSE` preserve the original repository bytes.
`assets.json` records the source path, real icon SHA256 and repository MIT rights;
the page carries Janne Vuorela's attribution and the full license. No invented
screenshot, testimonial, review or audio demo appears.

Screenshots and audio are explicitly pending with empty inventories. A screenshot
must be captured from the real application and reviewed for private paths and
content before use. Any future speech sample needs a retained consent record
bound to its SHA256, owner and speaker permission, permitted use, clearance date,
reviewer and withdrawal contact. This registry describes those required fields;
it does not claim permission was obtained. Keep private consent/contact records
outside the public page and source repository. Adding available media requires a
reviewed registry/validator update; this task intentionally accepts only the
recorded repository branding and empty pending media inventories.

The public copy describes Original Raw cleaning and Zoom/Teams leveling without
guaranteeing a result, retains the local processing boundary, and marks Gentle
as experimental where mentioned. Requirements match the existing README and
portable-package guide; this page does not broaden tested Windows/FFmpeg scope.
