#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');

function run(project, builder = path.join(root, 'builder/xcshop-builder-0.1.2.exe'), kits = path.join(root, 'kits')) {
    project = path.resolve(project);
    builder = path.resolve(builder);
    kits = path.resolve(kits);
    const manifest = JSON.parse(fs.readFileSync(path.join(project, 'xcshop.json'), 'utf8'));
    function invoke(check) {
        const args = ['--project', project, '--kits', kits, '--machine', ...(check ? ['--check'] : [])];
        const started = performance.now();
        const process = spawnSync(builder, args, {encoding: 'utf8', timeout: 180000,
            maxBuffer: 32 * 1024 * 1024, windowsHide: true, cwd: project});
        const elapsedMs = Math.round(performance.now() - started);
        fs.writeFileSync(path.join(project, check ? 'check.log' : 'build.log'),
            (process.stdout || '') + (process.stderr || ''), 'utf8');
        if (process.error) throw process.error;
        const lines = process.stdout.split(/\r?\n/).filter(line => line.startsWith('XCSHOP_BUILD_RESULT '));
        assert.equal(lines.length, 1, 'Expected exactly one builder result');
        const result = JSON.parse(lines[0].slice('XCSHOP_BUILD_RESULT '.length));
        assert.equal(result.protocol, 'xcshop-builder/result');
        assert.equal(result.version, 0);
        assert.equal(result.errorCount, result.errors.length);
        assert.equal(result.warningCount, result.warnings.length);
        return {elapsedMs, exitCode: process.status, ...result};
    }
    const report = {builder, kits, check: invoke(true)};
    if (report.check.buildSucceeded) report.build = invoke(false);
    // Do not inspect stale output after a failed build.
    if (report.build?.buildSucceeded && report.build.outputWritten) {
        const output = path.resolve(project, manifest.generatePath, manifest.outputFolder || manifest.name);
        const files = [];
        function walk(directory) {
            for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
                const file = path.join(directory, entry.name);
                if (entry.isDirectory()) walk(file);
                else files.push(file);
            }
        }
        walk(output);
        const inventory = new Set(files.map(file => path.relative(output, file).replaceAll('\\', '/')));
        const failures = [];
        let bytes = 0, functions = 0, lines = 0, references = 0;
        for (const file of files) {
            const text = fs.readFileSync(file, 'utf8');
            bytes += Buffer.byteLength(text);
            if (/\{\{[^{}\r\n]+\}\}/u.test(text)) failures.push(`Unexpanded macro: ${file}`);
            if (text.includes('XCSHOP_UNIQUE_SHOULD_BE_REMOVED')) failures.push(`uniqueTrigger did not remove duplicate: ${file}`);
            if (file.endsWith('.json') || file.endsWith('.mcmeta')) {
                try { JSON.parse(text); } catch { failures.push(`Invalid JSON: ${file}`); }
            }
            if (!file.endsWith('.mcfunction')) continue;
            ++functions;
            lines += text.trimEnd().split(/\r?\n/).length;
            for (const [, namespace, name] of text.matchAll(/\bfunction ([a-z0-9_.-]+):([a-z0-9_./-]+)/g)) {
                ++references;
                if (!inventory.has(`data/${namespace}/function/${name}.mcfunction`))
                    failures.push(`Missing function ${namespace}:${name} in ${file}`);
            }
        }
        for (const tag of ['load', 'tick']) {
            const data = JSON.parse(fs.readFileSync(path.join(output, `data/minecraft/tags/function/${tag}.json`), 'utf8'));
            if (!data.values.includes(`${manifest.namespace}:${tag}`)) failures.push(`Missing ${tag} tag entry`);
        }
        for (const shop of manifest.shops) {
            for (const file of [`_summon/${shop.registrationName}.mcfunction`, `opened/${shop.registrationName}.mcfunction`])
                if (!inventory.has(`data/${manifest.namespace}/function/${file}`)) failures.push(`Missing shop entry ${file}`);
            const source = JSON.parse(fs.readFileSync(path.join(project, shop.element), 'utf8'));
            for (const group of source.nestedGroups.filter(group => group.enabled && group.layoutInput?.enabled))
                if (!inventory.has(`data/${manifest.namespace}/function/input/${shop.registrationName}/${group.layoutInput.id}.mcfunction`))
                    failures.push(`Missing layout input ${shop.registrationName}/${group.layoutInput.id}`);
        }
        report.output = {path: output, files: files.length, functions, lines, bytes, functionReferences: references,
            validationPassed: failures.length === 0, failures};
    }
    report.passed = Boolean(report.check.buildSucceeded && report.build?.buildSucceeded
        && report.output?.validationPassed);
    fs.writeFileSync(path.join(project, 'build-report.json'), JSON.stringify(report, null, 2) + '\n');
    return report;
}

if (require.main === module) {
    try {
        if (!process.argv[2]) throw new Error('Usage: node tools/benchmark_stress_project.cjs PROJECT [BUILDER] [KITS]');
        const report = run(process.argv[2], process.argv[3], process.argv[4]);
        console.log(JSON.stringify(report, null, 2));
        if (!report.passed) process.exitCode = 1;
    } catch (error) { console.error(error.stack); process.exitCode = 1; }
}
module.exports = {run};
