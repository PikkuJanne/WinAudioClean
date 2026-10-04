/* Presentation only: read same-directory release data, never user media. */
(function () {
  'use strict';

  var metadataVersion = 1;
  var sha256Pattern = /^[a-f0-9]{64}(?![\s\S])/;
  var gitIdPattern = /^[a-f0-9]{40}(?![\s\S])/;
  var versionPattern = /^\d+\.\d+(?:\.\d+){0,2}(?![\s\S])/;
  var fileNamePattern = /^WinAudioClean-[0-9]+\.[0-9]+(?:\.[0-9]+){0,2}-[a-f0-9]{12}-tool-only\.zip(?![\s\S])/;

  function isRecord(value) {
    return value !== null && typeof value === 'object' && !Array.isArray(value);
  }

  function hasExactKeys(value, keys) {
    return isRecord(value) && Object.keys(value).length === keys.length &&
      keys.every(function (key) { return Object.prototype.hasOwnProperty.call(value, key); });
  }

  function nonemptyText(value) {
    return typeof value === 'string' && value.trim().length > 0 && value.length <= 2000;
  }

  function validDate(value) {
    if (typeof value !== 'string' || value.length !== 10 || !/^\d{4}-\d{2}-\d{2}$/.test(value)) { return false; }
    if (Number(value.slice(0, 4)) < 1) { return false; }
    var parsed = new Date(value + 'T00:00:00Z');
    return !isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
  }

  function validRequirements(value) {
    return hasExactKeys(value, ['platforms', 'powershell', 'ffmpeg', 'installation', 'privacy']) &&
      Array.isArray(value.platforms) && value.platforms.length > 0 && value.platforms.length <= 10 &&
      value.platforms.every(nonemptyText) && new Set(value.platforms).size === value.platforms.length &&
      Array.isArray(value.powershell) &&
      value.powershell.length === 2 && value.powershell[0] === '5.1' && value.powershell[1] === '7' &&
      nonemptyText(value.ffmpeg) && nonemptyText(value.installation) && nonemptyText(value.privacy);
  }

  function safeDownloadUrl(value, fileName) {
    if (typeof value !== 'string' || value.length > 512 || !fileNamePattern.test(fileName)) { return null; }
    // A portable published fixture can serve the exact validated ZIP beside this page.
    if (value === fileName) { return value; }
    if (!/^https:\/\/github\.com\/PikkuJanne\/WinAudioClean\/releases\/download\/[A-Za-z0-9][A-Za-z0-9._-]*\/WinAudioClean-[0-9]+\.[0-9]+(?:\.[0-9]+){0,2}-[a-f0-9]{12}-tool-only\.zip(?![\s\S])/.test(value)) { return null; }
    try {
      var url = new URL(value);
      var parts = url.pathname.split('/');
      if (url.href !== value || url.protocol !== 'https:' || url.hostname !== 'github.com' || url.port ||
          url.username || url.password || url.search || url.hash || parts.length !== 7 ||
          parts[1] !== 'PikkuJanne' || parts[2] !== 'WinAudioClean' ||
          parts[3] !== 'releases' || parts[4] !== 'download' ||
          !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(parts[5]) || parts[6] !== fileName) { return null; }
      return url.href;
    } catch (_) { return null; }
  }

  function validatedMetadata(value) {
    if (!hasExactKeys(value, ['schemaVersion', 'application', 'status', 'version', 'date', 'download', 'source', 'requirements']) ||
        value.schemaVersion !== metadataVersion || value.application !== 'WinAudioClean' ||
        (value.status !== 'draft' && value.status !== 'published') ||
        typeof value.version !== 'string' || value.version.length > 32 || !versionPattern.test(value.version) ||
        !hasExactKeys(value.download, ['url', 'fileName', 'sha256', 'bytes']) ||
        !hasExactKeys(value.source, ['commit', 'tree']) || !validRequirements(value.requirements)) { return null; }
    if (value.status === 'draft') {
      if (value.date !== null || value.download.url !== null || value.download.fileName !== null ||
          value.download.sha256 !== null || value.download.bytes !== null ||
          value.source.commit !== null || value.source.tree !== null) { return null; }
      return value;
    }
    if (!validDate(value.date) || typeof value.download.fileName !== 'string' ||
        !fileNamePattern.test(value.download.fileName) || typeof value.download.sha256 !== 'string' || value.download.sha256.length !== 64 ||
        !sha256Pattern.test(value.download.sha256) || !Number.isSafeInteger(value.download.bytes) ||
        value.download.bytes <= 0 || typeof value.source.commit !== 'string' || value.source.commit.length !== 40 ||
        !gitIdPattern.test(value.source.commit) || typeof value.source.tree !== 'string' || value.source.tree.length !== 40 ||
        !gitIdPattern.test(value.source.tree) ||
        value.download.fileName !== 'WinAudioClean-' + value.version + '-' + value.source.commit.slice(0, 12) + '-tool-only.zip' ||
        !safeDownloadUrl(value.download.url, value.download.fileName)) { return null; }
    return value;
  }

  function setText(id, value) {
    var node = document.getElementById(id);
    if (node) { node.textContent = value; }
  }

  function parseMetadataSource(source) {
    // JSON.parse verifies grammar. Scan the same bounded text to reject keys that
    // JSON.parse would silently overwrite, including escaped spellings of a key.
    var parsed = JSON.parse(source);
    var stack = [];
    var i = 0;
    while (i < source.length) {
      var character = source.charAt(i);
      var current = stack[stack.length - 1];
      if (character === '"') {
        var start = i;
        i += 1;
        while (i < source.length) {
          if (source.charAt(i) === '\\') { i += 2; }
          else if (source.charAt(i) === '"') { i += 1; break; }
          else { i += 1; }
        }
        if (current && current.type === 'object' && current.expectKey) {
          var key = JSON.parse(source.slice(start, i));
          if (current.keys.has(key)) { throw new Error('Duplicate metadata key'); }
          current.keys.add(key);
          current.expectKey = false;
        }
        continue;
      }
      if (character === '{') { stack.push({ type: 'object', keys: new Set(), expectKey: true }); }
      else if (character === '[') { stack.push({ type: 'array' }); }
      else if (character === '}' || character === ']') { stack.pop(); }
      else if (character === ',' && current && current.type === 'object') { current.expectKey = true; }
      i += 1;
    }
    return parsed;
  }

  function keepUnavailable(message) {
    var download = document.getElementById('release-download');
    if (download) { download.hidden = true; download.removeAttribute('href'); }
    var unavailable = document.getElementById('download-unavailable');
    if (unavailable) { unavailable.hidden = false; unavailable.disabled = true; }
    setText('release-badge', 'UNAVAILABLE');
    setText('release-state', 'Metadata unavailable');
    setText('release-status', message);
    setText('download-note', 'No working release link is claimed. Read the setup guide and source repository for current information.');
  }

  function render(value) {
    setText('release-version', value.version);
    if (value.status === 'draft') {
      setText('release-badge', 'DRAFT');
      setText('release-state', 'Draft / unpublished');
      setText('release-status', 'No published download is available.');
      return;
    }
    var download = document.getElementById('release-download');
    var unavailable = document.getElementById('download-unavailable');
    if (!download || !unavailable) { return; }
    setText('release-badge', 'PUBLISHED');
    setText('release-state', 'Published metadata');
    setText('release-date', value.date);
    setText('release-status', 'Tool-only ZIP · ' + value.download.bytes.toLocaleString('en-US') + ' bytes');
    setText('release-checksum', value.download.sha256);
    document.getElementById('release-checksum').classList.add('checksum');
    setText('download-note', 'Verify the ZIP against this SHA256 before extraction. FFmpeg and ffprobe are supplied separately. A checksum is not a digital signature.');
    download.setAttribute('href', safeDownloadUrl(value.download.url, value.download.fileName));
    download.setAttribute('aria-label', 'Download WinAudioClean ' + value.version + ' portable tool-only ZIP');
    unavailable.hidden = true;
    download.hidden = false;
  }

  // Opening index.html directly remains useful; browsers may prohibit local JSON reads.
  if (window.location.protocol === 'file:') {
    setText('release-status', 'Local file preview: metadata is not loaded; no download is enabled.');
    return;
  }
  if (window.location.protocol !== 'http:' && window.location.protocol !== 'https:') {
    keepUnavailable('Release metadata cannot be loaded in this preview.');
    return;
  }
  fetch('release.json', { credentials: 'omit', cache: 'no-store', redirect: 'error' })
    .then(function (response) {
      if (!response.ok) { throw new Error('Release metadata unavailable'); }
      return response.text();
    })
    .then(function (source) {
      if (source.length > 65536) { throw new Error('Release metadata is too large'); }
      var metadata = validatedMetadata(parseMetadataSource(source));
      if (!metadata) { throw new Error('Unsupported release metadata'); }
      render(metadata);
    })
    .catch(function () { keepUnavailable('Release metadata is unavailable or invalid. Downloads remain disabled.'); });
}());
