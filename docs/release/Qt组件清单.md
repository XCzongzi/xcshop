# Qt 组件核查记录

记录日期：2026-10-30。依据当前 CMake、QML 导入、现有 EXE 和本机 Qt 社区版 6.11.2 MinGW x64 套件的 SPDX 清单整理，不是尚未制作的 Release 包最终清单。

现有 EXE 动态导入 Qt6Core、Qt6Gui、Qt6Network、Qt6Qml、Qt6Quick、Qt6QuickControls2、Qt6Test。QtTest 来自当前测试构建；正式构建关闭测试。Concurrent 在 CMake 中显式使用；QML 插件与传递依赖以部署结果为准。

## SPDX 组件条目

OR 表示可选许可，不能理解为同时选择全部许可。本项目对适用模块采用 LGPLv3 路线；QtEntryPoint、第三方代码及运行库分别处理。NOASSERTION 不代表无版权或无限制。

| SPDX 所属仓库 | 组件 | 声明许可 |
| --- | --- | --- |
| `qtbase` | `Core` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtbase` | `Concurrent` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtbase` | `Network` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtbase` | `Gui` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtbase` | `Test` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtbase` | `QWindowsIntegrationPlugin` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `Qml` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `QmlModels` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `QmlWorkerScript` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `Quick` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `QuickLayouts` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `QuickEffects` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `QuickTemplates2` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `qtquickcontrols2implplugin` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `qtquickcontrols2basicstyleimplplugin` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `qtquickcontrols2basicstyleplugin` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `QuickControls2` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `LabsFolderListModel` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtdeclarative` | `QuickDialogs2` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qt5compat` | `qtgraphicaleffectsprivate` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qt5compat` | `qtgraphicaleffectsplugin` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtsvg` | `Svg` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtsvg` | `QSvgIconPlugin` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtsvg` | `QSvgPlugin` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |
| `qtshadertools` | `ShaderTools` | `LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` |

## 正式包需要补齐的记录

- Qt 精确版本、套件、编译器、架构，以及 Qt 配置、修改和补丁。
- windeployqt 实际输出、DLL 和平台/QML/图像/TLS 插件及其校验值。
- 实际第三方依赖的版权和许可；当前候选文本见[许可索引](../../licenses/qt-6.11.2/README.md)。
- 发布下载处实际提供的 Qt 对应源码、构建材料和校验值；仅保留官网链接不足以完成源码安排。
- Qt 或编译器变化时重新核查；闭源构建器的 MSVC 运行依赖另行登记，不能套用编辑器 MinGW 清单。
