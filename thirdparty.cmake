cmake_minimum_required(VERSION 3.25)


function (find_suitable_git_version_tag
    REPO_URL TAG_PREFIX MIN_VERSION
    OUT_STATUS_VARIABLE OUT_TAG_VARIABLE
  )

  find_package(Git)
  if (NOT Git_FOUND)
    set(${OUT_STATUS_VARIABLE} FALSE PARENT_SCOPE)
    set(${OUT_TAG_VARIABLE} "" PARENT_SCOPE)
    return()
  endif()

  execute_process(
    COMMAND ${GIT_EXECUTABLE} ls-remote --tags ${REPO_URL}
    RESULT_VARIABLE TAGS_RESULT
    OUTPUT_VARIABLE TAG_LIST
  )

  if (${TAGS_RESULT} AND NOT ${TAGS_RESULT} EQUAL 0)
    set(${OUT_STATUS_VARIABLE} FALSE PARENT_SCOPE)
    set(${OUT_TAG_VARIABLE} "" PARENT_SCOPE)
    return()
  endif()

  string(REGEX REPLACE
    "[a-f0-9]+\trefs/tags/${TAG_PREFIX}([^\r\n]+)\r?\n" "\\1\n"
    VERSION_LIST "${TAG_LIST}")
  string(REGEX REPLACE
    "[a-f0-9]+\trefs/tags/([^\r\n]+)\r?\n" ""
    VERSION_LIST "${VERSION_LIST}")
  string(REPLACE "\n" ";"
    VERSION_LIST "${VERSION_LIST}")


  set(BEST_VERSION "")
  foreach (VERSION IN LISTS VERSION_LIST)
    if (
	(NOT "${VERSION}" STREQUAL "") AND
	("${VERSION}" VERSION_GREATER_EQUAL "${MIN_VERSION}")
      )
      if (
	  ("${BEST_VERSION}" STREQUAL "") OR
	  ("${VERSION}" VERSION_LESS "${BEST_VERSION}")
	)
	set(BEST_VERSION "${VERSION}")
      endif()
    endif()
  endforeach()

  if ("${BEST_VERSION}" STREQUAL "")
    set(${OUT_STATUS_VARIABLE} FALSE PARENT_SCOPE)
    set(${OUT_TAG_VARIABLE} "" PARENT_SCOPE)
    return()
  endif()

  set(${OUT_STATUS_VARIABLE} TRUE PARENT_SCOPE)
  set(${OUT_TAG_VARIABLE} "${TAG_PREFIX}${BEST_VERSION}" PARENT_SCOPE)
endfunction()


find_package(Vulkan 1.3.275 REQUIRED)

# GPU-side allocator for Vulkan by AMD
CPMAddPackage(
  NAME VulkanMemoryAllocator
  GITHUB_REPOSITORY GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator
  # A little bit after v3.1.0 to get nice cmake
  GIT_TAG b8e57472fffa3bd6e0a0b675f4615bf0a823ec4d
)
# VMA headers emit a bunch of warnings >:(
set_property(TARGET VulkanMemoryAllocator PROPERTY SYSTEM TRUE)

# Collection of libraries for loading various image formats
CPMAddPackage(
  NAME StbLibraries
  GITHUB_REPOSITORY nothings/stb
  # Some random version because STB doesn't use git tags...
  GIT_TAG f75e8d1cad7d90d72ef7a4661f1b994ef78b4e31
  DOWNLOAD_ONLY YES
)
if (StbLibraries_ADDED)
  add_library(StbLibraries INTERFACE)
  target_include_directories(StbLibraries INTERFACE ${StbLibraries_SOURCE_DIR}/)
endif ()

# Official library for parsing SPIRV bytecode
# We grab the exact SDK version from github so that
# you don't have to remember to mark a checkbox while installing the SDK =)
#
# UPD 2024.09.07: SPIRV-Reflect repository does not have tags for all
# the Vulkan versions. For example, there are tags
# `vulkan-sdk-1.3.283.0` and `vulkan-sdk-1.3.290.0`, but no tags
# "covering" versions between "1.3.283.0" and
# "1.3.290.0". Furthermore, the version of Vulkan may contain only
# three components (major, minor and patch), while in tags there are
# four-component versions (major, minor, patch and tweak). Therefore,
# the tag selection has to be more elaborate

find_suitable_git_version_tag(
  https://github.com/KhronosGroup/SPIRV-Reflect
  vulkan-sdk- ${Vulkan_VERSION}
  SPIRV_REFLECT_GIT_TAG_STATUS
  SPIRV_REFLECT_GIT_TAG
)

if (NOT ${SPIRV_REFLECT_GIT_TAG_STATUS})
  message(
    WARNING
    "Could not find a suitable git tag for SPIRV-Reflect. Using the exact Vulkan version")
  set(SPIRV_REFLECT_GIT_TAG ${Vulkan_VERSION})
endif()

CPMAddPackage(
  NAME SpirvReflect
  GITHUB_REPOSITORY KhronosGroup/SPIRV-Reflect
  GIT_TAG "${SPIRV_REFLECT_GIT_TAG}"
  OPTIONS
    "SPIRV_REFLECT_EXECUTABLE OFF"
    "SPIRV_REFLECT_STRIPPER OFF"
    "SPIRV_REFLECT_EXAMPLES OFF"
    "SPIRV_REFLECT_BUILD_TESTS OFF"
    "SPIRV_REFLECT_STATIC_LIB ON"
)

# Fmt is a dependency of spdlog, but to be
# safe we explicitly specify our version
CPMAddPackage(
  NAME fmt
  GITHUB_REPOSITORY fmtlib/fmt
  GIT_TAG 10.2.1
  OPTIONS
    "FMT_SYSTEM_HEADERS"
    "FMT_DOC OFF"
    "FMT_INSTALL OFF"
    "FMT_TEST OFF"
)

# Simple logging without headaches
CPMAddPackage(
  NAME spdlog
  GITHUB_REPOSITORY gabime/spdlog
  VERSION 1.13.0
  OPTIONS
    SPDLOG_FMT_EXTERNAL
)

# A profiler for both CPU and GPU
CPMAddPackage(
  GITHUB_REPOSITORY wolfpld/tracy
  GIT_TAG v0.11.1
  OPTIONS
    "TRACY_ON_DEMAND ON"
)
