// Check source-package inputs using Git, the resource inventory and local files.
// Run from any directory: node tools/check_publish_inputs.cjs
const assert = require('node:assert/strict');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
const git = args => cp.execFileSync('git', args, {cwd: root, encoding: 'utf8'})
    .split('\0').filter(Boolean);
const candidates = new Set(git(['ls-files', '--cached', '--others', '--exclude-standard', '-z'])
    .filter(file => fs.existsSync(path.join(root, file))));

assert.deepEqual(git(['ls-files', '--cached', '--ignored', '--exclude-standard', '-z']), [],
    'Tracked local files must be removed from the index before publishing');

const qrcFiles = fs.readdirSync(root).filter(file => file.endsWith('.qrc'));
const resources = new Set();
for (const file of qrcFiles) {
    for (const match of read(file).matchAll(/<file(?:\s[^>]*)?>([^<]+)<\/file>/g)) {
        const input = match[1];
        assert.ok(candidates.has(input), `${file}: missing source-package input ${input}`);
        resources.add(input);
    }
}

const inventory = read('docs/release/资源清单.md');
const records = [...inventory.matchAll(/^\| `([^`]+)` \| (\d+) \| (?:是 \| )?`([0-9a-f]{64})` \|$/gm)];
const recorded = new Set(records.map(record => record[1]));
for (const [, file, bytes, sha256] of records) {
    assert.ok(candidates.has(file), `Inventory input missing from source package: ${file}`);
    const data = fs.readFileSync(path.join(root, file));
    assert.equal(data.length, Number(bytes), `Inventory size mismatch: ${file}`);
    assert.equal(crypto.createHash('sha256').update(data).digest('hex'), sha256,
        `Inventory hash mismatch: ${file}`);
}
assert.deepEqual(new Set([...recorded].filter(file => file.startsWith('assets/'))), resources,
    'Resource inventory must exactly match the QRC inputs');
const kits = new Set([...candidates].filter(file => file.startsWith('kits/')));
assert.deepEqual(new Set([...recorded].filter(file => file.startsWith('kits/'))), kits,
    'Kit inventory must exactly match the published kit sources');
assert.equal([...resources].filter(file => file.startsWith('assets/minecraft/gui/')).length, 8);

const privatePaths = [
    'assets/minecraft/items/active.json',
    'assets/minecraft/items/cache/client.jar',
    'assets/minecraft/items/import-settings.json',
    'assets/minecraft/gui/container/6.png',
    'assets/minecraft/gui/container/private/note.txt',
    'assets/minecraft/gui/item_lore/extra.png',
    'kits/11', 'kits/private/local.xcshopT', 'kits/templates/private.xcshopT',
    'kits/blueprints/private/main.xcshoper', 'kits/blueprints/alpha-r0/private.json',
    'kits/materials/private/tick.xcontent', 'kits/materials/alpha-r0-26.3/private.json',
    'settings.json', 'update-state.ini', 'kits-download-state.ini', 'item-mappings.json',
    'projects/local/xcshop.json', 'backgrounds/custom.png', 'builder/xcshop-builder.exe',
    'projects/local/.xcshop-relay.json', '重要文件/private.md', '项目构思/private.md',
    'assets/gui/typeBar/UI.psd', '.local/check.log', '.tmp/check.log',
    'build/appxcshop.exe', 'build-release/CMakeCache.txt',
    'cmake-build-debug/CMakeCache.txt', 'out/private/settings.json',
    'tests/__pycache__/test.pyc', 'tools/__pycache__/pack_kits.pyc'
];
const ignored = cp.spawnSync('git', ['check-ignore', '--no-index', '-z', '--stdin'], {
    cwd: root, input: privatePaths.join('\0') + '\0', encoding: 'utf8'
});
assert.ok(ignored.status === 0 || ignored.status === 1, ignored.stderr);
assert.deepEqual(new Set(ignored.stdout.split('\0').filter(Boolean)), new Set(privatePaths),
    'Local data and generated files must remain ignored');

let links = 0;
for (const file of [...candidates].filter(file => file.endsWith('.md'))) {
    const source = read(file);
    assert.ok(!source.includes('\uFFFD'), `Invalid text encoding: ${file}`);
    const prose = source.replace(/^```[^\n]*\n[\s\S]*?^```[^\n]*(?:\n|$)/gm, '');
    for (const match of prose.matchAll(/\[[^\]]+\]\(([^\s)]+)\)/g)) {
        if (/^(https?:|mailto:|#)/.test(match[1])) continue;
        const target = decodeURIComponent(match[1].split('#')[0]);
        if (!target) continue;
        assert.ok(fs.existsSync(path.resolve(root, path.dirname(file), target)),
            `Broken local documentation link: ${file} -> ${target}`);
        ++links;
    }
}
console.log(`Publish inputs verified: ${qrcFiles.length} QRCs, ${resources.size} resources, `
    + `${kits.size} kit files, ${records.length} hashes, ${privatePaths.length} ignore probes, `
    + `${links} local documentation links.`);
