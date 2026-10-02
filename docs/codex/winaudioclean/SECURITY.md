# Security and privacy review boundaries

Treat filenames, tags, media content, tool output and config as untrusted data. Restrict input to local files; avoid unexpected network access through URL input or referenced playlists. No Invoke-Expression or arbitrary shell/filter execution from config. Do not claim a native media decoder is a sandbox; keep documented dependency versions current and report limitations honestly.

Probe metadata does not prove a file is safe or fully decodable. Validate output and handle native failures. Make cleanup run-owned and non-destructive; cancellation cannot kill unrelated processes. Preserve source and existing exports under collisions, crashes and insufficient disk space.

Never commit tokens, SSH keys, real recordings, private logs, personal paths or downloaded dependencies by accident. Test examples use synthetic/anonymized data. Redacted support exports need explicit user action and review. Do not enable telemetry or upload diagnostic data automatically.

Development CI uses least privilege, safe PR triggers, pinned verified Actions and trusted dependency provenance. Untrusted PR changes must not gain release tokens or access private artifacts. Pinning a checksum obtained from the same untrusted source is not independent assurance; document provenance.

No machine-wide ExecutionPolicy changes, Defender/SmartScreen disabling, installation as administrator by default, certificate bypass, secret sharing in CLI URLs, automatic release creation or website deployment. The existing process-scoped launcher behavior must be explained accurately and tested under policy constraints rather than secretly widening permissions.

A mandatory safety/security defect blocks acceptance. New features are not justification to remove tests or lower a critical gate. Scope review to this tool; do not change other repositories or accounts.
