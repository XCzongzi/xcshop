// Build a public release index using only Node.js built-ins (Node.js 22+).
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { parseArgs } = require('node:util');

const defaultRepository = 'XCzongzi/xcshop';
const defaultOutput = path.join(__dirname, '..', 'versions.json');

async function fetchReleases(repository, { token, fetchImpl = fetch } = {}) {
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository)) {
    throw new Error('Repository must have the form owner/repo.');
  }
  const headers = {
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'xcshop-release-index',
  };
  if (token) headers.Authorization = `Bearer ${token}`;

  const releases = new Map();
  for (let page = 1; ; page++) {
    const url = `https://api.github.com/repos/${repository}/releases?per_page=100&page=${page}`;
    const response = await fetchImpl(url, { headers, signal: AbortSignal.timeout(30000) });
    if (!response.ok) throw new Error(`GitHub Releases API returned HTTP ${response.status} (page ${page}).`);
    const batch = await response.json();
    if (!Array.isArray(batch)) throw new Error('GitHub Releases API did not return an array.');
    for (const release of batch) {
      if (!Number.isSafeInteger(release?.id) || typeof release.draft !== 'boolean') {
        throw new Error('GitHub Releases API returned an invalid release.');
      }
      releases.set(release.id, release);
    }
    if (batch.length < 100) break;
  }
  return [...releases.values()];
}

function buildIndex(repository, releases) {
  return {
    schema_version: 1,
    repository,
    releases: releases.filter(release => !release.draft).map(release => ({
      id: release.id,
      tag_name: release.tag_name,
      name: release.name || release.tag_name,
      published_at: release.published_at,
      prerelease: release.prerelease,
      html_url: release.html_url,
      body: release.body || '',
      assets: release.assets.filter(asset => asset.state === 'uploaded').map(asset => ({
        name: asset.name,
        size: asset.size,
        content_type: asset.content_type,
        browser_download_url: asset.browser_download_url,
        digest: asset.digest || null,
      })).sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0),
    })).sort((a, b) => Date.parse(b.published_at) - Date.parse(a.published_at) || b.id - a.id),
  };
}

async function syncVersions({ repository = defaultRepository, output = defaultOutput, ...options } = {}) {
  // Fetch every page before replacing anything; API failures preserve the old index.
  const index = buildIndex(repository, await fetchReleases(repository, options));
  const contents = `${JSON.stringify(index, null, 2)}\n`;
  if (fs.existsSync(output) && fs.readFileSync(output, 'utf8') === contents) {
    return { count: index.releases.length, changed: false };
  }
  fs.mkdirSync(path.dirname(output), { recursive: true });
  const temporary = `${output}.${randomUUID()}.tmp`;
  try {
    fs.writeFileSync(temporary, contents, { encoding: 'utf8', flag: 'wx' });
    fs.renameSync(temporary, output);
  } finally {
    fs.rmSync(temporary, { force: true });
  }
  return { count: index.releases.length, changed: true };
}

if (require.main === module) {
  (async () => {
    const { values } = parseArgs({
      options: {
        repository: { type: 'string', default: process.env.GITHUB_REPOSITORY || defaultRepository },
        output: { type: 'string', default: defaultOutput },
      },
    });
    const result = await syncVersions({ ...values, token: process.env.GITHUB_TOKEN });
    console.log(`${values.output}: ${result.count} published releases (${result.changed ? 'updated' : 'unchanged'}).`);
  })().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = { fetchReleases, buildIndex, syncVersions };
