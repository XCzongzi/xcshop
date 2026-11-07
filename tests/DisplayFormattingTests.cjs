const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const formatting = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../js/DisplayFormatting.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), formatting);

assert.equal(formatting.textFromEditor(String.raw`first\nsecond`), 'first\nsecond');
assert.equal(formatting.textFromEditor(String.raw`\n\n`), '\n\n');
assert.equal(formatting.textFromEditor('\\'), '\\');
assert.equal(formatting.textFromEditor(String.raw`\q`), String.raw`\q`);
assert.equal(formatting.textFromEditor(String.raw`\\n`), String.raw`\n`);
for (const text of ['first\nsecond', '\n', String.raw`\n`, 'path\\file', 'one\ttwo', 'one\r\ntwo']) {
    assert.equal(formatting.textFromEditor(formatting.textForEditor(text)), text);
}
for (const text of [String.raw`{"text":"first\nsecond"}`, String.raw`{"text":"first\\nsecond"}`,
    String.raw`["one\n",{"text":"two\\n"}]`, String.raw`"one\ntwo"`]) {
    assert.equal(formatting.textFromEditor(text), text);
    assert.equal(formatting.textForEditor(text), text);
}
const plain = formatting.textFromEditor(String.raw`first\nsecond`);
assert.equal(formatting.source(plain)[0].text, 'first\nsecond');
assert.ok(formatting.html({extra: formatting.source(plain)}).includes('first<br>second'));
assert.equal(JSON.parse(JSON.stringify({separator: plain})).separator, 'first\nsecond');
console.log('Display formatting tests passed: plain escapes, JSON escapes, preview and persistence.');
