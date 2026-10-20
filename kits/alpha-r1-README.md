# Alpha r1

面向 Minecraft Java **26.3**，数据包格式 **121.0**。模板 ID：

```text
1dc7404f-209f-4eea-becd-291406d52787
```

按你的 `xcshop-datapack` 测试包拆分为蓝图和材料；补齐预检查、扣费、发货、成功/失败反馈。原测试包不修改。

## 文件与使用

- `templates/alpha-r1.xcshopT`：身份、兼容版本、介绍与生成前限制检查。
- `blueprints/alpha-r1/*.xcshoper`：遍历 IR、选择流程和组织输出。
- `materials/alpha-r1-26.3/*`：26.3 指令片段，全部文件平铺，没有二级目录。

将这三个目录中的新增文件放进编辑器的 `kits` 对应目录。项目 `xcshop.json` 使用上述 `templateId`、`"version":"26.3"` 和 `"dataVersion":0`；`generatePath` 仍为数据包的父目录。运行：

```text
xcshop-builder.exe --project "项目目录" --kits "套件目录"
```

仓库的 `tools/InstallAlphaR1.ps1` 可安装到编辑器源码和运行时两份 `kits`：它只添加本套件的新文件，遇到同名而内容不同的文件会停止，不覆盖既有模板或项目。

生成包复制到存档 `datapacks` 后执行 `/reload`。假设注册名为 `myshop`：

```mcfunction
# 在指定空位置创建商店；不要对已有容器使用，模板会拒绝覆盖非空气方块。
execute positioned 0 64 0 run function xcshop_alpha:_summon/myshop
# 以玩家身份在距商店 8 格内执行布局输入器（id 为 inp）。
function xcshop_alpha:input/myshop/inp
```

也会在处理交易前自动匹配当前商店的布局输入器；匹配采用连接顺序中的第一项，全部不匹配时写入 `defaultValue`。纯展示物品不覆盖输入器已绘制的槽位。拿取交易后，投入的真实物品会掉落归还到购买者脚下，输入布局随之清空；这与测试包的“归还投入物、重设商品”流程一致。输入器应在物品投入后主动调用，或通过项目自定义命令调用；它不会每刻扫描所有未打开的商店。

## 运行结构

运行命名空间固定为 `xcshop_alpha`（不是项目默认命名空间），使用 `_xca` 计分板、`xca.*` 实体标签以及 `custom_data.xca`。它们与参考包的 `xcshop` 系统隔离；同一存档只加载一份 Alpha r1 生成包，不要让商品自身占用保留的 `xca` 数据。

```text
data/xcshop_alpha/
├─ advancement/opened/<商店>.json
└─ function/
   ├─ load.mcfunction、tick.mcfunction、detection.mcfunction、locate.mcfunction
   ├─ _summon/<商店>.mcfunction
   ├─ opened/<商店>.mcfunction
   ├─ input/<商店>/<布局id>/...
   └─ shop/<商店>/
      ├─ set.mcfunction、sell.mcfunction、return.mcfunction、cleanup.mcfunction
      └─ <槽位>/<商品序号>/
         ├─ set.mcfunction、sell.mcfunction、check.mcfunction、pay.mcfunction
         ├─ success.mcfunction、fail.mcfunction
         ├─ condition/<代价序号>.mcfunction
         └─ trigger/<触发序号>/run.mcfunction
```

标记实体和方块保存持久化实例 ID。展示商品携带同一 ID，拿取和掷出均按实例定位；玩家须距标记实体 8 格内。无效或移出范围的展示物品只清理，不扣费。`/reload` 保留商店 ID 和用户余额，不重新置零。破坏商店方块后，其标记实体需要管理员清理。

同一槽位按 IR 顺序选择第一个符合筛选条件的商品（与触发规则不是同一概念）。刷新前先保护真实投入物，不将其覆盖成占位物品。商品自带的其它 `custom_data` 保留，只添加 `xca` 字段；额外价格文本只加到展示品的 lore，真正发放的是原始 `item`。展示文本中的 LF、CRLF、CR 换行会拆成独立 lore 条目，保留颜色、样式和空行，不把控制字符塞在同一条 lore 内。

仓库内另附可直接构建的项目 `tests/fixtures/alpha-r1`（与测试包同样使用注册名 `myshop`）。它生成到仓库的 `x64/alpha-r1-output/alpha-r1-demo`，不写入你的存档。加载生成包后，可用 `/scoreboard players set @s money 100`、`/experience add @s 10 levels` 和 `/give @s diamond 64` 准备代价。`choices=0` 显示石头、`choices=1` 显示平滑石头；开启容器会补上缺失的 `choices=0`，但不会覆盖已有选择。输入器的钻石放在 13，三个经验瓶放在 21、22、23，匹配值为 1；不放钻石、只放三个经验瓶时为 2，其余布局为 0。

## 交易约定

一次拿取或掷出事件表示**一次交易**。先用该事件的数量和槽位快照匹配所有规则，全部代价统一检查并扣除一次，再按数组顺序执行所有匹配动作；成功提示也只执行一次。例如同时配置“取得物品 → 发放商品”和“取得物品 → 执行指令”，两条都会执行，不重复扣费。没有匹配规则时不扣费，清理展示品并恢复展示。价格和发货数量不按拿取/掷出数量自动倍增；每个匹配的 `grant_item` 都发放一次原 `item`（包含其显式数量），所以配置两个相同的发货动作会发两次。

- 拿取：`none` 接受任意正数量；`all` 要求等于商品 `count`；`less_than_all` 为 `1..count-1`；`custom` 为指定数量；`slot` 检查玩家背包指定槽位，检测先于清理展示品。
- 掷出：沿用参考包，`single` 为 1 个，`all` 为 2 个及以上；使用掉落物的 origin 找购买者，而不是最近的任意玩家。
- 先执行所有 execute 条件，再检查全部可用资源；任一失败直接调用失败反馈，不执行任何扣费或动作。
- 检查全部通过后，才扣除经验等级、物品、玩家自身的计分板分数，然后执行全部匹配的 `grant_item`、`command` 或 `function` 动作，最后反馈一次成功。失败时不执行任何匹配动作、不扣费，仅反馈一次失败。
- `type.filter=true` 只检查，不扣除；`execute_condition` 始终只检查。物品代价的查询和扣除均排除展示品，避免拿另一件商品抵扣费用。
- 提示文字支持普通文字或 JSON 组件；音效使用 `playsound`。用户引用的计分板仅尝试创建，不重置已有分数。
- `openCommand` 在开启 UI 时以玩家身份执行；`customName` 写入容器的名称组件。

## r1 明确限制

生成前拒绝：不支持的容器、负数或超出 32 位范围的价格、同商品多项实际物品扣费、重复经验等级扣费、同一计分板重复扣费、超范围触发槽位/数量、超范围布局结果、商品与布局输入槽位重叠，以及普通嵌套组的整组筛选（没有绘制槽位的组不受此限制）。相关筛选条件须改为每个商品自己的筛选。保留仅筛选条件的多个代价不受实际扣费数量限制。

支持桶、单箱、陷阱单箱、发射器、投掷器、漏斗；暂不支持双箱、末影箱、潜影盒、酿造台、熔炉或实体容器。单箱不要与相邻箱合并。支持玩家背包槽位 0–35，数量要求 1–99，实际可堆叠上限还受原物品组件限制。不是防外挂系统，拥有命令/NBT 修改权限的玩家不在信任边界内。

当前 Shop IR 的普通商品只汇总一层普通嵌套；模板因此拒绝多层普通嵌套，以及布局匹配引用 UI 再含普通嵌套商品的配置，不静默丢掉商品。

`command` 与 `function` 保持构建器原有约定，不做用户命令语法限制。自定义命令、条件函数可能有副作用，用户须保证其有效性；如果用户动作自身失败，r1 不回滚已扣费用。这不是跨任意命令的事务系统。多人命令串行执行，但共享容器仍为共享商品展示，不能提供每人独立界面。

## 验证

`tests/AlphaR1Tests.h` 覆盖模板完整生成、代价预检查顺序、仅筛选、展示品排除、触发参数、布局、转义与不支持配置。另可用 `tests/VerifyMinecraftFunctions.ps1 -Datapack <生成包路径>`，借助本机原版 26.3 jar 编译所有函数（包含实例化原生函数宏），不启动服务器、不接受 EULA、不打开或修改存档。

模板定稿后的身份和内容应保持不变；后续行为修改作为新的 revision 创建新 UUID。

版本格式依据：[Minecraft 26.3 官方技术变更](https://www.minecraft.net/en-us/article/minecraft-java-edition-26-3)，并核对本机 26.3 jar 的 `version.json`（`data_major=121`、`data_minor=0`）。
