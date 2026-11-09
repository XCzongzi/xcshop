// Requires the separately distributed real builder; pass its path as argv[2].
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const builder = path.resolve(process.argv[2] || path.join(root, 'builder/xcshop-builder-1.0.0.exe'));
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'xcshop-containers-'));
const project = path.join(temporary, 'project');
const write = (name, value) => fs.writeFileSync(path.join(project, name), JSON.stringify(value));
const slotCounts = {generic_9x3: 27, generic_9x6: 54, generic_3x3: 9,
    hopper_5: 5, brewing_stand_5: 5, furnace_3: 3};
const options = [...fs.readFileSync(path.join(root, 'qml/Constants.qml'), 'utf8')
    .matchAll(/"value": "([a-z_]+)", "label": "[^"]+", "layoutId": "([a-z_0-9]+)"/g)]
    .map(([, type, layout]) => ({type, layout}))
    // Builder 0.1.2 rejects coloured shulker IDs before running template checks.
    .filter(({type}) => !type.endsWith('_shulker_box'));
const rejected = new Set(['ender_chest', 'large_chest', 'large_trapped_chest']);

try {
    assert.ok(options.length > 10, 'Exercise block and entity containers across all editor layouts');
    assert.equal(options.filter(({type}) => rejected.has(type)).length, rejected.size);
    for (const type of ['UI', 'Item', 'Cost', 'Display'])
        fs.mkdirSync(path.join(project, type), {recursive: true});
    write('Item/stone.xcseItem', {item: 'stone', itemSyntaxError: false,
        display: {mode: 'original', element: ''}, operations: []});

    for (const {type, layout} of options) {
        const lastSlot = slotCounts[layout] - 1;
        assert.ok(Number.isInteger(lastSlot), `Unknown layout: ${layout}`);
        write('xcshop.json', {name: 'container-test', namespace: 'container_test', version: '26.3',
            dataPackVersion: {major:121,minor:0},
            dataVersion: 0, generatePath: path.join(temporary, type),
            templateId: '89755dae-f798-440d-b3a9-342ee8a9070f',
            shops: [{registrationName: 'test', element: 'UI/shop.xcseUI', containerType: type}]});
        write('UI/shop.xcseUI', {containerType: layout, customName: '', openCommand: '',
            placeholderItem: {enabled: false, element: ''}, nestedGroups: [],
            slots: [{index: lastSlot, items: [{element: 'Item/stone.xcseItem',
                filter: {scoreboard: '', target: '', score: ''}, macros: []}]}]});
        const result = spawnSync(builder, ['--project', project, '--kits', path.join(root, 'kits')],
            {encoding: 'utf8', maxBuffer: 8 * 1024 * 1024});
        assert.ifError(result.error);
        const line = result.stdout.split(/\r?\n/).find(value => value.startsWith('XCSHOP_BUILD_RESULT '));
        assert.ok(line, `${type}: ${result.stdout}${result.stderr}`);
        const record = JSON.parse(line.slice('XCSHOP_BUILD_RESULT '.length));
        const message = `${type}: ${JSON.stringify(record)}`;
        assert.equal(record.buildSucceeded, !rejected.has(type), message);
        assert.equal(record.outputWritten, !rejected.has(type), message);
        if (rejected.has(type)) {
            assert.notEqual(result.status, 0, message);
            assert.ok(record.errors.some(error => error.reason.startsWith('Alpha r0 不支持末影箱或大型箱子。')), message);
            continue;
        }
        assert.equal(result.status, 0, message);
        assert.equal(record.errorCount, 0, message);
        assert.equal(record.warnings.filter(warning => warning.property !== '$.version').length, 0, message);
        const runtime = path.join(temporary, type, 'container-test/data/container_test/function');
        const item = fs.readFileSync(path.join(runtime, `shop/test/${lastSlot}/0/set.mcfunction`), 'utf8');
        assert.ok(item.includes(`container.${lastSlot} with stone`), type);
        const opened = fs.readFileSync(path.join(runtime, 'opened/test.mcfunction'), 'utf8');
        assert.ok(opened.includes('unless data block ~ ~ ~ components.minecraft:custom_data.xcshop.shop run kill @s'), type);
    }
    console.log(`Alpha r0 containers: ${options.length} real builds checked (${rejected.size} rejected)`);
} finally {
    assert.equal(path.dirname(temporary), path.resolve(os.tmpdir()));
    assert.ok(path.basename(temporary).startsWith('xcshop-containers-'));
    fs.rmSync(temporary, {recursive: true, force: true});
}
