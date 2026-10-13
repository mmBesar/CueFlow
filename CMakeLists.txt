cmake_minimum_required(VERSION 3.21)
project(CueFlow VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
option(CUEFLOW_BUILD_APP "Build the Qt Quick application" ON)
include(CTest)

# Keep the playback core testable without installing Qt. This is useful for
# lightweight CI jobs and cross-compilation checks on less common Linux CPUs.
if(BUILD_TESTING)
    add_executable(scroll_model_test tests/scroll_model_test.cpp)
    target_include_directories(scroll_model_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
    add_test(NAME scroll_model_test COMMAND scroll_model_test)
endif()

if(CUEFLOW_BUILD_APP)
    find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2)
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

    target_link_libraries(cueflow PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Network
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
    )

    # qt_add_executable() creates a normal executable on desktop platforms,
    # but a MODULE library on Android. Do not use a desktop RUNTIME install
    # rule for that Android module: the APK target handles Android packaging.
    if(NOT ANDROID)
        install(TARGETS cueflow RUNTIME DESTINATION bin)

        # Produce a Linux install tree with the Qt runtime and QML imports.
        qt_generate_deploy_qml_app_script(
            TARGET cueflow
            OUTPUT_SCRIPT deploy_script
            NO_UNSUPPORTED_PLATFORM_ERROR
        )
        install(SCRIPT ${deploy_script})
    endif()
endif()
