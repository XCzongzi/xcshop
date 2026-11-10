// Exercise the version boundaries with the separately distributed real builder.
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const builder = path.resolve(process.argv[2] || path.join(root, 'builder/xcshop-builder-1.0.0.exe'));
const templateId = '1fe54658-3cc3-4480-b943-f68d412fa421';
const versions = ['1.21.5', '1.21.6', '1.21.7', '1.21.8', '1.21.9', '1.21.10',
    '1.21.11', '26.1', '26.1.1', '26.1.2', '26.2'];
const mappings = JSON.parse(fs.readFileSync(path.join(root, 'minecraft-data-pack-versions.json'))).versions;
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'xcshop-alpha-r1-'));
const project = path.join(temporary, 'project');
const schema = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(root, 'js/WorkspaceSchema.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), schema);
const fresh = value => JSON.parse(JSON.stringify(value));
const write = (name, value) => fs.writeFileSync(path.join(project, name), JSON.stringify(value));
const walk = directory => fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(file) : [file];
});
let builds = 0;
function build(version, overrides = {}) {
    const manifest = {name: 'compatibility', namespace: 'r1.shop-test', version,
        dataVersion: 0, dataPackVersion: mappings[version] || {major: 122, minor: 0},
        generatePath: path.join(temporary, 'generated', version), templateId,
        shops: [{registrationName: 'test', element: 'UI/shop.xcseUI', containerType: 'barrel'}],
        ...overrides};
    write('xcshop.json', manifest);
    const result = spawnSync(builder, ['--project', project, '--kits', path.join(root, 'kits')],
        {encoding: 'utf8', maxBuffer: 8 * 1024 * 1024});
    assert.ifError(result.error);
    const line = result.stdout.split(/\r?\n/).find(value => value.startsWith('XCSHOP_BUILD_RESULT '));
    assert.ok(line, result.stdout + result.stderr);
    ++builds;
    return {record: JSON.parse(line.slice('XCSHOP_BUILD_RESULT '.length)), status: result.status,
        output: path.join(manifest.generatePath, manifest.name), namespace: manifest.namespace};
}
function succeeded(result) {
    assert.equal(result.status, 0, JSON.stringify(result.record));
    assert.equal(result.record.buildSucceeded, true, JSON.stringify(result.record));
    assert.equal(result.record.outputWritten, true);
    assert.equal(result.record.errorCount, 0);
    assert.equal(result.record.warnings.length, 0, JSON.stringify(result.record));
}

try {
    const template = fs.readFileSync(path.join(root, 'kits/templates/alpha-r1.xcshopT'), 'utf8')
        .replace(/\r\n/g, '\n').split('\n');
    assert.equal(template[0], templateId);
    assert.equal(template[1], '0');
    assert.deepEqual(JSON.parse('[' + template[2] + ']'), versions,
        'Declare every supported release explicitly, without future-version expansion');
    for (const type of ['UI', 'Item', 'Cost', 'Display'])
        fs.mkdirSync(path.join(project, type), {recursive: true});
    const filter = {scoreboard: '', target: '', score: ''};
    const sale = {element: 'Item/stone.xcseItem', filter, macros: []};
    const ui = {containerType: 'generic_9x3', customName: '{"text":"测试商店","color":"gold"}',
        openCommand: 'function external:on_open',
        placeholderItem: {enabled: true, element: 'Item/placeholder.xcseItem'},
        nestedGroups: [{id: 'layout', name: '', enabled: true, element: '', filter, slots: [1],
            layoutInput: {id: 'input', enabled: true, defaultValue: '0',
                result: {scoreboard: 'input_result', target: '@s'},
                connections: [{element: 'UI/match.xcseUI', value: '1'}]}}],
        slots: [{index: 0, items: [sale]}]};
    write('UI/shop.xcseUI', ui);
    write('UI/match.xcseUI', {...ui, customName: '', openCommand: '', nestedGroups: [],
        placeholderItem: {enabled: false, element: ''}, slots: [{index: 1, items: [sale]}]});
    write('Cost/score.xcseCost', {display: '金币', itemSyntaxError: false,
        type: {kind: 'scoreboard', value: 'coins', filter: false}});
    const display = fresh(schema.display());
    display.operation.enabled = true;
    display.hint.success = {text: '{"text":"成功","color":"green"}', sound: 'entity.player.levelup'};
    display.hint.fail = {text: '失败', sound: 'entity.villager.no'};
    write('Display/format.xcseDisplay', display);
    const product = {...fresh(schema.item()), item: 'stone[custom_name={text:"商品"}] 2',
        display: {mode: 'additional', element: 'Display/format.xcseDisplay'}};
    product.operations = [
        {kind: 'take_item', filter: {kind: 'none'}},
        {kind: 'take_item', filter: {kind: 'slot', slot: '0'}},
        {kind: 'drop_item', quantity: 'single'},
        {kind: 'drop_item', quantity: 'all'}
    ].map((mode, index) => ({...fresh(schema.operation()), title: '购买', returnOnSuccess: index % 2 === 0,
        cost: [{element: 'Cost/score.xcseCost', amount: '1'}],
        trigger: {mode, execute: index === 1 ? {kind: 'function', value: 'external:action'}
            : {kind: 'grant_item'}}}));
    write('Item/stone.xcseItem', product);
    write('Item/placeholder.xcseItem', {...fresh(schema.item()), item: 'white_wool'});

    const baseline = build('26.3', {templateId: '89755dae-f798-440d-b3a9-342ee8a9070f'});
    succeeded(baseline);
    const runtimePrefix = `data/${baseline.namespace}/function/`;
    const baselineFunctions = new Map(walk(path.join(baseline.output, runtimePrefix)).map(file => [
        path.relative(path.join(baseline.output, runtimePrefix), file), fs.readFileSync(file, 'utf8')
    ]));
    for (const version of versions) {
        const result = build(version);
        succeeded(result);
        const read = relative => fs.readFileSync(path.join(result.output, relative), 'utf8');
        const pack = JSON.parse(read('pack.mcmeta')).pack;
        assert.equal(pack.description.text, 'xcshop Alpha r1');
        if (['1.21.5', '1.21.6', '1.21.7', '1.21.8'].includes(version)) {
            assert.equal(pack.pack_format, mappings[version].major);
            assert.equal(pack.min_format, undefined);
            assert.equal(pack.max_format, undefined);
        } else {
            const {major, minor} = mappings[version];
            assert.deepEqual(pack.min_format, [major, minor]);
            assert.deepEqual(pack.max_format, [major, minor]);
            assert.equal(pack.pack_format, undefined);
        }
        const advancement = JSON.parse(read(`data/${result.namespace}/advancement/opened/test.json`));
        assert.equal(advancement.criteria.xcshop.trigger, 'minecraft:any_block_use');
        assert.deepEqual(advancement.criteria.xcshop.conditions, {location: [{
            condition: 'minecraft:location_check', predicate: {block: {
                blocks: 'minecraft:barrel', predicates: {'minecraft:custom_data': {xcshop: {shop: 'test'}}}
            }}
        }]});
        assert.equal(advancement.rewards.function, `${result.namespace}:opened/test`);
        const actualFunctions = walk(path.join(result.output, runtimePrefix));
        assert.equal(actualFunctions.length, baselineFunctions.size);
        for (const file of actualFunctions) {
            const relative = path.relative(path.join(result.output, runtimePrefix), file);
            const content = fs.readFileSync(file, 'utf8');
            assert.equal(content, baselineFunctions.get(relative), `${version}: runtime changed: ${relative}`);
            assert.ok(!content.includes('{{'), `${version}: unexpanded material macro`);
            for (const [, namespace, name] of content.matchAll(/\bfunction ([a-z0-9_.-]+):([a-z0-9_./-]+)/g)) {
                if (namespace === 'external') continue;
                assert.equal(namespace, result.namespace);
                assert.ok(fs.existsSync(path.join(result.output, runtimePrefix, `${name}.mcfunction`)), name);
            }
        }
        for (const tag of ['load', 'tick'])
            assert.deepEqual(JSON.parse(read(`data/minecraft/tags/function/${tag}.json`)).values,
                [`${result.namespace}:${tag}`]);
        assert.ok(read(runtimePrefix + 'shop/test/0/1/set.mcfunction').includes('minecraft:lore" append value'));
        assert.ok(read(runtimePrefix + '_summon/test.mcfunction').includes('测试商店'));
        assert.ok(fs.existsSync(path.join(result.output, runtimePrefix, 'input/test/input/0.mcfunction')));
    }
    for (const version of ['1.21.4', '26.3', '26.4']) {
        const result = build(version);
        assert.notEqual(result.status, 0, JSON.stringify(result.record));
        assert.equal(result.record.buildSucceeded, false);
        assert.equal(result.record.outputWritten, false);
        assert.ok(result.record.errors.some(error => error.property === '$.version'), JSON.stringify(result.record));
    }
    for (const namespace of ['xcshop', 'minecraft']) succeeded(build('1.21.5', {
        namespace, generatePath: path.join(temporary, 'namespaces', namespace)
    }));
    const unsupported = build('26.2', {generatePath: path.join(temporary, 'unsupported'),
        shops: [{registrationName: 'test', element: 'UI/shop.xcseUI', containerType: 'ender_chest'}]});
    assert.equal(unsupported.record.buildSucceeded, false);
    assert.ok(unsupported.record.errors.some(error => error.reason.startsWith('Alpha r1 不支持')),
        JSON.stringify(unsupported.record));
    console.log(`Alpha r1 compatibility: ${builds} real builds checked; ${versions.length} supported releases.`);
} finally {
    assert.equal(path.dirname(temporary), path.resolve(os.tmpdir()));
    assert.ok(path.basename(temporary).startsWith('xcshop-alpha-r1-'));
    fs.rmSync(temporary, {recursive: true, force: true});
}
