QT += core gui network qml quick quickcontrols2 androidextras
CONFIG += c++17
TEMPLATE = app
TARGET = cueflow-legacy

SOURCES += \
    $$PWD/../src/main.cpp \
    $$PWD/../src/SessionController.cpp

HEADERS += \
    $$PWD/../src/SessionController.h \
    $$PWD/../src/ScrollModel.h

RESOURCES += $$PWD/qml.qrc

isEmpty(CUEFLOW_APP_VERSION): CUEFLOW_APP_VERSION = 0.1.0
DEFINES += CUEFLOW_APP_VERSION=\\\"$$CUEFLOW_APP_VERSION\\\"

DEFINES += CUEFLOW_QT5_ANDROID
isEmpty(CUEFLOW_BUILD_COMMIT): CUEFLOW_BUILD_COMMIT = unknown
DEFINES += CUEFLOW_BUILD_COMMIT=\\\"$$CUEFLOW_BUILD_COMMIT\\\"

# Android 6 is API 23. Qt 5.15's supported minimum is Android 5/API 21.
# Qt 5.15/qmake does not honor ANDROID_PACKAGE_NAME as a project variable.
# Use a custom package template prepared from the exact Qt 5.15 installation
# by CI. That template sets the real manifest package and Gradle applicationId.
android {
    ANDROID_PACKAGE_SOURCE_DIR = $$PWD/package-template
    DISTFILES += \
        $$PWD/package-template/AndroidManifest.xml \
        $$PWD/package-template/build.gradle \
        $$PWD/package-template/res/values/libs.xml
}
ANDROID_VERSION_CODE = 103
ANDROID_VERSION_NAME = 0.1.0-legacy
ANDROID_MIN_SDK_VERSION = 21
ANDROID_TARGET_SDK_VERSION = 28
ANDROID_ABIS = armeabi-v7a

# Qt 5.15 / NDK r21 is intentionally isolated to this legacy APK. The primary
# Android build remains Qt 6.12, arm64-v8a, and Android 9+.
