const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const formatting = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../js/DisplayFormatting.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), formatting);

for (const text of ['first\nsecond', '\n', String.raw`\n`, 'path\\file', 'one\ttwo', 'one\r\ntwo']) {
    assert.equal(formatting.source(text)[0].text, text);
    assert.equal(formatting.source(JSON.stringify({text}))[0].text, text);
}
const plain = 'first\nsecond';
assert.equal(formatting.source(plain)[0].text, 'first\nsecond');
assert.ok(formatting.html({extra: formatting.source(plain)}).includes('first<br>second'));
assert.equal(JSON.parse(JSON.stringify({separator: plain})).separator, 'first\nsecond');
const mixed = formatting.source(JSON.stringify({text: '', extra: [
    {text: '红', color: 'red', bold: true}, {text: '白'}, {text: '蓝', color: 'blue'}
]})).filter(part => part.text.length);
assert.equal(mixed[1].color, 'white');
assert.equal(mixed[1].bold, false);
assert.equal(mixed[2].color, 'blue');
const array = formatting.source('[{"text":"A","bold":true},{"text":"B","italic":true},{"text":"C","bold":false}]');
assert.equal(array[2].bold, false);
assert.equal(array[2].italic, false);
assert.equal(formatting.style({bold: false}, {bold: true}).bold, false);
console.log('Display formatting tests passed: rich text, literal escapes, newlines and sibling styles.');
