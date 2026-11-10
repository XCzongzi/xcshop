# Alpha r1

面向 Minecraft Java **1.21.5–26.2** 的标准方块容器商店套件，项目数据版本为 `dataVersion = 0`，需要 xcshop-builder 0.1.3 或更新版本。

模板 ID：`1fe54658-3cc3-4480-b943-f68d412fa421`。

明确支持的正式版本：`1.21.5`、`1.21.6`、`1.21.7`、`1.21.8`、`1.21.9`、`1.21.10`、`1.21.11`、`26.1`、`26.1.1`、`26.1.2`、`26.2`。不声明快照或未来版本支持；26.3 使用 Alpha r0。

## 文件与使用

- 模板：`templates/alpha-r1.xcshopT`
- 蓝图：`blueprints/alpha-r1/`
- 材料：`materials/alpha-r1-1.21.5-26.2/`，全部为根目录文件

在编辑器中选择 Alpha r1 和目标游戏版本后构建。已有项目可在项目设置中切换模板、选择受支持的游戏版本并保存，生成到单独目录验证后再用于游戏。不会自动切换已有项目或默认模板。

游戏内通过 `/function <项目命名空间>:_summon/<商店注册名>` 创建商店，通过 `/function <项目命名空间>:input/<商店注册名>/<输入器名>` 调用布局输入器，必要时通过 `/function <项目命名空间>:clear_marker` 清理已加载的失效标记。

## 版本适配

打开商店使用 `minecraft:any_block_use` 的旧版 `location` 条件数组，内含 `condition: "minecraft:location_check"`；通过方块谓词的 `predicates.minecraft:custom_data` 匹配容器中的商店注册名。该写法适用于本模板声明的版本，不使用 26.3 新增的 `minecraft:match_block`。

`pack.mcmeta` 使用项目保存的 `@dataPackVersion`：1.21.5–1.21.8 输出 `pack_format`；1.21.9–26.2 输出 `min_format`、`max_format`，主次版本均保留。已有项目缺失 `dataPackVersion` 时，在项目设置中保存一次补齐。映射见 [Minecraft 数据包版本映射](../docs/Minecraft数据包版本映射.md)。

1.21.5 起的文本组件存储、单数资源目录、物品组件、`player.cursor`、`execute if items`、`@n`、函数返回值及 `on origin` 沿用 Alpha r0 的实现。商品物品、组件、自定义指令、外部函数和音效仍须适用于所选游戏版本；模板不进行用户内容的跨版本转换。

## 功能与限制

交易路由、代价检查及扣除、嵌套筛选、占位商品、lore、提示、成功后返回、布局输入器和 marker 清理沿用 [Alpha r0](alpha-r0-README.md) 的规则。r1 使用独立 UUID、蓝图和材料，不覆盖 r0。

不支持末影箱、大型箱子和大型陷阱箱。彩色潜影盒仍受独立构建器的容器校验限制。商店在打开及交互后刷新，计分板变化不会立即自动刷新栏位。仅声明普通方块容器支持。

## 验证

运行 `node tests/AlphaR1CompatibilityTests.cjs [构建器路径]`，使用真实构建器检查所有 11 个目标版本、支持范围外版本的拒绝、两种元数据格式、旧版交互条件、命名空间、文本及交易函数与 r0 的一致性。

构建输出检查不替代游戏内验证。使用独立测试世界检查打开容器、拿取及 Shift 拿取、单个及整组掷出、代价扣除、提示、布局输入和 marker 清理，再用于正式存档。

格式依据：[1.21.5 技术说明](https://www.minecraft.net/en-us/article/minecraft-java-edition-1-21-5)、[1.21.9 元数据格式](https://www.minecraft.net/en-us/article/minecraft-java-edition-1-21-9)、[26.3 进度与谓词变更](https://www.minecraft.net/en-us/article/minecraft-java-edition-26-3)。
