const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function load(name) {
    const context = vm.createContext({});
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../js/syntax', name), 'utf8'), context);
    return context;
}

const parser = load('ItemSyntaxParser.js');
const highlighter = load('ItemSyntaxHighlighter.js');
const modes = {1: load('mode-1.js'), 2: load('mode-2.js')};
const palette = Object.fromEntries(['plain', 'itemId', 'key', 'string', 'number',
    'quantity', 'punctuation', 'boolean', 'invalid'].map(key => [key, key]));
palette.brackets = ['bracket0', 'bracket1', 'bracket2'];

function check(source, mode, invalid) {
    assert.equal(highlighter.isInvalid(source, mode, palette, modes, parser), invalid,
        `mode ${mode}: ${source}`);
    const rendered = highlighter.highlight(source, mode, palette, modes, parser);
    const escaped = rendered.replace(/<\/?font\b[^>]*>/g, '');
    assert.equal(escaped, parser.escapeHtml(source), 'Highlighting must preserve the original input');
    const ranges = highlighter.ranges(source, mode, palette, modes, parser);
    let position = 0;
    const formatted = ranges.map(range => {
        assert.equal(range.start, position, 'Native colours must address the original UTF-16 positions');
        position += range.length;
        return parser.colorText(source.slice(range.start, position), range.color);
    }).join('');
    assert.equal(position, source.length, 'Native ranges must cover the original text');
    assert.equal(formatted, rendered, 'Native colours must agree with the syntax parser');
}

for (const mode of [1, 2]) {
    for (const source of ['minecraft:stone', 'minecraft:stone 64', '{{物品}}',
        '{{命名空间}}:{{物品}} {{数量}}', 'minecraft:{{material}}_block',
        'minecraft:stone {{数量}}', 'minecraft:stone 1{{数量}}'])
        check(source, mode, false);
    for (const source of ['{{}}', '{{item}', 'minecraft:stone {{count}',
        'minecraft:stone {{count}} garbage', 'Minecraft:{{item}}',
        '\\{{item}}', 'minecraft:stone -{{count}}', '{{item}}[broken='])
        check(source, mode, true);
}

for (const source of ['minecraft:stone{Count:{{数量}}} {{总数}}',
    'minecraft:stone{display:{Name:"中文🙂\t<>&",Lore:["首行\\n次行"]}}',
    '{{物品}}{display:{Name:\'{{名称}}\'},{{键}}:[{{值}},2]}',
    'minecraft:stone{display:{Name:\'{{含"引号的宏}}\'}}'])
    check(source, 1, false);
for (const source of ['{{item}}{Count:{{count}},}', '{{item}}{Count:}',
    '{{item}}[minecraft:damage={{damage}}]'])
    check(source, 1, true);

for (const source of ['minecraft:stone[minecraft:damage={{损伤}}] {{数量}}',
    'minecraft:stone[minecraft:custom_name="中文🙂\t<>&"]',
    '{{item}}[{{component}}={{value}},minecraft:custom_data={key:[{{value}},2]}]',
    'minecraft:stone[minecraft:custom_name=\'{{名称}}\']'])
    check(source, 2, false);
for (const source of ['{{item}}[minecraft:damage=]',
    '{{item}}[minecraft:damage={{damage}},]', '{{item}}{Count:{{count}}'])
    check(source, 2, true);

console.log('Item syntax tests passed: macros, both syntax modes, invalid syntax and text preservation.');
