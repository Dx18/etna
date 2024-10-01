cmake_minimum_required(VERSION 3.25)


# Finds suitable git tag version for remote repository located at
# `${REPO_URL}.
#
# 1. Uses `git ls-remote` to find all the repository tags;
#
# 2. Finds the tags starting with the given prefix `${TAG_PREFIX}`
#    (this prefix may be a regular expression);
#
# 3. Treats everything after the prefix as a version;
#
# 4. Finds the smallest of the versions greater than or equal to the
#    given version `${MIN_VERSION}`;
#
# 5. Suppose this version is `${VERSION}`. Then, it returns the tag
#    that "had" this version in it.
#
# Sets variables `${OUT_STATUS_VARIABLE}` and `${OUT_TAG_VARIABLE}` as
# a result. `${OUT_STATUS_VARIABLE}` will hold the boolean value
# indicating whether the operation succeeded or not, and
# `${OUT_TAG_VARIABLE}` will hold the returned tag (or, on failure, an
# empty string).
#
# The functions returns with an error if:
#
# 1. `git` is not found;
#
# 2. `git ls-remote` fails;
#
# 3. One of the versions presented in the repository does not have the
#    correct format;
#
# 4. All the versions presented in the repository are less than the
#    given minimum version.
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

  # Constructing a line list
  string(REGEX REPLACE "\r?\n" ";"
    TAG_LIST "${TAG_LIST}")

  set(EXTRACT_TAG_REGEX "^[a-f0-9]+\trefs/tags/([^\r\n]+)$")

  set(BEST_TAG "")
  set(BEST_VERSION "")
  foreach (TAG IN LISTS TAG_LIST)
    # Extracting the tag
    string(REGEX REPLACE "${EXTRACT_TAG_REGEX}" "\\1" TAG "${TAG}")

    # Check if the tag starts with the given prefix. Note that the
    # given prefix may be a regular expression
    if ("${TAG}" MATCHES "^${TAG_PREFIX}(.+)")
      set(VERSION "${CMAKE_MATCH_${CMAKE_MATCH_COUNT}}")

      if ("${VERSION}" MATCHES "([0-9]+)(\\.([0-9]+)(\\.([0-9]+)(\\.([0-9]+))?)?)?")
	# This is indeed a version

	if (("${VERSION}" VERSION_GREATER_EQUAL "${MIN_VERSION}") AND
	    (("${BEST_VERSION}" STREQUAL "") OR
	      ("${VERSION}" VERSION_LESS "${BEST_VERSION}")))
	  set(BEST_TAG "${TAG}")
	  set(BEST_VERSION "${VERSION}")
	endif()
      else()
	# This is not a version and we do not know what to with it
	set(${OUT_STATUS_VARIABLE} FALSE PARENT_SCOPE)
	set(${OUT_TAG_VARIABLE} "" PARENT_SCOPE)
	return()
      endif()
    endif()
  endforeach()

  if ("${BEST_VERSION}" STREQUAL "")
    set(${OUT_STATUS_VARIABLE} FALSE PARENT_SCOPE)
    set(${OUT_TAG_VARIABLE} "" PARENT_SCOPE)
    return()
  endif()

  set(${OUT_STATUS_VARIABLE} TRUE PARENT_SCOPE)
  set(${OUT_TAG_VARIABLE} "${BEST_TAG}" PARENT_SCOPE)
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

option(SPIRV_REFLECT_VERSION_SMART_SEARCH
  "Use more elaborate search for the SPIRV-Reflect git tag" OFF
)

if (SPIRV_REFLECT_VERSION_SMART_SEARCH)
  find_suitable_git_version_tag(
    https://github.com/KhronosGroup/SPIRV-Reflect
    "(vulkan-)?sdk-" "${Vulkan_VERSION}"
    SPIRV_REFLECT_GIT_TAG_STATUS
    SPIRV_REFLECT_GIT_TAG
  )

  if (NOT ${SPIRV_REFLECT_GIT_TAG_STATUS})
    message(
      WARNING
      "Could not find a suitable git tag for SPIRV-Reflect although the search was requested. Using the exact Vulkan version")
    set(SPIRV_REFLECT_GIT_TAG "vulkan-sdk-${Vulkan_VERSION}")
  endif()
else()
  set(SPIRV_REFLECT_GIT_TAG "vulkan-sdk-${Vulkan_VERSION}")
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
