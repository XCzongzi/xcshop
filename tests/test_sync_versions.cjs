'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { fetchReleases, buildIndex, syncVersions } = require('../tools/sync_versions.cjs');

const repository = 'XCzongzi/xcshop';
function release(id, overrides = {}) {
  return {
    id, tag_name: `v0.0.${id}`, name: null,
    draft: false, prerelease: false, published_at: '2026-11-01T00:00:00Z',
    html_url: `https://github.com/${repository}/releases/tag/v0.0.${id}`,
    body: '中文更新说明\n第二行', assets: [], ...overrides,
  };
}
function response(data) {
  return { ok: true, json: async () => data };
}
function temporaryOutput(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'xcshop-versions-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return path.join(directory, 'versions.json');
}

test('reads beyond 100 releases, including when a page contains drafts', async () => {
  const urls = [];
  const releases = await fetchReleases(repository, {
    token: 'test-token',
    fetchImpl: async (url, options) => {
      urls.push(url);
      assert.equal(options.headers.Authorization, 'Bearer test-token');
      return response(urls.length === 1
        ? Array.from({ length: 100 }, (_, i) => release(i, { draft: true }))
        : [release(100)]);
    },
  });
  assert.equal(releases.length, 101);
  assert.match(urls[0], /per_page=100&page=1$/);
  assert.match(urls[1], /per_page=100&page=2$/);
  assert.equal(buildIndex(repository, releases).releases.length, 1);
});

test('keeps prereleases and notes, excludes drafts and unfinished assets, sorts by publication time', () => {
  const asset = {
    name: '编辑器.zip', state: 'uploaded', size: 1024, content_type: 'application/zip',
    browser_download_url: 'https://github.com/XCzongzi/xcshop/releases/download/v0.0.2/editor.zip',
    digest: 'sha256:abc', download_count: 5,
  };
  const index = buildIndex(repository, [
    release(9, { draft: true }),
    release(10),
    release(2, { prerelease: true, published_at: '2026-11-02T00:00:00Z', assets: [
      asset, { ...asset, name: 'incomplete.zip', state: 'starter' },
    ] }),
  ]);
  assert.deepEqual(index.releases.map(r => r.id), [2, 10]);
  assert.equal(index.releases[0].prerelease, true);
  assert.equal(index.releases[0].name, 'v0.0.2');
  assert.equal(index.releases[0].body, '中文更新说明\n第二行');
  assert.deepEqual(index.releases[0].assets, [{
    name: asset.name, size: 1024, content_type: 'application/zip',
    browser_download_url: asset.browser_download_url, digest: 'sha256:abc',
  }]);
});

test('repeated runs are unchanged; edits and deletions replace the previous index', async t => {
  const output = temporaryOutput(t);
  let releases = [release(1), release(2)];
  const options = { repository, output, fetchImpl: async () => response(releases) };
  assert.deepEqual(await syncVersions(options), { count: 2, changed: true });
  const first = fs.readFileSync(output, 'utf8');
  releases.reverse();
  assert.deepEqual(await syncVersions(options), { count: 2, changed: false });
  assert.equal(fs.readFileSync(output, 'utf8'), first);
  releases = [release(1, { body: '修订说明' })];
  await syncVersions(options);
  assert.deepEqual(JSON.parse(fs.readFileSync(output)).releases.map(r => r.body), ['修订说明']);
  releases = [];
  await syncVersions(options);
  assert.deepEqual(JSON.parse(fs.readFileSync(output)).releases, []);
});

test('a later page failure preserves the previous file without temporary leftovers', async t => {
  const output = temporaryOutput(t);
  fs.writeFileSync(output, 'previous index');
  let requests = 0;
  await assert.rejects(syncVersions({ repository, output, fetchImpl: async () => {
    requests++;
    return requests === 1
      ? response(Array.from({ length: 100 }, (_, i) => release(i)))
      : { ok: false, status: 403 };
  } }), /HTTP 403 \(page 2\)/);
  assert.equal(fs.readFileSync(output, 'utf8'), 'previous index');
  assert.deepEqual(fs.readdirSync(path.dirname(output)), ['versions.json']);
});

test('malformed responses fail without replacing the previous index', async t => {
  const output = temporaryOutput(t);
  fs.writeFileSync(output, 'previous index');
  for (const data of [{ message: 'API error' }, [{ id: 1 }], [null]]) {
    await assert.rejects(syncVersions({ repository, output, fetchImpl: async () => response(data) }));
    assert.equal(fs.readFileSync(output, 'utf8'), 'previous index');
  }
});

test('volatile download counts and asset order do not change the index', () => {
  const assets = ['b.zip', 'a.zip'].map(name => ({ name, state: 'uploaded', size: 1,
    content_type: 'application/zip', browser_download_url: `https://example.com/${name}` }));
  const first = buildIndex(repository, [release(1, { assets })]);
  const second = buildIndex(repository, [release(1, {
    assets: assets.toReversed().map(asset => ({ ...asset, download_count: 99 })),
  })]);
  assert.deepEqual(first, second);
});
