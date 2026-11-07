// Requires a real builder with @namespace support; pass its path as argv[2].
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const builder = path.resolve(process.argv[2] || path.join(root, 'builder/xcshop-builder-0.1.2.exe'));
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'xcshop-namespace-'));
const project = path.join(temporary, 'project');
const schema = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(root, 'js/WorkspaceSchema.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), schema);
const fresh = value => JSON.parse(JSON.stringify(value));
const write = (name, value) => fs.writeFileSync(path.join(project, name), JSON.stringify(value));
const filter = {scoreboard: '', target: '', score: ''};
const sale = {element: 'Item/stone.xcseItem', filter, macros: []};
const ui = {containerType: 'generic_9x3', customName: '', openCommand: 'function external:on_open',
    placeholderItem: {enabled: true, element: 'Item/placeholder.xcseItem'}, nestedGroups: [],
    slots: [{index: 0, items: [sale]}]};
const manifest = {name: 'namespace-test', version: '26.3', dataVersion: 0,
    generatePath: path.join(temporary, 'generated'), templateId: '89755dae-f798-440d-b3a9-342ee8a9070f',
    shops: [{registrationName: 'test', element: 'UI/shop.xcseUI', containerType: 'barrel'}]};
const walk = directory => fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(file) : [file];
});

try {
    for (const type of ['UI', 'Item', 'Cost', 'Display'])
        fs.mkdirSync(path.join(project, type), {recursive: true});
    ui.nestedGroups = [{id: 'layout', name: '', enabled: true, element: '', filter, slots: [1],
        layoutInput: {id: 'input', enabled: true, defaultValue: '0',
            result: {scoreboard: 'input_result', target: '@s'},
            connections: [{element: 'UI/match.xcseUI', value: '1'}]}}];
    write('UI/shop.xcseUI', ui);
    write('UI/match.xcseUI', {...ui, openCommand: '', nestedGroups: [],
        placeholderItem: {enabled: false, element: ''}, slots: [{index: 1, items: [sale]}]});
    write('Cost/score.xcseCost', {display: 'Coins', itemSyntaxError: false,
        type: {kind: 'scoreboard', value: 'coins', filter: false}});
    const product = {...fresh(schema.item()), item: 'stone 2'};
    product.operations = [
        {kind: 'take_item', filter: {kind: 'none'}},
        {kind: 'take_item', filter: {kind: 'slot', slot: '0'}},
        {kind: 'drop_item', quantity: 'single'},
        {kind: 'drop_item', quantity: 'all'}
    ].map((mode, index) => ({...fresh(schema.operation()), returnOnSuccess: index % 2 === 0,
        cost: [{element: 'Cost/score.xcseCost', amount: '1'}],
        trigger: {mode, execute: index === 1 ? {kind: 'function', value: 'external:action'}
            : {kind: 'grant_item'}}}));
    write('Item/stone.xcseItem', product);
    write('Item/placeholder.xcseItem', {...fresh(schema.item()), item: 'white_wool'});

    for (const namespace of ['xcshop', 'custom_shop', 'other.namespace-42', 'minecraft']) {
        const generatePath = path.join(manifest.generatePath, namespace);
        write('xcshop.json', {...manifest, namespace, generatePath});
        const result = spawnSync(builder, ['--project', project, '--kits', path.join(root, 'kits')],
            {encoding: 'utf8', maxBuffer: 8 * 1024 * 1024});
        assert.ifError(result.error);
        const line = result.stdout.split(/\r?\n/).find(line => line.startsWith('XCSHOP_BUILD_RESULT '));
        assert.ok(line, result.stdout + result.stderr);
        const record = JSON.parse(line.slice('XCSHOP_BUILD_RESULT '.length));
        assert.equal(result.status, 0, JSON.stringify(record));
        assert.equal(record.buildSucceeded, true, JSON.stringify(record));
        assert.equal(record.outputWritten, true);
        assert.equal(record.warningCount, 0, JSON.stringify(record));

        const output = path.join(generatePath, manifest.name);
        const read = relative => fs.readFileSync(path.join(output, relative), 'utf8');
        const runtime = `data/${namespace}/function/`;
        assert.deepEqual(fs.readdirSync(path.join(output, 'data')).sort(),
            [...new Set([namespace, 'minecraft'])].sort());
        for (const tag of ['load', 'tick'])
            assert.deepEqual(JSON.parse(read(`data/minecraft/tags/function/${tag}.json`)).values,
                [`${namespace}:${tag}`]);
        const advancement = JSON.parse(read(`data/${namespace}/advancement/opened/test.json`));
        assert.equal(advancement.rewards.function, `${namespace}:opened/test`);
        assert.ok(read(`${runtime}opened/test.mcfunction`).includes(`only ${namespace}:opened/test`));
        assert.ok(read(`${runtime}opened/test.mcfunction`).includes('function external:on_open'));
        assert.ok(read(`${runtime}shop/test/0/0/trigger/1.mcfunction`).includes('function external:action'));
        assert.ok(read(`${runtime}shop/test/0/0/trigger/0.mcfunction`)
            .includes(`return run function ${namespace}:shop/test/0/0/failure`));
        assert.ok(fs.existsSync(path.join(output, runtime, 'input/test/input/0.mcfunction')));
        assert.ok(read(`${runtime}shop/test/placeholder.mcfunction`).includes('minecraft:custom_data'));
        assert.ok(read(`${runtime}load.mcfunction`).includes('__xcshop__'));

        for (const file of walk(output).filter(file => file.endsWith('.mcfunction'))) {
            const text = fs.readFileSync(file, 'utf8');
            assert.ok(!text.includes('{{'), `Unexpanded macro in ${file}`);
            for (const [, ns, name] of text.matchAll(/\bfunction ([a-z0-9_.-]+):([a-z0-9_./-]+)/g)) {
                if (ns === 'external') continue;
                assert.equal(ns, namespace, `Wrong namespace in ${file}`);
                assert.ok(fs.existsSync(path.join(output, runtime, `${name}.mcfunction`)),
                    `Missing function ${ns}:${name} referenced by ${file}`);
            }
        }
    }
    console.log('Alpha r0 namespaces: 4 real builds passed');
} finally {
    assert.equal(path.dirname(temporary), path.resolve(os.tmpdir()));
    assert.ok(path.basename(temporary).startsWith('xcshop-namespace-'));
    fs.rmSync(temporary, {recursive: true, force: true});
}
