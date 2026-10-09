# Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 3.14.0)
project(bssl_dart LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(BORINGSSL_ROOT ../third_party/boringssl/)

include(../third_party/boringssl/sources.cmake)

# Symbol prefixing: all BoringSSL symbols become bssl_dart_<symbol>
add_definitions(-DBORINGSSL_PREFIX=bssl_dart)
# Keep BoringSSL free of C++ runtime symbols (such as operator delete from
# virtual destructors), since CMake and hook/link.dart (CLinker) link the
# library with the C compiler driver.
add_definitions(-DBORINGSSL_TEMPORARY_NO_CXX_RUNTIME)

# Architecture and platform detection.
#
# CMAKE_SYSTEM_PROCESSOR is the host's when CMAKE_OSX_ARCHITECTURES selects
# another architecture on macOS, so use the requested architecture instead.
set(BSSL_DART_PROCESSOR "${CMAKE_SYSTEM_PROCESSOR}")
if(APPLE AND CMAKE_OSX_ARCHITECTURES)
  list(LENGTH CMAKE_OSX_ARCHITECTURES BSSL_DART_ARCHITECTURE_COUNT)
  if(BSSL_DART_ARCHITECTURE_COUNT EQUAL 1)
    set(BSSL_DART_PROCESSOR "${CMAKE_OSX_ARCHITECTURES}")
  else()
    # The assembly is per architecture, so universal builds use the C code.
    set(BSSL_DART_PROCESSOR "universal")
  endif()
endif()
string(TOLOWER "${BSSL_DART_PROCESSOR}" BSSL_DART_PROCESSOR)

if("${BSSL_DART_PROCESSOR}" STREQUAL "x86_64" OR "${BSSL_DART_PROCESSOR}" STREQUAL "amd64")
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(ARCH "x86_64")
  else()
    set(ARCH "x86")
  endif()
elseif("${BSSL_DART_PROCESSOR}" STREQUAL "x86" OR "${BSSL_DART_PROCESSOR}" STREQUAL "i386" OR "${BSSL_DART_PROCESSOR}" STREQUAL "i686")
  set(ARCH "x86")
elseif("${BSSL_DART_PROCESSOR}" STREQUAL "aarch64" OR "${BSSL_DART_PROCESSOR}" STREQUAL "arm64" OR "${BSSL_DART_PROCESSOR}" STREQUAL "arm64e")
  set(ARCH "aarch64")
elseif("${BSSL_DART_PROCESSOR}" MATCHES "^arm*")
  set(ARCH "arm")
elseif("${BSSL_DART_PROCESSOR}" STREQUAL "ppc64le")
  set(ARCH "ppc64le")
else()
  set(ARCH "generic")
endif()

if(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
  set(PLATFORM "win")
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin" OR ${CMAKE_SYSTEM_NAME} STREQUAL "iOS")
  set(PLATFORM "apple")
else()
  set(PLATFORM "linux")
endif()

if(MSVC AND NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND "${ARCH}" STREQUAL "aarch64")
  # BoringSSL's Windows AArch64 assembly is gas syntax for clang-cl.
  unset(crypto_sources_win_aarch64)
endif()

if(NOT DEFINED crypto_sources_${PLATFORM}_${ARCH})
  add_definitions(-DOPENSSL_NO_ASM)
  set(crypto_sources_${PLATFORM}_${ARCH})
elseif(WIN32)
  enable_language(ASM_NASM)
  set(OPENSSL_NASM TRUE)
  set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -gcv8")
else()
  if(NOT DEFINED CMAKE_ASM_COMPILER AND DEFINED CMAKE_C_COMPILER)
    set(CMAKE_ASM_COMPILER "${CMAKE_C_COMPILER}")
  endif()
  enable_language(ASM)
endif()

if(MSVC)
  set(MSVC_DISABLED_WARNINGS_STR " -wd4100 -wd4127 -wd4132 -wd4244 -wd4267 -wd4706 -wd4141 -wd4201")
  # -Gy and -Gw put each function and variable in its own COMDAT, so the link
  # hook can drop the unused ones. BoringSSL doesn't use RTTI (-GR-).
  set(CMAKE_C_FLAGS "-utf-8 -W4 -WX -Gy -Gw ${MSVC_DISABLED_WARNINGS_STR}")
  set(CMAKE_CXX_FLAGS "-utf-8 -W4 -WX -Gy -Gw -GR- ${MSVC_DISABLED_WARNINGS_STR}")
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY $<1:${CMAKE_BINARY_DIR}>)
else()
  # BoringSSL doesn't need the C++ runtime (see BORINGSSL_ALLOW_CXX_RUNTIME
  # upstream), so the libraries don't depend on it. Also clear CMake's implicit
  # C++ link libraries so CMake does not pass -lc++ (e.g. libc++_shared.so on
  # Android) or -lstdc++ when linking CXX object files with LINKER_LANGUAGE C.
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-exceptions -fno-rtti")
  set(CMAKE_CXX_IMPLICIT_LINK_LIBRARIES "")
  if(NOT APPLE)
    # One section per function and variable, so the link hook can drop the
    # unused ones. Mach-O linkers already do this per symbol.
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffunction-sections -fdata-sections")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -ffunction-sections -fdata-sections")
  endif()
endif()

if(WIN32)
  set(CMAKE_GENERATOR_CC cl)
  add_definitions(-D_HAS_EXCEPTIONS=0)
  add_definitions(-DWIN32_LEAN_AND_MEAN)
  add_definitions(-DNOMINMAX)
  add_definitions(-D_CRT_SECURE_NO_WARNINGS)
  add_definitions(-DBORINGSSL_UNSAFE_DETERMINISTIC_MODE=0)
endif()

# The sources are compiled once, and linked into both libraries:
#  * bssl_dart, a dynamic library with all of BoringSSL, bundled as is when
#    linking is disabled (for example in `dart run` and `dart test`).
#  * bssl_dart_static, a static library, from which `hook/link.dart` links a
#    dynamic library with only the functions the application uses.
# LINKER_LANGUAGE C is only set on the libraries: on a target with the sources,
# the Visual Studio generator would compile them without CMAKE_CXX_STANDARD.
add_library(
  bssl_dart_objects
  OBJECT
  ${crypto_sources}
  ${crypto_sources_${PLATFORM}_${ARCH}}
)

target_include_directories(
  bssl_dart_objects
  PUBLIC
  ../third_party/boringssl/src/include/
  PRIVATE
  ../third_party/boringssl/src/gen/
)

set_target_properties(
  bssl_dart_objects
  PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  C_VISIBILITY_PRESET default
  VISIBILITY_INLINES_HIDDEN 0
)

add_library(bssl_dart SHARED $<TARGET_OBJECTS:bssl_dart_objects>)
add_library(bssl_dart_static STATIC $<TARGET_OBJECTS:bssl_dart_objects>)

set_target_properties(
  bssl_dart
  bssl_dart_static
  PROPERTIES
  LINKER_LANGUAGE C
)

set_target_properties(
  bssl_dart
  PROPERTIES
  WINDOWS_EXPORT_ALL_SYMBOLS TRUE
)

install(
  TARGETS bssl_dart bssl_dart_static
  RUNTIME DESTINATION .
  LIBRARY DESTINATION .
  ARCHIVE DESTINATION .
)
