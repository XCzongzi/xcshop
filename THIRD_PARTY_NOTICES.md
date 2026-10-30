# 第三方内容与来源

本页记录 xcshop 编辑器的第三方依赖、素材及分发时应保留的说明。它不是对未取得权利的内容的授权，也不是对尚未制作的发布包的合规认证。记录日期：2026-10-30。

编辑器原创代码的 GPLv3 及独立构建器额外许可见 [LICENSING.md](LICENSING.md)。第三方许可原文优先于本页摘要。

## Qt 社区版

Qt 是 The Qt Company Ltd. 及其他贡献者的作品。当前开发套件为 **Qt 6.11.2 / MinGW x64**，编辑器通过 DLL 动态使用 Qt；项目源码声明最低 Qt 6.8。

| 使用范围 | 对应仓库或模块 | 许可处理 |
| --- | --- | --- |
| 基础、图形、联网和并发 | qtbase：Core、Gui、Network、Concurrent | 对适用的 Qt 实现选择 LGPLv3；内部第三方代码另按各自许可 |
| QML、Quick、Controls、Templates、Layouts、Dialogs、Effects、FolderListModel、Controls.impl | qtdeclarative | 对适用实现选择 LGPLv3；包括 Basic 样式插件等运行时依赖 |
| Qt5Compat.GraphicalEffects | qt5compat 的图形效果模块 | 对适用实现选择 LGPLv3 |
| SVG 和图像插件、着色器相关支持 | qtsvg、qtimageformats、qtshadertools 等 | 是否进入正式包及具体许可，以部署文件、构建配置和 SPDX 清单为准 |
| 测试 | Qt Test | 当前测试构建使用；正式编辑器关闭 XCSHOP_BUILD_TESTS |
| Windows 入口辅助代码 | QtEntryPoint | BSD 3-Clause，包含相应版权声明 |

当前本机 SPDX 核查记录见 [Qt 组件清单](docs/release/Qt组件清单.md)。本次整理的基础许可及第三方版权原文在 [licenses/](licenses/)，相关 Qt 文档原文块的索引在 [licenses/qt-6.11.2/README.md](licenses/qt-6.11.2/README.md)。后者含候选组件及可选插件，不能只凭复制了这个集合就宣布最终包的许可已全部核实。

分发所附 Qt DLL、插件及 QML 文件时，需要满足选用许可证的源码、版权和替换库等要求。发布者应实际提供对应 Qt 源码及必要构建材料的合规获取方式，包括自己的修改与补丁；不能只提供编辑器源码或只链接 Qt 官方下载页。具体下载位置必须在该次发布记录中填写并验证，本仓库不声称此项已经完成。

参考：[Qt 许可义务](https://www.qt.io/faq/qt-open-source-licensing)、[Qt 6.11 LGPL 正文](https://doc.qt.io/qt-6.11/lgpl.html)、[Qt Windows 部署](https://doc.qt.io/qt-6.11/windows-deployment.html)。

## 编译器与运行库

编辑器现有 MinGW 开发构建会涉及 `libgcc_s_seh-1.dll`、`libstdc++-6.dll`、`libwinpthread-1.dll` 等文件。编译器的开源许可证不能被理解为所有编译结果都必须使用相同许可；相关运行库的许可及例外仍需随实际分发内容核对。

本次从匹配的 MinGW 13.1.0 安装中保留了 GCC Runtime Library Exception、winpthreads、MinGW-w64 runtime 和 LGPL 参考文本；GPLv3 正文在根目录 LICENSE。保留许可文本不能替代必要的对应源码安排，应结合具体库及例外判断。

独立构建器由作者说明为使用 C++ 标准库、MSVC 编译。Microsoft STL 公开源码采用 Apache-2.0 with LLVM Exception，但这不能替代所用 Visual Studio/MSVC 二进制运行库的再分发条款。构建器最终选择静态或动态运行库、附带哪些文件，需在它自己的发布材料中记录。本次未检查构建器源码，也未为其编写一个未经作者选择的二进制使用/再分发许可。

参考：[GCC Runtime Library Exception](https://www.gnu.org/licenses/gcc-exception-3.1.html)、[Microsoft STL 许可](https://github.com/microsoft/STL/blob/main/LICENSE.txt)、[MSVC 运行库再分发](https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files)。

## Minecraft 素材及渲染结果

Minecraft 相关模型、纹理、名称和品牌的相关权利归 Mojang、Microsoft 及相应权利人所有。编辑器 GUI 资源和由原版模型、纹理渲染的物品图标不被重新声明为本项目 GPL 原创素材。渲染器的原创代码与其输出画面中的既有权利应分别处理。

当前 `gui.qrc`、`container.qrc` 引用了两张提示框和六张容器图片。作者于 2026-10-30 确认，Minecraft 风格 GUI 图片是从游戏 JAR 内的资源文件获取的；具体游戏版本和提取路径尚未逐项提供。背景图片由作者自行在 Minecraft 游戏中截图，截图与直接提取的 GUI 资源分别记录，不将其来源混为一谈，也不将截图中的既有游戏素材统一重新许可为 GPL。

计划随包预装的物品图标，需要记录明确的游戏版本、来源、渲染器版本及实际资源范围。现有文件和哈希见[资源清单](docs/release/资源清单.md)，作者提供的来源说明见[素材与套件来源](docs/release/素材与套件来源.md)。本次保留原有使用方式，没有伪造官方许可，也没有以其他工具使用相似图片作为授权证明。

本工具非 Minecraft 官方出品，与 Mojang 或 Microsoft 无关联，亦未经其批准。相关说明不能替代适用的许可或法律依据。

参考：[Minecraft EULA](https://www.minecraft.net/en-us/eula)、[Minecraft Usage Guidelines](https://www.minecraft.net/en-us/usage-guidelines)。

## 社媒与赞助标识

详细文件来源见 [assets/gui/brands/SOURCES.md](assets/gui/brands/SOURCES.md)。

| 文件 | 来源和用途 | 权利说明 |
| --- | --- | --- |
| github-black.svg、github-white.svg | GitHub 官方品牌素材，链接开发者 GitHub 主页 | GitHub/Invertocat 相关商标和作品权利保留；遵守品牌规范，不表示合作或背书 |
| bilibili.svg | Simple Icons 中的 Bilibili 图标，显示为蓝色，链接开发者主页 | Simple Icons 项目 CC0 不自动清除具体品牌图标及商标权利；其当前数据条目仅列出官网来源，未列单独许可，不能据此认定无限制 |
| afdian.png | 爱发电官网静态 Logo，链接作者赞助页面 | 未在本仓库记录可通用适用的独立许可，不将“官网下载”写成“已获无限制授权” |

参考：[GitHub 品牌规范](https://brand.github.com/foundations/logo)、[Simple Icons 声明](https://github.com/simple-icons/simple-icons/blob/develop/DISCLAIMER.md)、[Simple Icons 图标数据](https://github.com/simple-icons/simple-icons/blob/develop/data/simple-icons.json)。现有 CC0 全文保留在 [SIMPLE-ICONS-LICENSE.md](assets/gui/brands/SIMPLE-ICONS-LICENSE.md)，它不取代品牌相关规则。

## 其他图片、字体与套件

- 背景图片是作者自行在游戏中截取的画面；Minecraft 使用指南对游戏截图有相应规定，实际使用仍需满足适用条件。具体游戏版本、资源包/光影及其他第三方内容如有使用，可随实际文件补充记录。
- 除社媒品牌标识、Minecraft 原版资源和背景截图以外的其他界面图标，作者确认由其原创。原创图标的授权应与原版游戏素材、品牌标识分开说明；本次仅补充来源，不擅自为其新增未选择的素材许可。
- 程序引用系统可用的字体，测试入口也会从 Windows 字体目录加载字体；这些路径引用不等于本项目已经取得字体文件的再分发权。正式包若加入字体文件，需要单独记录许可。
- `kits/` 的套件由作者原创与 AI 辅助制作，材料包/数据包逻辑由作者原创；当前仍未被 Git 跟踪。套件许可和生成结果中所含材料正文的使用权尚需单独明确，不自动套用编辑器代码许可证。
- 用户导入的图片、资源包和自定义物品不应混入维护者的正式发布包；也不能由本项目替用户授予第三方内容权利。

## 更新方式

每次换 Qt/编译器版本、增加插件、替换素材或引入外部代码时，同步更新本页、资源/依赖清单、随附许可和该次发布记录。已存在的第三方版权及许可声明应保留。
