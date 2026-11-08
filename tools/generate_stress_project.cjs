#!/usr/bin/env node
// Deterministic, editable dataVersion 0 fixtures for the real xcshop builder.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const presets = {
    smoke: {shops: 4, candidates: 2, variants: 16},
    pressure: {shops: 24, candidates: 3, variants: 128},
    inferno: {shops: 96, candidates: 6, variants: 512}
};
const emptyFilter = () => ({scoreboard: '', target: '', score: ''});
const filter = (scoreboard, score = '0..', target = '@s') => ({scoreboard, target, score});
const component = (text, extra = {}) => JSON.stringify({text, ...extra});
const pad = number => String(number).padStart(3, '0');
const clone = value => JSON.parse(JSON.stringify(value));

function generate(destination, profile = 'pressure', overrides = {}) {
    if (!Object.hasOwn(presets, profile)) throw new Error(`Unknown profile: ${profile}`);
    const options = {...presets[profile], ...overrides};
    for (const [key, value] of Object.entries(options)) {
        if (!Number.isSafeInteger(value) || value < 1 || value > 512)
            throw new Error(`${key} must be an integer between 1 and 512`);
    }
    destination = path.resolve(destination);
    // Exclusive creation also protects hand-edited fixtures and previous output.
    if (fs.existsSync(destination)) throw new Error(`Destination already exists: ${destination}`);
    const schema = vm.createContext({});
    vm.runInContext(fs.readFileSync(path.join(root, 'js/WorkspaceSchema.js'), 'utf8')
        .replace(/^\.pragma library\s*/, ''), schema);
    const files = new Map();
    const write = (name, data) => files.set(name, data);
    const operation = (title, mode, execute, costs = [], flags = {}) => ({
        ...clone(schema.operation(title)), cost: costs, trigger: {mode, execute}, ...flags
    });
    const take = filter => ({kind: 'take_item', filter});
    const none = () => take({kind: 'none'});
    const quantity = (mode, amount) => take({kind: 'quantity', mode,
        ...(amount === undefined ? {} : {amount})});
    const drop = quantity => ({kind: 'drop_item', quantity});
    const command = value => ({kind: 'command', value});
    const grant = {kind: 'grant_item'};
    const cost = (name, amount = '{{price}}') => ({element: `Cost/${name}.xcseCost`, amount});
    const ui = (slots = [], extra = {}) => ({containerType: 'generic_9x3', customName: '',
        openCommand: '', placeholderItem: {enabled: false, element: ''},
        slots, nestedGroups: [], ...extra});
    const layoutOff = () => ({id: '', enabled: false, defaultValue: '0',
        result: {scoreboard: '', target: ''}, connections: []});
    const group = (id, element, slots, selection = emptyFilter(), extra = {}) => ({
        id, name: id, enabled: true, element, slots, filter: selection,
        layoutInput: layoutOff(), ...extra
    });

    const costs = [
        ['coins', '金币', 'scoreboard', 'xs_coins', false],
        ['coins_gate', '金币门槛', 'scoreboard', 'xs_coins', true],
        ['level', '经验等级', 'experience_level', '', false],
        ['level_gate', '等级门槛', 'experience_level', '', true],
        ['material', '绿宝石', 'item_count', 'minecraft:emerald', false],
        ['material_gate', '持有绿宝石', 'item_count', 'minecraft:emerald', true],
        ['permission', '权限条件', 'execute_condition', 'if entity @s[tag=xs_member]', true],
        ['position', '站在实心方块上', 'execute_condition', 'unless block ~ ~-1 ~ minecraft:air', false]
    ];
    for (const [name, display, kind, value, onlyFilter] of costs)
        write(`Cost/${name}.xcseCost`, {display, itemSyntaxError: false,
            type: {kind, value, filter: onlyFilter}});
    // Literal alternatives make the no-macro branch visible in the editor as well.
    write('Cost/free.xcseCost', {display: '零元测试', itemSyntaxError: false,
        type: {kind: 'scoreboard', value: 'xs_coins', filter: false}});

    const colors = ['gold', '#39c5bb', 'light_purple', '#ABC', 'red', 'aqua', 'white', 'green'];
    for (let index = 0; index < 16; ++index) {
        const display = clone(schema.display());
        display.frame = {head: component(`试炼 ${index} · 星城商店\n`, {color: colors[index % 8], bold: true}),
            end: '\n结束 / end 🙂', separator: index % 2 ? '\n' : component(' | ', {color: 'dark_gray'})};
        display.member = {...display.member, order: index % 2 ? 'value_then_cost' : 'cost_then_value',
            head: component('['), middle: ' × ', end: ']'};
        display.operation = {...display.operation, enabled: index % 4 !== 0,
            order: index % 2 ? 'cost_then_title' : 'title_then_cost',
            head: component('▶ ', {color: 'yellow'}), middle: '：', end: '', separator: ' + '};
        for (const [offset, style] of [display.member.cost, display.member.value, display.operation.title].entries()) {
            style.color = colors[(index + offset) % colors.length];
            for (const [bit, key] of ['bold', 'italic', 'underlined', 'strikethrough', 'obfuscated'].entries())
                style[key] = Boolean((index + offset) & (1 << (bit % 4)));
        }
        display.hint = {
            success: {text: component('购买成功！', {color: 'green'}),
                sound: index % 2 ? 'minecraft:entity.experience_orb.pickup' : ''},
            fail: {text: index % 3 ? component('条件不足 / insufficient', {color: 'red'}) : '',
                sound: index % 2 ? 'minecraft:block.note_block.bass' : ''}
        };
        write(`Display/style_${pad(index)}.xcseDisplay`, display);
    }

    write('Item/继承/base.xcseItem', {...clone(schema.item()), item: 'minecraft:stone 16', operations: [
        operation('基类：继承宏 {{label}}', take({kind: 'slot', slot: '35'}),
            command('scoreboard players add @s xs_actions {{bonus}}'), [cost('level_gate', '1')]),
        operation('基类：隐藏日志', drop('single'), command('scoreboard players add @s xs_actions 1'), [],
            {showInDisplay: false, successHint: false, failHint: false})
    ]});
    write('Item/继承/middle.xcseItem', {...clone(schema.item()), item: 'minecraft:emerald 16',
        operationsFrom: 'Item/继承/base.xcseItem', operations: [
            operation('中层：多行函数', take({kind: 'slot', slot: '9'}),
                {kind: 'function', value: 'xcshop_stress:tick\n\nxcshop_stress:tick'}, [cost('coins_gate')]),
            operation('中层：空名称', quantity('custom', '2'), grant, [cost('material_gate', '1')])
        ]});
    write('Item/占位/边框.xcseItem', {...clone(schema.item()),
        item: 'minecraft:gray_stained_glass_pane[minecraft:custom_name={text:"压力测试边框",italic:false}]',
        operations: [operation('', none(), command(''), [],
            {showInDisplay: false, successHint: false, failHint: false, returnOnSuccess: true})]});
    write('Item/原生/stone.xcseItem', {...clone(schema.item()), item: 'minecraft:stone 32',
        operations: [operation('', none(), grant, [cost('free', '0')],
            {successHint: false, failHint: false})]});

    const modes = [none(), quantity('all'), quantity('less_than_all'), quantity('custom', '{{take_count}}'),
        take({kind: 'slot', slot: '0'}), take({kind: 'slot', slot: '35'}), drop('single'), drop('all')];
    const operations = modes.map((mode, index) => operation(
        index === 1 ? '' : `动作 ${index} · {{label}}`, mode,
        index % 3 === 0 ? grant : index % 3 === 1
            ? command('scoreboard players add @s xs_actions {{bonus}}\nscoreboard players add @s xs_actions 1')
            : {kind: 'function', value: 'xcshop_stress:tick\nxcshop_stress:tick'},
        index === 0 ? [] : index === 7 ? costs.map(([name]) => cost(name, name.startsWith('level') ? '1' : '{{price}}'))
            : [cost(costs[index - 1][0]), cost('coins', '0')],
        {showInDisplay: index !== 6, successHint: index % 2 === 0, failHint: index % 3 !== 0,
            returnOnSuccess: index === 4}));
    operations.push(
        // Keep an earlier duplicate, then lock later duplicates of exactly the same trigger.
        operation('唯一触发之前保留', quantity('custom', '3'), grant),
        operation('隐藏唯一触发', quantity('custom', '3'), command('scoreboard players add @s xs_actions 3'), [],
            {uniqueTrigger: true, showInDisplay: false}),
        operation('应被唯一触发移除', quantity('custom', '3'), command('say XCSHOP_UNIQUE_SHOULD_BE_REMOVED')),
        operation('不同数量必须保留', quantity('custom', '4'), command('scoreboard players add @s xs_actions 4'))
    );
    for (let index = 0; index < options.variants; ++index) {
        const product = {...clone(schema.item()),
            item: index % 2 ? 'minecraft:{{material}} {{count}}'
                : 'minecraft:{{material}}[minecraft:custom_name={text:"{{label}}",italic:false},minecraft:custom_data={stress:1b,variant:{{variant}}}] {{count}}',
            display: index % 17 === 16 ? {mode: 'original', element: ''}
                : {mode: 'additional', element: `Display/style_${pad(index % 16)}.xcseDisplay`},
            operationsFrom: index % 4 === 3 ? '' : 'Item/继承/middle.xcseItem',
            operations: clone(operations)};
        write(`Item/商品/product_${pad(index)}.xcseItem`, product);
        if (profile === 'smoke') write(`Item/吞吐/product_${pad(index)}.xcseItem`, {
            ...clone(product), display: {mode: 'original', element: ''}});
    }

    const materials = ['stone', 'diamond', 'emerald', 'gold_ingot', 'iron_ingot', 'redstone', 'lapis_lazuli', 'quartz'];
    function sale(shop, slot, candidate, selection = emptyFilter()) {
        const variant = ((shop * 27 + slot) * options.candidates + candidate) % options.variants;
        const values = {material: materials[variant % materials.length], count: String(16 + variant % 4 * 16),
            price: String(1 + (shop + slot + candidate) % 9), take_count: '2', bonus: '1', variant: String(variant),
            label: `星城${pad(shop)}·栏${pad(slot)}·候选${candidate}`};
        const category = profile === 'smoke' && (slot !== 0 || candidate !== 0) ? '吞吐' : '商品';
        return {element: `Item/${category}/product_${pad(variant)}.xcseItem`, filter: selection,
            macros: Object.entries(values).map(([name, value]) => ({name, value}))};
    }
    const registrations = [];
    for (let shop = 0; shop < options.shops; ++shop) {
        const id = pad(shop);
        const leaf = `UI/嵌套/leaf_${id}.xcseUI`;
        const middle = `UI/嵌套/middle_${id}.xcseUI`;
        write(leaf, ui(Array.from({length: 9}, (_, slot) => ({index: slot,
            items: [sale(shop, slot, 0, filter('xs_level', '1..')), sale(shop, slot, 1)]}))));
        write(middle, ui([], {nestedGroups: [group('inner', leaf, [0, 1, 2, 3, 4, 5, 6, 7, 8],
            filter('xs_page', '0..2'))]}));
        const patterns = [];
        for (let pattern = 0; pattern < 3; ++pattern) {
            const name = `UI/输入/pattern_${id}_${pattern}.xcseUI`;
            patterns.push(name);
            write(name, ui([{index: 18, items: [{element: 'Item/原生/stone.xcseItem',
                filter: emptyFilter(), macros: []}, sale(shop, 18, pattern)]},
            {index: 19 + pattern, items: [sale(shop, 19 + pattern, pattern)]}]));
        }
        const slots = Array.from({length: 27}, (_, slot) => ({index: slot,
            items: Array.from({length: options.candidates}, (_, candidate) => sale(shop, slot, candidate,
                candidate ? filter('xs_page', String(candidate - 1)) : emptyFilter()))}));
        write(`UI/商店/city_${id}.xcseUI`, ui(slots, {
            customName: `超绝压力试炼 · 星城 ${id} 🙂`,
            openCommand: 'scoreboard players add @s xs_opened 1\nscoreboard players add @s xs_actions 0',
            placeholderItem: {enabled: shop % 2 === 0, element: shop % 2 === 0 ? 'Item/占位/边框.xcseItem' : ''},
            nestedGroups: [
                group('outer', middle, [0, 1, 2, 3, 4, 5], filter('xs_level', '1..')),
                group('disabled', leaf, [9, 10, 11], emptyFilter(), {enabled: false}),
                group('input', '', [18, 19, 20, 21, 22, 23, 24, 25, 26], emptyFilter(), {
                    layoutInput: {id: `recipe_${id}`, enabled: true, defaultValue: '-1',
                        result: {scoreboard: 'xs_recipe', target: '@s'},
                        connections: patterns.map((element, index) => ({element, value: String(index + 1)}))}
                })
            ]
        }));
        registrations.push({registrationName: `city_${id}`,
            element: `UI/商店/city_${id}.xcseUI`,
            containerType: ['barrel', 'chest', 'trapped_chest', 'shulker_box'][shop % 4]});
    }
    // Editor-only layouts: the Alpha template intentionally cannot register these containers.
    for (const [containerType, length] of [['generic_9x6', 54], ['generic_3x3', 9], ['hopper_5', 5],
        ['brewing_stand_5', 5], ['furnace_3', 3]])
        write(`UI/仅编辑器布局/${containerType}.xcseUI`, ui(Array.from({length}, (_, index) => ({index,
            items: [{element: 'Item/原生/stone.xcseItem', filter: emptyFilter(), macros: []}]})), {containerType}));

    write('xcshop.json', {name: `超绝构建压力测试-${profile}`, namespace: 'xcshop_stress',
        version: '26.3', dataVersion: 0, templateId: '89755dae-f798-440d-b3a9-342ee8a9070f',
        generatePath: './generated', outputFolder: 'xcshop-stress-pack', shops: registrations});
    const summary = {profile, ...options, sourceFiles: files.size,
        elements: Object.fromEntries(['UI', 'Item', 'Cost', 'Display'].map(type => [type,
            [...files.keys()].filter(name => name.startsWith(`${type}/`)).length])),
        directCandidates: options.shops * 27 * options.candidates,
        nestedCandidates: options.shops * 6 * 2,
        layoutConnections: options.shops * 3,
        productOperationsBeforeInheritance: 12,
        maxProductOperationsAfterInheritanceAndUniqueTrigger: 15};
    write('coverage.json', {summary, coverage: {
        project: ['dataVersion 0', 'template UUID', '26.3', 'custom namespace', 'relative generatePath', 'outputFolder'],
        ui: ['all 27 slots', 'ordered candidates', 'score exact/range', 'placeholder on/off', 'customName',
            'multiline openCommand', 'two nested levels', 'intersection of slot masks', 'disabled group',
            'outer/inner/item filters', 'layout input', 'negative default', 'ordered matches', 'empty input slots',
            'multiple input candidates', 'six editor layouts (five unregistered)'],
        item: ['original/additional display', 'plain/component item', 'count macro', 'Chinese macro value',
            'multiline command/function', 'empty command', 'grant item', 'no/zero/multiple costs',
            'take none/all/less_than_all/custom/slot 0/slot 35', 'drop single/all',
            'three-level operationsFrom', 'self-before-parent order', 'optional inheritance',
            'uniqueTrigger exact condition', 'hidden unique operation', 'duplicate before unique retained',
            'showInDisplay/successHint/failHint/returnOnSuccess true/false', 'empty title'],
        cost: ['all four types', 'deduct/filter-only', 'operation cost amount macro', 'zero cost'],
        display: ['operation enabled/disabled', 'both operation/member orders', 'frame/member/operation fragments',
            'plain/JSON text', 'real newline', 'Chinese/emoji', 'named/hex/short hex colors',
            'bold/italic/underlined/strikethrough/obfuscated', 'hint text/sound on/off']
    }, limits: ['Coverage describes fixture inputs; run a real build and inspect output to verify behavior.',
        'Alpha r0 only builds 27-slot barrel/chest/trapped_chest/shulker_box shops.',
        'Macros are used in Item and operation fields; Cost definitions and Display formats use literal values.',
        'Editor preferences, imports, animation, and game runtime need separate UI/game testing.']});
    fs.mkdirSync(destination, {recursive: true});
    for (const [name, data] of files) {
        const file = path.join(destination, name);
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n', 'utf8');
    }
    fs.writeFileSync(path.join(destination, 'README.md'), `# 超绝构建压力测试 · ${profile}\n\n`
        + `在 xcshop 中打开本目录。项目使用 Alpha r0、Minecraft Java 26.3、dataVersion 0。\n\n`
        + `注册商店 ${options.shops} 个，直接候选 ${summary.directCandidates} 个，嵌套候选 ${summary.nestedCandidates} 个，输入连接 ${summary.layoutConnections} 条。\n`
        + `四类元素数量：${JSON.stringify(summary.elements)}。详细覆盖见 coverage.json。\n\n`
        + (profile === 'smoke' ? '基线档只在少量槽位启用额外展示，以验证完整输出。\n\n'
            : '压力档大量启用额外展示，用于复现模板检查/蓝图执行限额；当前构建器可能在写出数据包前终止。\n\n')
        + '产物位于 generated/xcshop-stress-pack。仅编辑器布局目录中的非 27 格 UI 不注册为商店。\n\n'
        + '游戏内：/function xcshop_stress:_summon/city_000（在目标位置创建商店）。\n'
        + '初始化玩家：/scoreboard players set @s xs_coins 10000；xs_level 设为 10；xs_page 设为 0；/tag @s add xs_member。\n'
        + '测试材料扣费时准备绿宝石，经验等级设为 30。筛选、代价和输入结果所用目标由 load 自动创建。\n'
        + '布局输入入口：/function xcshop_stress:input/city_000/recipe_000（玩家需已定位到商店实例）。\n'
        + '自定义命令使用的 xs_actions、xs_opened 需手动创建 dummy 目标；函数操作调用本包 tick，不依赖外部数据包。\n\n'
        + '这是一份构建与编辑压力夹具，尚不代表 Minecraft 游戏内所有行为已经验证。\n', 'utf8');
    return {destination, ...summary};
}

if (require.main === module) {
    try {
        const args = process.argv.slice(2);
        if (args.includes('--help')) {
            console.log('node tools/generate_stress_project.cjs [--profile smoke|pressure|inferno] [--output DIRECTORY] [--shops N] [--candidates N] [--variants N]');
        } else {
            const values = {};
            for (let index = 0; index < args.length; index += 2) {
                const key = args[index];
                if (!['--profile', '--output', '--shops', '--candidates', '--variants'].includes(key)
                    || !args[index + 1] || args[index + 1].startsWith('--')) throw new Error(`Invalid argument: ${key}`);
                values[key.slice(2)] = args[index + 1];
            }
            const profile = values.profile || 'pressure';
            const overrides = Object.fromEntries(['shops', 'candidates', 'variants']
                .filter(key => values[key] !== undefined).map(key => [key, Number(values[key])]));
            console.log(JSON.stringify(generate(values.output || path.join(root, 'projects', `超绝构建压力测试-${profile}`),
                profile, overrides), null, 2));
        }
    } catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = {generate};
