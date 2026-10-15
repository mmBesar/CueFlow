cmake_minimum_required(VERSION 3.21)
project(CueFlow VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
option(CUEFLOW_BUILD_APP "Build the Qt Quick application" ON)
option(CUEFLOW_DEPLOY_QT_RUNTIME "Bundle Qt libraries and QML imports in the desktop install tree" ON)
set(CUEFLOW_BUILD_COMMIT "unknown" CACHE STRING "Source commit used to build CueFlow")
include(CTest)

# Keep the playback core testable without installing Qt. This is useful for
# lightweight CI jobs and cross-compilation checks on less common Linux CPUs.
if(BUILD_TESTING)
    add_executable(scroll_model_test tests/scroll_model_test.cpp)
    target_include_directories(scroll_model_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
    add_test(NAME scroll_model_test COMMAND scroll_model_test)
endif()

if(CUEFLOW_BUILD_APP)
    find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2 Svg)
    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)
    set(CMAKE_AUTOUIC ON)
    qt_standard_project_setup(REQUIRES 6.5)

    qt_add_executable(cueflow
        src/main.cpp
        src/SessionController.cpp
        src/SessionController.h
        src/ScrollModel.h
    )

    qt_add_qml_module(cueflow
        URI CueFlow
        VERSION 1.0
        QML_FILES
            qml/Main.qml
    )

    qt_add_resources(cueflow cueflow_icon_resources
        PREFIX "/icons"
        BASE icon
        FILES icon/CueFlow-icon.svg
    )

    target_compile_definitions(cueflow PRIVATE
        CUEFLOW_BUILD_COMMIT="${CUEFLOW_BUILD_COMMIT}"
        CUEFLOW_APP_VERSION="${PROJECT_VERSION}"
    )

    if(ANDROID)
        # Keep the Qt activity's launcher identity separate from the in-app
        # window icon. Android 9+ uses density-specific copies of the same mark.
        set_property(TARGET cueflow PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR
            "${CMAKE_CURRENT_SOURCE_DIR}/packaging/android")
        set_property(TARGET cueflow PROPERTY QT_ANDROID_APP_ICON "@mipmap/ic_launcher")
        set_property(TARGET cueflow PROPERTY QT_ANDROID_APP_NAME "CueFlow")
        set_property(TARGET cueflow PROPERTY QT_ANDROID_VERSION_CODE 100)
        set_property(TARGET cueflow PROPERTY QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}")
    endif()

    target_link_libraries(cueflow PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Network
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Svg
    )

    # Android 16 KB page-size compatibility. Qt 6.12 supports Android 16,
    # but this app is built with NDK r27, where 16 KB ELF alignment must be
    # requested explicitly for application-owned shared objects.
    if(ANDROID)
        target_link_options(cueflow PRIVATE
            "-Wl,-z,max-page-size=16384"
            "-Wl,-z,common-page-size=16384"
        )
    endif()

    # qt_add_executable() creates a normal executable on desktop platforms,
    # but a MODULE library on Android. Do not use a desktop RUNTIME install
    # rule for that Android module: the APK target handles Android packaging.
    if(NOT ANDROID)
        install(TARGETS cueflow RUNTIME DESTINATION bin)
        install(FILES packaging/linux/cueflow.desktop DESTINATION share/applications)
        install(FILES icon/CueFlow-icon.svg DESTINATION share/icons/hicolor/scalable/apps RENAME cueflow.svg)

        # Generic Linux CI artifacts use a Qt deployment tree. Nix packages
        # should instead use the Qt libraries in the Nix store and disable this
        # copy-based deployment step with -DCUEFLOW_DEPLOY_QT_RUNTIME=OFF.
        if(CUEFLOW_DEPLOY_QT_RUNTIME)
            qt_generate_deploy_qml_app_script(
                TARGET cueflow
                OUTPUT_SCRIPT deploy_script
                NO_UNSUPPORTED_PLATFORM_ERROR
            )
            install(SCRIPT ${deploy_script})
        endif()
    endif()
endif()
