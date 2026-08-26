cmake_minimum_required(VERSION 3.16)

project(xcshop VERSION 0.1 LANGUAGES CXX)


set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QT_QML_GENERATE_QMLLS_INI ON)   #图形效果




find_package(Qt6 REQUIRED COMPONENTS Quick Network Concurrent)

qt_standard_project_setup(REQUIRES 6.5)

include_directories(header)    # 头文件目录

#QT策略
qt_policy(
    SET QTP0004 NEW #为了解决模块化问题（我也不知道具体干什么的
)


set(CMAKE_AUTORCC ON)   #解决资源文件问题，一定要放在qt_add_executable前边
qt_add_executable(appxcshop
    src/main.cpp
    src/XCFile.cpp
    src/MinecraftAssetImporter.cpp
    src/ElementIO.cpp
)


set_source_files_properties(appxcshop
    qml/Colors.qml
    qml/Constants.qml
    qml/Global.qml
    qml/SignalBus.qml
    qml/Temp/Console.qml    # 控制台，临时
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

set_source_files_properties(
    js/syntax/ItemSyntaxHighlighter.js
    js/syntax/ItemSyntaxParser.js
    js/syntax/mode-1.js
    js/syntax/mode-2.js
    PROPERTIES QT_QML_SKIP_QMLDIR_ENTRY TRUE)



qt_add_qml_module(appxcshop
    URI xcshop
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Colors.qml
        qml/Constants.qml
        qml/Global.qml
        qml/SignalBus.qml


        qml/components/TitleBar.qml
        qml/components/Border.qml
        qml/components/TypeBar.qml
        qml/components/ElementExplorer.qml
        qml/components/ElementRelayBar.qml
        qml/components/FileControls.qml

        qml/components/base/reusable/ButtonStateOverlay.qml
        qml/components/base/reusable/LightEffect.qml
        qml/components/base/reusable/XCShadow.qml

        qml/components/base/XCWindow.qml
        qml/components/base/ImageButton.qml
        qml/components/base/TextButton.qml
        qml/components/base/XCText.qml
        qml/components/base/XCTextField.qml
        qml/components/base/XCCheckBox.qml
        qml/components/base/BooleanSwitch.qml
        qml/components/base/TextStyleEditor.qml
        qml/components/base/XCTextArea.qml
        qml/components/base/JsonTextEditorButton.qml
        qml/components/base/XCKeyInput.qml
        qml/components/base/XCFileDialog.qml
        qml/components/base/XCFolderDialog.qml
        qml/components/popup/PopupLoader.qml
        qml/components/popup/PopupNotice.qml
        qml/components/popup/PopupMappingHistory.qml
        qml/components/popup/PopupJsonTextEditor.qml
        qml/components/base/ContentBar.qml
        qml/components/base/RadioGroup.qml
        qml/components/base/ComboBox.qml
        qml/components/base/BranchBar.qml
        qml/components/base/VariableTextField.qml
        qml/components/base/VariableTextArea.qml
        qml/components/base/ScrollBar.qml
        qml/components/base/MultiPropertyEdit.qml
        qml/components/base/ElementSelection.qml
        qml/components/base/ElementSelectionCompact.qml
        qml/components/base/LargeIconButton.qml
        qml/components/base/IconButton.qml

        qml/components/settings/SettingsPageHeader.qml
        qml/components/settings/SettingsCard.qml
        qml/components/settings/SettingsNavButton.qml
        
        qml/components/relayBar/ElementCard.qml
        qml/components/relayBar/RelayTabCard.qml
        qml/components/relayBar/RelaySelectionMask.qml

        qml/components/FileSystem/XCFileTreeBar.qml
        qml/components/FileSystem/FileButton.qml
        qml/components/FileSystem/FileCtrlBar.qml


        qml/pages/Controls/_Item/Item_triggerBar.qml
        qml/pages/Controls/_Item/Item_costBar.qml
        qml/pages/Controls/_Display/MinecraftTooltipPreview.qml
        qml/pages/Controls/_UI/ContainerBox.qml
        qml/pages/Controls/_UI/ItemSlot.qml
        
        qml/pages/base/BasePage.qml
        qml/pages/base/BaseIOPage.qml
        qml/pages/base/WindowSurface.qml
        qml/pages/PageWithEmpty.qml
        qml/pages/PageOnStart.qml
        qml/pages/PageOnCreating.qml
        qml/pages/PageOnOpening.qml
        qml/pages/PageOnTotal.qml
        qml/pages/PageOnUI.qml
        qml/pages/PageOnItem.qml
        qml/pages/PageOnCost.qml
        qml/pages/PageOnDisplay.qml
        qml/pages/PageOnSettings.qml
        qml/pages/settings/SettingsInterface.qml
        qml/pages/settings/SettingsTemplates.qml
        qml/pages/settings/SettingsItems.qml
        qml/pages/PageOnAbout.qml


        assets/js/request.js
        js/syntax/ItemSyntaxHighlighter.js
        js/syntax/ItemSyntaxParser.js
        js/syntax/mode-1.js
        js/syntax/mode-2.js


        qml/Temp/Console.qml

    RESOURCES
        gui.qrc
        js.qrc
        js/ElementRelayState.js
    SOURCES
        src/XCFile.cpp
        src/MinecraftAssetImporter.cpp
        src/main.cpp
        src/ElementIO.cpp

        header/XCFile.h
        header/MinecraftAssetImporter.h
        header/ElementIO.h
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appxcshop PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appxcshop
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE

    # AUTOMOC TRUE
    # AUTORCC TRUE
    # AUTOUIC TRUE
)

target_link_libraries(appxcshop
    PRIVATE Qt6::Quick Qt6::Network Qt6::Concurrent
)

include(GNUInstallDirs)
install(TARGETS appxcshop
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
