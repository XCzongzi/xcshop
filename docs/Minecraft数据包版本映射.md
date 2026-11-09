# Minecraft 数据包版本映射

编辑器根目录的 [`minecraft-data-pack-versions.json`](../minecraft-data-pack-versions.json) 是手动维护的 Minecraft Java 正式版到数据包格式版本的映射。发布时放在 `appxcshop.exe` 同级；路径基于程序目录，不依赖启动时的工作目录。CMake 构建和安装会复制此文件。

截至 2026-11-09，包含 Mojang 官方版本清单中从 `1.13` 到 `26.3` 的全部 51 个正式版（包括补丁版），不含快照、预发布版、候选版或整合包名称。数据包版本与游戏版本、Minecraft 世界 `DataVersion`、XCShop 项目 `dataVersion` 独立编号。

## 文件格式和维护

以下仅展示部分条目，实际文件保留全部正式版：

```json
{
  "schemaVersion": 1,
  "versions": {
    "1.13": { "major": 4, "minor": 0 },
    "1.21.11": { "major": 94, "minor": 1 },
    "26.1.2": { "major": 101, "minor": 1 },
    "26.3": { "major": 121, "minor": 0 }
  }
}
```

`schemaVersion` 表示映射文件的结构版本。`major` 必须为正整数，`minor` 必须为非负整数，均不超过 2147483647。旧整数格式统一使用 `minor: 0`；不能用浮点数 `94.1` 代替两个整数。

游戏版本精确命中时使用对应值。只有目标正式版比表中最新游戏版本更新时才回退，使用最新条目的完整 `major/minor`；例如当前 `27.1` 回退为 `26.3` 对应的 `121.0`。最新游戏版本按数字分段比较确定，不依赖 JSON 顺序或最大的 `major`。历史缺项、快照、无效版本不回退；文件缺失或无效时阻止新建/修改游戏版本，并显示原因。

新增正式版时，在 `versions` 添加准确的官方版本 ID 和主次版本即可，不必重新编译。发布包修改程序旁的 JSON；开发时修改仓库根目录的文件。更新映射本身不会重写已有项目。

创建项目时，模板末尾的 `...` 使用本地映射表中的较新正式版扩展列表，打开创建页不会请求网络。程序每次启动时在后台检查更新：先读取 Mojang 官方版本清单中的最新正式版，与本地表中按游戏版本排序的最新条目比较；有差异或本地文件缺失、无效时，下载 [站点映射表](https://xczongzi.net/projects/xcshop/downloads/minecraft-data-pack-versions.json)。下载结果须通过结构和版本映射校验，且最新条目与 Mojang 最新正式版一致，才原子替换本地文件并刷新创建页。

成功确认无需更新或成功保存更新后，在程序目录的 `minecraft-version-state.ini` 记录成功检查时间，24 小时内启动不重复请求。官方清单请求失败、下载失败或超时、下载内容无效或站点映射尚未更新、写入失败等异常均不触发冷却，保留原有文件，下次启动重试。

初始数据已逐项核对 [Mojang 官方版本清单](https://piston-meta.mojang.com/mc/game/version_manifest_v2.json)所指的客户端 JAR：读取根目录 `version.json` 的 `pack_version`（旧整数、`data` 或 `data_major/data_minor`）；`1.13`、`1.13.1`、`1.13.2` 没有该文件，核对 JAR 根目录 `pack.mcmeta` 的旧共享格式值 `4`。例如 [1.21.11 官方公告](https://www.minecraft.net/en-us/article/minecraft-java-edition-1-21-11)公布 `94.1`，[26.3 官方公告](https://www.minecraft.net/en-us/article/minecraft-java-edition-26-3)公布 `121.0`。编辑器和构建器在构建时均不联网查询映射。

## 保存项目和蓝图接口

新建项目查表，并在 `xcshop.json` 同时写入：

```json
{
  "version": "26.3",
  "dataPackVersion": { "major": 121, "minor": 0 }
}
```

项目设置每次改变游戏版本时重新查表，并将两个版本一同原子保存；未改游戏版本时保留已有数据包版本。旧项目缺少 `dataPackVersion` 时，在项目设置中保存一次即可补齐。取消或保存失败不会修改原配置。手工修改 `xcshop.json` 的游戏版本时，也需同步 `dataPackVersion`。

构建器直接使用项目保存值，不查映射、不根据游戏版本重算。只读全局 `@dataPackVersion.major` 和 `@dataPackVersion.minor` 在蓝图、材料、模板检查脚本、嵌套迭代和子蓝图中均可读取。完整对象用 `json(@dataPackVersion)`，不能直接插入文本或赋值。

Alpha r0 材料示例：

```text
pack.mcmeta
{
  "pack": {
    "description": "XCShop",
    "min_format": [{{@dataPackVersion.major}}, {{@dataPackVersion.minor}}],
    "max_format": [{{@dataPackVersion.major}}, {{@dataPackVersion.minor}}]
  }
}
```

旧版套件可按其规范用 `"pack_format": {{@dataPackVersion.major}}`。新旧字段规则见 [Mojang 格式说明](https://www.minecraft.net/en-us/article/minecraft-snapshot-25w31a)。构建器只提供值，元数据布局由套件决定；版本号正确不代表指令、组件和目录结构自动兼容，模板支持版本检查仍保留。

项目提供的值不合法时，构建器定位到 `$.dataPackVersion` 或子字段并终止；缺少该字段时，读取新接口会报补填提示，不使用新接口的旧套件仍可构建。需使用提供此接口的构建器；旧构建器不能展开新宏。
