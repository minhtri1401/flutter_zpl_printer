# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "flutter_zpl_printer")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_zpl_printer_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "flutter_zpl_printer_plugin.cpp"
  "flutter_zpl_printer_plugin.h"

  # USB transport (spec 2026-04-22).
  "usb/usb_messages.g.h"
  "usb/usb_messages.g.cpp"
  "usb/usb_path_parser.h"
  "usb/usb_path_parser.cpp"
  "usb/driver_detector.h"
  "usb/driver_detector.cpp"
  "usb/usb_host_api_impl.h"
  "usb/usb_host_api_impl.cpp"
  "usb/usb_hotplug_stream_handler.h"
  "usb/usb_hotplug_stream_handler.cpp"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/flutter_zpl_printer/flutter_zpl_printer_plugin_c_api.h"
  "flutter_zpl_printer_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
# USB: SetupAPI for device enumeration + cfgmgr32 for device instance helpers.
target_link_libraries(${PLUGIN_NAME} PRIVATE setupapi cfgmgr32)

# Require C++17 for std::optional and structured bindings.
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)

# Bundle libusb-1.0.dll alongside the plugin. Path is arch-dependent.
# Consumer builds resolve FLUTTER_TARGET_PLATFORM_ARCH to "x64" or "arm64".
set(LIBUSB_ARCH "x64")
if(DEFINED FLUTTER_TARGET_PLATFORM_ARCH AND FLUTTER_TARGET_PLATFORM_ARCH STREQUAL "arm64")
  set(LIBUSB_ARCH "arm64")
endif()
set(LIBUSB_DLL "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libusb/1.0.29/windows/${LIBUSB_ARCH}/libusb-1.0.dll")

# List of absolute paths to libraries that should be bundled with the plugin.
if(EXISTS "${LIBUSB_DLL}")
  set(flutter_zpl_printer_bundled_libraries
    "${LIBUSB_DLL}"
    PARENT_SCOPE
  )
else()
  message(WARNING "libusb-1.0.dll not found at ${LIBUSB_DLL}. USB transport will fail at runtime. Run tool/fetch_libusb.sh to fetch.")
  set(flutter_zpl_printer_bundled_libraries
    ""
    PARENT_SCOPE
  )
endif()

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

# Add the Google Test dependency.
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/release-1.11.0.zip
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

# The plugin's C API is not very useful for unit testing, so build the sources
# directly into the test binary rather than using the DLL.
add_executable(${TEST_RUNNER}
  test/flutter_zpl_printer_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
