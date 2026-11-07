cmake_minimum_required(VERSION 3.16)

project(xcshop VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QT_QML_GENERATE_QMLLS_INI ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickPrivate QuickControls2 Network Concurrent)

# Prefer system zlib; official Windows Qt kits expose their bundled copy.
find_package(ZLIB QUIET)
if(ZLIB_FOUND)
    set(XCSHOP_ZIP_LIBRARY ZLIB::ZLIB)
else()
    find_package(Qt6 REQUIRED COMPONENTS ZlibPrivate)
    set(XCSHOP_ZIP_LIBRARY Qt6::ZlibPrivate Qt6::Core)
endif()
qt_add_library(xcshop_kit_archive STATIC src/BuildKitArchive.cpp header/BuildKitArchive.h)
target_link_libraries(xcshop_kit_archive PRIVATE Qt6::Network ${XCSHOP_ZIP_LIBRARY})
target_include_directories(xcshop_kit_archive PRIVATE header)

qt_standard_project_setup(REQUIRES 6.8)

include_directories(header)    # 头文件目录

# Generate implicit imports for QML files in subdirectories.
qt_policy(
    SET QTP0004 NEW
)

set(CMAKE_AUTORCC ON)
qt_add_executable(appxcshop
    src/MinecraftGameData.cpp
    src/MinecraftItemRenderer.cpp
    src/BuildKitManager.cpp
    src/BuildManager.cpp
    src/WindowStateController.cpp
    src/UpdateChecker.cpp
    header/UpdateChecker.h
    gui.qrc
    about.qrc
    gui_light.qrc
    container.qrc
)

set_source_files_properties(
    qml/Colors.qml
    qml/Constants.qml
    qml/Global.qml
    qml/SignalBus.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

set_source_files_properties(
    js/syntax/ItemSyntaxHighlighter.js
    js/ThemeCatalog.js
    js/MinecraftTextColors.js
    js/WorkspaceSchema.js
    js/DisplayFormatting.js
    js/syntax/MacroHighlighter.js
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

        qml/components/base/ActionButton.qml
        qml/components/base/XCComboBox.qml
        qml/components/base/ElementSelectionBase.qml
        qml/components/base/ElementConnectionRow.qml
        qml/components/base/XCScrollBar.qml
        qml/components/base/XCScrollView.qml
        qml/components/base/reusable/InputBackground.qml
        qml/components/base/reusable/ResizableEditor.qml
        qml/components/popup/PopupFrame.qml
        qml/components/settings/SettingsSection.qml

        qml/components/TitleBar.qml
        qml/components/WorkspaceEntrance.qml
        qml/components/InitializationThemePicker.qml
        qml/components/Border.qml
        qml/components/TypeBar.qml
        qml/components/ElementExplorer.qml
        qml/components/ElementRelayBar.qml
        qml/components/FileControls.qml

        qml/components/base/reusable/ButtonStateOverlay.qml
        qml/components/base/reusable/ContentSurface.qml
        qml/components/base/reusable/PanelSurface.qml
        qml/components/base/reusable/FrostedSurface.qml
        qml/components/base/reusable/ObjectListModel.qml
        qml/components/base/reusable/AnimatedReveal.qml
        qml/components/base/reusable/PageTransition.qml
        qml/components/base/reusable/AnimatedListRemoval.qml
        qml/components/base/reusable/AnimatedListSwap.qml
        qml/components/base/reusable/AmbientBackground.qml
        qml/components/base/reusable/LightEffect.qml
        qml/components/base/reusable/XCShadow.qml

        qml/components/base/XCWindow.qml
        qml/components/base/ImageButton.qml
        qml/components/base/ThemedIcon.qml
        qml/components/base/TextButton.qml
        qml/components/base/XCText.qml
        qml/components/base/XCToolTip.qml
        qml/components/base/XCTextField.qml
        qml/components/base/XCCheckBox.qml
        qml/components/base/XCSlider.qml
        qml/components/base/BooleanSwitch.qml
        qml/components/base/TextStyleEditor.qml
        qml/components/base/XCTextArea.qml
        qml/components/base/JsonTextEditorButton.qml
        qml/components/base/XCKeyInput.qml
        qml/components/base/XCFileDialog.qml
        qml/components/base/XCFolderDialog.qml
        qml/components/popup/PopupLoader.qml
        qml/components/popup/PopupNotice.qml
        qml/components/popup/PopupTextInput.qml
        qml/components/popup/PopupProjectSettings.qml
        qml/components/popup/PopupShopSettings.qml
        qml/components/popup/PopupJsonTextEditor.qml
        qml/components/popup/PopupOperationInheritance.qml
        qml/components/base/ContentBar.qml
        qml/components/base/RadioGroup.qml
        qml/components/base/VariableTextField.qml
        qml/components/base/VariableTextArea.qml
        qml/components/base/ScrollBar.qml
        qml/components/base/ResizeHandle.qml
        qml/components/base/MultiPropertyEdit.qml
        qml/components/base/ElementSelection.qml
        qml/components/base/ElementSelectionCompact.qml
        qml/components/base/LargeIconButton.qml
        qml/components/base/IconButton.qml
        qml/components/base/ContextMenu.qml

        qml/components/settings/SettingsPageHeader.qml
        qml/components/settings/SettingsCard.qml
        qml/components/settings/BackgroundImageCard.qml
        qml/components/settings/SettingsActionButton.qml
        qml/components/settings/SettingsNavButton.qml
        
        qml/components/relayBar/ElementCard.qml
        qml/components/relayBar/RelayTabCard.qml
        qml/components/relayBar/RelaySelectionMask.qml

        qml/components/FileSystem/XCFileTreeBar.qml
        qml/components/FileSystem/FileButton.qml
        qml/components/FileSystem/FileCtrlBar.qml

        qml/pages/Controls/_Item/Item_triggerBar.qml
        qml/pages/Controls/_Item/Item_operationCard.qml
        qml/pages/Controls/_Item/Item_costBar.qml
        qml/pages/Controls/_Display/MinecraftTooltipPreview.qml
        qml/pages/Controls/_Display/DisplayPairEditor.qml
        qml/pages/Controls/_Display/DisplayTextEditor.qml
        qml/pages/Controls/_Global/ProjectBar.qml
        qml/pages/Controls/_Global/ShopBar.qml
        qml/pages/Controls/_Global/BuildBar.qml
        qml/pages/Controls/_Global/InfoBar.qml
        qml/pages/Controls/_UI/ContainerBox.qml
        qml/pages/Controls/_UI/ContainerUI.qml
        qml/pages/Controls/_UI/ContainerTypeSelection.qml
        qml/pages/Controls/_UI/CurrentSlotProperties.qml
        qml/pages/Controls/_UI/GlobalProperties.qml
        qml/pages/Controls/_UI/Inspector.qml
        qml/pages/Controls/_UI/ItemSlot.qml
        qml/pages/Controls/_UI/LayoutInput.qml
        qml/pages/Controls/_UI/LayoutInputConnection.qml
        qml/pages/Controls/_UI/LayoutManager.qml
        qml/pages/Controls/_UI/MacroParameterEditor.qml
        qml/pages/Controls/_UI/SaleItemEditor.qml
        qml/pages/Controls/_UI/ScoreboardFilter.qml
        
        qml/pages/base/BasePage.qml
        qml/pages/base/BaseIOPage.qml
        qml/pages/base/WindowSurface.qml
        qml/pages/PageWithEmpty.qml
        qml/pages/PageOnStart.qml
        qml/pages/PageOnInitialize.qml
        qml/pages/PageOnCreating.qml
        qml/pages/PageOnTotal.qml
        qml/pages/PageOnUI.qml
        qml/pages/PageOnItem.qml
        qml/pages/PageOnCost.qml
        qml/pages/PageOnDisplay.qml
        qml/pages/PageOnSettings.qml
        qml/pages/settings/SettingsInterface.qml
        qml/pages/settings/SettingsFonts.qml
        qml/pages/settings/SettingsBuildKits.qml
        qml/pages/settings/SettingsBuilder.qml
        qml/pages/settings/SettingsItems.qml
        qml/pages/PageOnAbout.qml

        js/syntax/ItemSyntaxHighlighter.js
        js/ThemeCatalog.js
        js/MinecraftTextColors.js
        js/WorkspaceSchema.js
        js/DisplayFormatting.js
        js/syntax/MacroHighlighter.js
        js/syntax/ItemSyntaxParser.js
        js/syntax/mode-1.js
        js/syntax/mode-2.js

    RESOURCES
        js/ElementRelayState.js
    SOURCES
        src/XCFile.cpp
        src/MinecraftAssetImporter.cpp
        src/main.cpp
        src/ElementIO.cpp

        header/XCFile.h
        header/ElementSortModel.h
        header/EditorFonts.h
        header/EditorHighlighter.h
        src/EditorHighlighter.cpp
        header/MinecraftAssetImporter.h
        header/MinecraftImportSupport.h
        header/ElementIO.h
        header/BuildKitManager.h
        header/BuildManager.h
        header/BuildConsoleDocument.h
        header/WindowStateController.h
)

set_target_properties(appxcshop PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appxcshop
    PRIVATE Qt6::Quick Qt6::QuickPrivate Qt6::QuickControls2 Qt6::Network Qt6::Concurrent xcshop_kit_archive
)
target_compile_definitions(appxcshop PRIVATE XCSHOP_VERSION="${PROJECT_VERSION}")
if(WIN32)
    enable_language(RC)
    configure_file(assets/gui/app-icon.rc.in app-icon.rc @ONLY)
    target_sources(appxcshop PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/app-icon.rc")
    set_source_files_properties("${CMAKE_CURRENT_BINARY_DIR}/app-icon.rc" PROPERTIES
        OBJECT_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/assets/gui/png/xcs-app-icon-blue-flow.ico")
    target_link_libraries(appxcshop PRIVATE dwmapi)
endif()

# Seed bundled kits without replacing templates already installed/edited by the user.
add_custom_command(TARGET appxcshop POST_BUILD
    COMMAND ${CMAKE_COMMAND} "-DKITS_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/kits"
        "-DKITS_TARGET=$<TARGET_FILE_DIR:appxcshop>/kits"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/tools/SeedBuildKits.cmake")

include(GNUInstallDirs)
install(TARGETS appxcshop
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
# Install the same bundled inputs as the post-build seed step.
install(CODE "set(KITS_SOURCE \"${CMAKE_CURRENT_SOURCE_DIR}/kits\")
    set(KITS_TARGET \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}/kits\")
    include(\"${CMAKE_CURRENT_SOURCE_DIR}/tools/SeedBuildKits.cmake\")")

option(XCSHOP_BUILD_TESTS "Build editor integration tests" OFF)
if(XCSHOP_BUILD_TESTS)
    enable_testing()
    find_package(Qt6 REQUIRED COMPONENTS Test)
    # Only ZIP fixture generation uses Qt's private writer.
    if(Qt6_VERSION VERSION_GREATER_EQUAL "6.11")
        find_package(Qt6 REQUIRED COMPONENTS CorePrivate)
        set(XCSHOP_TEST_ZIP_LIBRARY Qt6::CorePrivate)
    else()
        find_package(Qt6 REQUIRED COMPONENTS GuiPrivate)
        set(XCSHOP_TEST_ZIP_LIBRARY Qt6::GuiPrivate)
    endif()
    qt_add_executable(build_kit_acquisition_tests tests/BuildKitAcquisitionTests.cpp
        src/BuildKitManager.cpp header/BuildKitManager.h)
    target_link_libraries(build_kit_acquisition_tests PRIVATE Qt6::Test Qt6::Network Qt6::Concurrent
        xcshop_kit_archive ${XCSHOP_TEST_ZIP_LIBRARY})
    target_compile_definitions(build_kit_acquisition_tests PRIVATE XCSHOP_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")
    add_test(NAME build_kit_acquisition_tests COMMAND build_kit_acquisition_tests)
    qt_add_executable(update_checker_tests tests/UpdateCheckerTests.cpp tests/UpdateFeedFixture.h
        src/UpdateChecker.cpp header/UpdateChecker.h)
    target_link_libraries(update_checker_tests PRIVATE Qt6::Network Qt6::Test)
    add_test(NAME update_checker_tests COMMAND update_checker_tests)
    qt_add_executable(editor_backend_tests tests/EditorBackendTests.cpp
        src/BuildKitManager.cpp header/BuildKitManager.h src/BuildManager.cpp header/BuildManager.h)
    target_link_libraries(editor_backend_tests PRIVATE Qt6::Core Qt6::Test Qt6::Concurrent xcshop_kit_archive)
    qt_add_executable(builder_protocol_fixture tests/BuilderProtocolFixture.cpp)
    target_link_libraries(builder_protocol_fixture PRIVATE Qt6::Core)
    qt_add_executable(minecraft_import_tests tests/MinecraftImportTests.cpp
        src/MinecraftGameData.cpp src/MinecraftItemRenderer.cpp)
    target_link_libraries(minecraft_import_tests PRIVATE Qt6::Gui Qt6::Network Qt6::Test)
    add_test(NAME minecraft_import_tests COMMAND minecraft_import_tests)
    set_tests_properties(minecraft_import_tests PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_FORCE_STDERR_LOGGING=1")
    target_compile_definitions(appxcshop PRIVATE XCSHOP_UI_TESTS=1)
    target_sources(appxcshop PRIVATE tests/UiTestInput.h tests/WindowFrameTests.cpp tests/UpdateFeedFixture.h)
    target_link_libraries(appxcshop PRIVATE Qt6::Test)
    if(WIN32)
        target_link_libraries(appxcshop PRIVATE user32)
        # Exercise the Windows platform plugin: offscreen cannot reproduce native placement bugs.
        add_test(NAME window_frame_tests COMMAND appxcshop --window-frame-tests)
        set_tests_properties(window_frame_tests PROPERTIES
            ENVIRONMENT "QT_QPA_PLATFORM=windows;QT_QUICK_BACKEND=rhi;QSG_RHI_BACKEND=d3d11;QT_FORCE_STDERR_LOGGING=1"
            RUN_SERIAL TRUE
            TIMEOUT 60)
    endif()
    qt_add_resources(appxcshop editor_ui_smoke PREFIX "/" FILES tests/EditorUiSmoke.qml tests/MinecraftItemsSmoke.qml tests/OperationsUiSmoke.qml tests/SharedUiSmoke.qml tests/DropdownUiSmoke.qml tests/LightThemeUiSmoke.qml tests/ThemedIconUiSmoke.qml tests/ExplorerUiSmoke.qml tests/EditorFontsUiSmoke.qml tests/UpdateUiSmoke.qml tests/InitializationUiSmoke.qml)
    foreach(mode IN ITEMS update current offline skip)
        add_test(NAME initialization_${mode}_ui_smoke COMMAND appxcshop --initialization-ui-smoke)
        set_tests_properties(initialization_${mode}_ui_smoke PROPERTIES
            ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1;XCSHOP_INITIALIZATION_TEST_MODE=${mode}"
            FAIL_REGULAR_EXPRESSION "INITIALIZATION_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
            TIMEOUT 30)
    endforeach()
    add_test(NAME update_ui_smoke COMMAND appxcshop --update-ui-smoke)
    set_tests_properties(update_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1"
        FAIL_REGULAR_EXPRESSION "UPDATE_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 30)
    add_test(NAME editor_fonts_ui_smoke COMMAND appxcshop --editor-fonts-ui-smoke)
    set_tests_properties(editor_fonts_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1"
        FAIL_REGULAR_EXPRESSION "EDITOR_FONTS_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 20)
    add_test(NAME explorer_ui_smoke COMMAND appxcshop --explorer-ui-smoke)
    set_tests_properties(explorer_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1"
        FAIL_REGULAR_EXPRESSION "EXPLORER_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 30)
    add_test(NAME themed_icon_ui_smoke COMMAND appxcshop --themed-icon-ui-smoke)
    set_tests_properties(themed_icon_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1"
        FAIL_REGULAR_EXPRESSION "THEMED_ICON_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 30)
    add_test(NAME light_theme_ui_smoke COMMAND appxcshop --light-theme-ui-smoke)
    add_test(NAME background_ui_smoke COMMAND appxcshop --light-theme-ui-smoke)
    add_test(NAME build_kits_ui_smoke COMMAND appxcshop --light-theme-ui-smoke)
    set_tests_properties(build_kits_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1;XCSHOP_THEME_TEST_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/BuildKitsUiSmoke.qml"
        FAIL_REGULAR_EXPRESSION "BUILD_KITS_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 25)
    add_test(NAME about_ui_smoke COMMAND appxcshop --light-theme-ui-smoke)
    add_test(NAME workspace_transition_ui_smoke COMMAND appxcshop --light-theme-ui-smoke)
    add_test(NAME page_transitions_ui_smoke COMMAND appxcshop --light-theme-ui-smoke)
    add_test(NAME settings_sections_ui_smoke COMMAND appxcshop --light-theme-ui-smoke)
    set_tests_properties(settings_sections_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1;XCSHOP_THEME_TEST_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/SettingsSectionsUiSmoke.qml"
        FAIL_REGULAR_EXPRESSION "SETTINGS_SECTIONS_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 20)
    set_tests_properties(page_transitions_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1;XCSHOP_THEME_TEST_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/PageTransitionsUiSmoke.qml"
        FAIL_REGULAR_EXPRESSION "PAGE_TRANSITIONS_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 30)
    set_tests_properties(workspace_transition_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1;XCSHOP_THEME_TEST_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/WorkspaceTransitionUiSmoke.qml"
        FAIL_REGULAR_EXPRESSION "WORKSPACE_TRANSITION_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 30)
    set_tests_properties(about_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1;XCSHOP_THEME_TEST_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/AboutUiSmoke.qml"
        FAIL_REGULAR_EXPRESSION "ABOUT_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 25)
    set_tests_properties(background_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1;XCSHOP_THEME_TEST_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/BackgroundUiSmoke.qml"
        FAIL_REGULAR_EXPRESSION "BACKGROUND_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 20)
    set_tests_properties(light_theme_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1"
        FAIL_REGULAR_EXPRESSION "LIGHT_THEME_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 120)
    add_test(NAME dropdown_ui_smoke COMMAND appxcshop --dropdown-ui-smoke)
    set_tests_properties(dropdown_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1"
        FAIL_REGULAR_EXPRESSION "DROPDOWN_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 25)
    add_test(NAME shared_ui_smoke COMMAND appxcshop --shared-ui-smoke)
    set_tests_properties(shared_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1"
        FAIL_REGULAR_EXPRESSION "SHARED_UI_SMOKE_FAILED;ReferenceError;TypeError;Binding loop;Cannot assign"
        TIMEOUT 30)
    add_test(NAME operations_ui_smoke COMMAND appxcshop --operations-ui-smoke)
    set_tests_properties(operations_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1"
        TIMEOUT 25)
    add_test(NAME editor_backend_tests COMMAND editor_backend_tests $<TARGET_FILE:builder_protocol_fixture>)
    add_test(NAME editor_startup_smoke COMMAND appxcshop --startup-smoke)
    add_test(NAME minecraft_items_ui_smoke COMMAND appxcshop --minecraft-ui-smoke)
    set_tests_properties(minecraft_items_ui_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1"
        TIMEOUT 20)
    set_tests_properties(editor_startup_smoke PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_FORCE_STDERR_LOGGING=1"
        TIMEOUT 15)
endif()
