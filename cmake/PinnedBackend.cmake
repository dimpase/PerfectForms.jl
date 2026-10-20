include(FetchContent)
include(SourceProvenance)

option(AV_BACKEND_FETCH_PROGRESS "Show progress while fetching backend sources" ON)
option(AV_BACKEND_DEVELOPMENT "Allow revisions and patches in an explicit local backend checkout" OFF)

if(AV_BACKEND_DEVELOPMENT AND NOT FETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON)
  message(FATAL_ERROR "AV_BACKEND_DEVELOPMENT requires FETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON")
endif()
if(FETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON)
  if(NOT IS_ABSOLUTE "${FETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON}" OR
      NOT IS_DIRECTORY "${FETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON}")
    message(FATAL_ERROR "FETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON must name an existing absolute checkout")
  endif()
endif()

set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${PROJECT_SOURCE_DIR}/backend/pins.json")
file(READ "${PROJECT_SOURCE_DIR}/backend/pins.json" AV_BACKEND_PINS)
string(JSON AV_BACKEND_REPOSITORY GET "${AV_BACKEND_PINS}" repository)
string(JSON AV_BACKEND_PINNED_COMMIT GET "${AV_BACKEND_PINS}" commit)

FetchContent_Declare(polyhedral_common
  GIT_REPOSITORY "${AV_BACKEND_REPOSITORY}"
  GIT_TAG "${AV_BACKEND_PINNED_COMMIT}"
  GIT_PROGRESS "${AV_BACKEND_FETCH_PROGRESS}"
  GIT_SUBMODULES_RECURSE TRUE
  UPDATE_DISCONNECTED TRUE
  # Only headers are used. This directory intentionally has no CMake project;
  # FetchContent therefore does not add the upstream standalone build.
  SOURCE_SUBDIR _polyhedral_common_headers_only)

function(av_populate_backend)
  if(AV_BACKEND_FETCH_PROGRESS)
    # Scope verbosity to this fetch, including builds with a cached QUIET=ON.
    set(FETCHCONTENT_QUIET OFF)
    # With CMP0168=NEW (CMake 3.30+), the message level controls fetch output.
    # Preserve explicit quiet/debug levels; --log-level also takes precedence.
    if(NOT DEFINED CMAKE_MESSAGE_LOG_LEVEL OR CMAKE_MESSAGE_LOG_LEVEL STREQUAL "STATUS")
      set(CMAKE_MESSAGE_LOG_LEVEL VERBOSE)
    endif()
  endif()
  FetchContent_MakeAvailable(polyhedral_common)
endfunction()

if(FETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON)
  message(STATUS "Using backend source override: ${FETCHCONTENT_SOURCE_DIR_POLYHEDRAL_COMMON}")
else()
  message(STATUS "Preparing polyhedral_common at ${AV_BACKEND_PINNED_COMMIT} (download/cache and recursive submodules)")
endif()
string(TIMESTAMP _av_fetch_start "%s")
av_populate_backend()
FetchContent_GetProperties(polyhedral_common)
string(TIMESTAMP _av_fetch_end "%s")
math(EXPR _av_fetch_seconds "${_av_fetch_end} - ${_av_fetch_start}")
message(STATUS "Backend sources ready (${_av_fetch_seconds}s)")

string(JSON _count LENGTH "${AV_BACKEND_PINS}" submodules)
math(EXPR _total "${_count} + 1")
string(TIMESTAMP _av_verify_start "%s")
if(AV_BACKEND_DEVELOPMENT)
  set(_mode "local")
else()
  set(_mode "pinned")
endif()
message(STATUS "Inspecting ${_mode} source [1/${_total}]: polyhedral_common")
av_describe_source("${polyhedral_common_SOURCE_DIR}" "${AV_BACKEND_PINNED_COMMIT}" AV_BACKEND_SOURCE_INFO)
string(JSON AV_BACKEND_COMMIT GET "${AV_BACKEND_SOURCE_INFO}" commit)
string(JSON AV_BACKEND_SOURCE_INFO SET "${AV_BACKEND_SOURCE_INFO}" mode "\"${_mode}\"")
string(JSON AV_BACKEND_SOURCE_INFO SET "${AV_BACKEND_SOURCE_INFO}" submodules "{}")
math(EXPR _last "${_count} - 1")
foreach(_index RANGE 0 ${_last})
  string(JSON _path MEMBER "${AV_BACKEND_PINS}" submodules ${_index})
  string(JSON _commit GET "${AV_BACKEND_PINS}" submodules "${_path}")
  math(EXPR _step "${_index} + 2")
  message(STATUS "Inspecting ${_mode} source [${_step}/${_total}]: ${_path}")
  av_describe_source("${polyhedral_common_SOURCE_DIR}/${_path}" "${_commit}" _info)
  string(JSON AV_BACKEND_SOURCE_INFO SET "${AV_BACKEND_SOURCE_INFO}" submodules "${_path}" "${_info}")
endforeach()
string(SHA256 AV_BACKEND_SOURCE_SHA256 "${AV_BACKEND_SOURCE_INFO}")
string(TIMESTAMP _av_verify_end "%s")
math(EXPR _av_verify_seconds "${_av_verify_end} - ${_av_verify_start}")
message(STATUS "Backend source provenance recorded (${_av_verify_seconds}s; ${_mode} mode)")
