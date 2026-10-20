# Inspect a Git working tree without updating its index or changing any files.
function(av_describe_source directory expected output)
  execute_process(COMMAND "${GIT_EXECUTABLE}" --no-optional-locks rev-parse --show-toplevel
    WORKING_DIRECTORY "${directory}"
    RESULT_VARIABLE _status OUTPUT_VARIABLE _root OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT _status EQUAL 0)
    message(FATAL_ERROR "Not a Git checkout: ${directory}. Initialize the required submodules.")
  endif()
  file(REAL_PATH "${directory}" _directory)
  file(REAL_PATH "${_root}" _root)
  if(NOT _directory STREQUAL _root)
    message(FATAL_ERROR "Missing submodule checkout: ${directory}. Initialize the required submodules.")
  endif()
  execute_process(COMMAND "${GIT_EXECUTABLE}" --no-optional-locks rev-parse HEAD
    WORKING_DIRECTORY "${directory}"
    COMMAND_ERROR_IS_FATAL ANY OUTPUT_VARIABLE _commit OUTPUT_STRIP_TRAILING_WHITESPACE)
  execute_process(COMMAND "${GIT_EXECUTABLE}" --no-optional-locks status
      --porcelain=v1 --untracked-files=all --ignore-submodules=none
    WORKING_DIRECTORY "${directory}"
    COMMAND_ERROR_IS_FATAL ANY OUTPUT_VARIABLE _status OUTPUT_STRIP_TRAILING_WHITESPACE)
  set(_dirty false)
  if(NOT _status STREQUAL "")
    set(_dirty true)
  endif()
  if(NOT AV_BACKEND_DEVELOPMENT)
    if(NOT _commit STREQUAL expected)
      message(FATAL_ERROR "Unpinned backend source at ${directory}: expected ${expected}, got ${_commit}")
    endif()
    if(_dirty)
      message(FATAL_ERROR "Backend source has local modifications: ${directory}. Use a clean pinned checkout, or explicitly enable AV_BACKEND_DEVELOPMENT with a local source override.")
    endif()
  endif()

  # Include tracked and new, nonignored files. Submodule directories are
  # described separately. Hash working files rather than the Git index, so
  # uncommitted edits and newly added headers affect the build identity.
  execute_process(COMMAND "${GIT_EXECUTABLE}" --no-optional-locks -c core.quotepath=false
      ls-files --cached --others --exclude-standard
    WORKING_DIRECTORY "${directory}"
    COMMAND_ERROR_IS_FATAL ANY OUTPUT_VARIABLE _files OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE "\n" ";" _files "${_files}")
  list(REMOVE_DUPLICATES _files)
  list(SORT _files)
  set(_inventory "")
  foreach(_file IN LISTS _files)
    if(IS_DIRECTORY "${directory}/${_file}")
      continue()
    endif()
    if(_file MATCHES "^\"")
      message(FATAL_ERROR "Unsupported quoted Git filename in ${directory}: ${_file}")
    endif()
    if(EXISTS "${directory}/${_file}")
      file(SHA256 "${directory}/${_file}" _hash)
      set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${directory}/${_file}")
    else()
      set(_hash "deleted")
    endif()
    string(APPEND _inventory "${_file}\n${_hash}\n")
  endforeach()
  string(SHA256 _tree_sha256 "${_inventory}")
  string(JSON _info SET "{}" commit "\"${_commit}\"")
  string(JSON _info SET "${_info}" dirty "${_dirty}")
  string(JSON _info SET "${_info}" tree_sha256 "\"${_tree_sha256}\"")
  set(${output} "${_info}" PARENT_SCOPE)
endfunction()
