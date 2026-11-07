// Requires the separately distributed real builder; pass its path as argv[2].
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const builder = path.resolve(process.argv[2] || path.join(root, 'builder/xcshop-builder-0.1.0.exe'));
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'xcshop-quantity-'));
const project = path.join(temporary, 'project');
const write = (name, data) => fs.writeFileSync(path.join(project, name), JSON.stringify(data));
try {
    for (const type of ['UI', 'Item', 'Cost', 'Display'])
        fs.mkdirSync(path.join(project, type), {recursive: true});
    write('xcshop.json', {name: 'quantity-test', namespace: 'quantity_test', version: '26.3', dataVersion: 0,
        generatePath: path.join(temporary, 'generated'), templateId: '89755dae-f798-440d-b3a9-342ee8a9070f',
        shops: [{registrationName: 'test', element: 'UI/shop.xcseUI', containerType: 'barrel'}]});
    write('UI/shop.xcseUI', {containerType: 'generic_9x3', customName: '', openCommand: '',
        placeholderItem: {enabled: false, element: ''}, nestedGroups: [],
        slots: [{index: 0, items: [{element: 'Item/stone.xcseItem',
            filter: {scoreboard: '', target: '', score: ''}, macros: []}]}]});
    const cases = [
        ['stone', 'quantity', 'all', true],
        ['stone 1', 'quantity', 'less_than_all', true],
        ['stone 1', 'quantity', 'custom', true],
        ['stone 2', 'quantity', 'all', false],
        ['stone 2', 'quantity', 'less_than_all', false],
        ['stone', 'none', '', false],
        ['stone', 'slot', '', false],
        ['stone', 'drop_item', '', false]
    ];
    for (const [item, kind, mode, expected] of cases) {
        const filter = kind === 'quantity' ? {kind, mode, ...(mode === 'custom' ? {amount: '1'} : {})}
            : kind === 'slot' ? {kind, slot: '0'} : {kind};
        const triggerMode = kind === 'drop_item' ? {kind, quantity: 'single'}
            : {kind: 'take_item', filter};
        write('Item/stone.xcseItem', {item, itemSyntaxError: false, display: {mode: 'original', element: ''},
            operations: [{title: '', showInDisplay: true, successHint: false, failHint: false,
                returnOnSuccess: false, uniqueTrigger: false, cost: [],
                trigger: {mode: triggerMode, execute: {kind: 'grant_item'}}}]});
        const result = spawnSync(builder, ['--project', project, '--kits', path.join(root, 'kits')]);
        assert.ifError(result.error);
        let output;
        try { output = new TextDecoder('utf-8', {fatal: true}).decode(result.stdout); }
        catch { output = new TextDecoder('gb18030').decode(result.stdout); }
        const line = output.split(/\r?\n/).find(value => value.startsWith('XCSHOP_BUILD_RESULT '));
        assert.ok(line, output);
        const record = JSON.parse(line.slice('XCSHOP_BUILD_RESULT '.length));
        assert.equal(result.status, 0, output);
        assert.equal(record.buildSucceeded, true, JSON.stringify(record));
        assert.equal(record.warningCount, Number(expected), `${item}/${kind}/${mode}: ${JSON.stringify(record)}`);
        if (expected) {
            assert.ok(record.warnings[0].reason.length);
            assert.ok(record.warnings[0].solution.length);
            assert.equal(record.warnings[0].terminatesBuild, false);
        }
    }
    console.log(`Alpha r0 quantity warnings: ${cases.length} cases passed`);
} finally {
    assert.equal(path.dirname(temporary), path.resolve(os.tmpdir()));
    assert.ok(path.basename(temporary).startsWith('xcshop-quantity-'));
    fs.rmSync(temporary, {recursive: true, force: true});
}
