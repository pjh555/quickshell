cmake_minimum_required(VERSION 3.21)

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" PROJECT_DATE_VERSION LIMIT_COUNT 1)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION")
project(ClavisShell VERSION ${PROJECT_DATE_VERSION} LANGUAGES C CXX)

include(GNUInstallDirs)
include(CTest)

set(CLAVIS_QML_BUILD_DIR "${CMAKE_BINARY_DIR}/qml" CACHE PATH
    "Build-tree QML import root")
# Qt's own install layout is multiarch-aware on Debian/Ubuntu
# (for example lib/aarch64-linux-gnu/qt6/qml), unlike Arch's lib/qt6/qml.
find_package(Qt6 QUIET COMPONENTS Qml)
if(DEFINED QT6_INSTALL_QML)
    set(CLAVIS_QML_DEFAULT_INSTALL_DIR "${QT6_INSTALL_QML}")
else()
    set(CLAVIS_QML_DEFAULT_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml")
endif()
set(CLAVIS_QML_INSTALL_DIR "${CLAVIS_QML_DEFAULT_INSTALL_DIR}" CACHE STRING
    "Install destination for Clavis private QML modules, relative to the install prefix")
# Existing Arch-oriented build directories cached lib/qt6/qml. On Debian/Ubuntu
# that path is not searched by Qt; migrate the untouched default to the
# multiarch directory reported by Qt.
if(CLAVIS_QML_INSTALL_DIR STREQUAL "lib/qt6/qml"
   AND DEFINED QT6_INSTALL_QML
   AND NOT QT6_INSTALL_QML STREQUAL "lib/qt6/qml")
    set(CLAVIS_QML_INSTALL_DIR "${QT6_INSTALL_QML}" CACHE STRING
        "Install destination for Clavis private QML modules, relative to the install prefix" FORCE)
endif()
set(CLAVIS_CONFIG_INSTALL_DIR "etc/xdg/quickshell/clavis" CACHE STRING
    "Install destination for the Quickshell clavis configuration, relative to the prefix")
set(CLAVIS_SYSTEMD_USER_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/systemd/user" CACHE STRING
    "Install destination for Clavis systemd user units, relative to the prefix")

find_package(Python3 REQUIRED COMPONENTS Interpreter)
file(GLOB SEARCH_DECLARATIONS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/Modules/ControlCenter/*.qml")
set(SEARCH_CATALOG "${CMAKE_CURRENT_SOURCE_DIR}/Common/generated/SearchCatalog.js")
add_custom_command(OUTPUT "${SEARCH_CATALOG}"
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/scripts/dev/generate-search-catalog.py"
    DEPENDS ${SEARCH_DECLARATIONS}
        "${CMAKE_CURRENT_SOURCE_DIR}/Common/settings-routes.json"
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts/system/niri-actions.json"
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts/dev/generate-search-catalog.py"
    VERBATIM)
add_custom_target(search_catalog ALL DEPENDS "${SEARCH_CATALOG}")

add_subdirectory(core)
