# LociSysConf.cmake
#
# Produces the four legacy configuration files (sys.conf, comp.conf,
# version.conf, Loci.conf) in the CMake binary dir and builds the
# OBJ-compatible directory layout (include/, lib/, bin/, quickTest/, docs/).
# This makes the binary dir usable as LOCI_BASE for:
#   * the unmodified quickTest GNU-make suites, and
#   * external Loci application Makefiles that include $(LOCI_BASE)/Loci.conf.

# --------------------------------------------------------------------------
# Versioning (legacy: $(shell git describe --abbrev=6 --always --dirty --tags))
# --------------------------------------------------------------------------
find_package(Git QUIET)
set(LOCI_GIT_INFO "unknown-version")
set(LOCI_GIT_BRANCH "unknown-branch")
if(GIT_FOUND AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
  execute_process(COMMAND ${GIT_EXECUTABLE} describe --abbrev=6 --always
    --dirty --tags
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE LOCI_GIT_INFO OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET RESULT_VARIABLE _gitrc)
  execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE LOCI_GIT_BRANCH OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET RESULT_VARIABLE _gitrc2)
endif()
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git" AND
   EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/version.conf")
  # tarball-with-docs flow: pre-stamped version file (legacy configure rule)
  include("${CMAKE_CURRENT_SOURCE_DIR}/src/version.conf" OPTIONAL
    RESULT_VARIABLE _vf)
  message(STATUS "Loci: version from src/version.conf: "
    "${LOCI_GIT_INFO} (${LOCI_GIT_BRANCH})")
endif()

# Legacy parses MAJOR/MINOR with sed on "vNN.NN"; untagged checkouts produced
# a bare hash there, which fails to compile.  Fall back to 0/0 in that case.
string(REGEX MATCH "^v([0-9]+)" _loci_vmaj "${LOCI_GIT_INFO}")
set(LOCI_VERSION_MAJOR 0)
set(LOCI_VERSION_MINOR 0)
if(CMAKE_MATCH_1)
  set(LOCI_VERSION_MAJOR ${CMAKE_MATCH_1})
  if(LOCI_GIT_INFO MATCHES "^v[0-9]+[.]([0-9]+)")
    set(LOCI_VERSION_MINOR ${CMAKE_MATCH_1})
  endif()
endif()

set(LOCI_REVISION_NAME "${LOCI_GIT_BRANCH}-${LOCI_GIT_INFO}")

# --------------------------------------------------------------------------
# Install path (Loci.conf: LOCI_INSTALL_DIR appended unless --no-sub-dir).
# Legacy 'make install' physically installs into
#   <prefix>/Loci-<sys>-<arch>-<comp>-<rev>/  when sub-dir mode is on,
# so nest the effective CMAKE_INSTALL_PREFIX accordingly (the user-given
# prefix is remembered so re-configures do not double-nest; sys.conf keeps
# recording the raw prefix as INSTALL_DIR, like configure does).
# --------------------------------------------------------------------------
# An explicitly re-passed -DCMAKE_INSTALL_PREFIX wins; a plain re-configure
# (cache holds the previously forced nested path) re-derives from the
# remembered user prefix instead of double-nesting.
if(DEFINED LOCI_INSTALL_PATH_CACHE AND CMAKE_INSTALL_PREFIX
   STREQUAL LOCI_INSTALL_PATH_CACHE)
  set(_loci_prefix_raw "${LOCI_USER_INSTALL_PREFIX}")
else()
  set(_loci_prefix_raw "${CMAKE_INSTALL_PREFIX}")
endif()
if(LOCI_NO_SUB_DIR)
  set(LOCI_NO_SUB_DIR01 1)
  set(LOCI_INSTALL_PATH "${_loci_prefix_raw}")
else()
  set(LOCI_NO_SUB_DIR01 0)
  set(LOCI_INSTALL_PATH
    "${_loci_prefix_raw}/Loci-${LOCI_SYS_TYPE}-${LOCI_ARCH_TYPE}-${COMP_NAME}-${LOCI_REVISION_NAME}")
endif()
set(LOCI_USER_INSTALL_PREFIX "${_loci_prefix_raw}" CACHE INTERNAL
  "Loci: user-given install prefix" FORCE)
set(LOCI_INSTALL_PATH_CACHE "${LOCI_INSTALL_PATH}" CACHE INTERNAL
  "Loci: effective nested install prefix" FORCE)
set(LOCI_INSTALL_DIR "${_loci_prefix_raw}")
set(LOCI_RPATH "${LOCI_INSTALL_PATH}/lib")
if(NOT LOCI_INSTALL_PATH STREQUAL _loci_prefix_raw)
  set(CMAKE_INSTALL_PREFIX "${LOCI_INSTALL_PATH}" CACHE PATH
    "Install prefix (Loci versioned subdirectory)" FORCE)
endif()

# --------------------------------------------------------------------------
# version.conf (same format the legacy configure wrote)
# --------------------------------------------------------------------------
file(WRITE "${CMAKE_BINARY_DIR}/version.conf"
"GIT_INFO   = ${LOCI_GIT_INFO}
GIT_BRANCH = ${LOCI_GIT_BRANCH}

COMP_NAME = $(shell echo $(CXX) | sed -e 's/ .*//' -e 's/.*\\///')
LOCI_REVISION_NAME = '\${GIT_BRANCH}-\${GIT_INFO}'
")
# Install.bash sed-normalizes the two GIT lines at install time; also keep
# the installed variant (kept in CMAKE_FILES_DIRECTORY, out of the tree)
file(WRITE "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/version-install.conf"
"GIT_INFO = ${LOCI_GIT_INFO}
GIT_BRANCH = ${LOCI_GIT_BRANCH}

COMP_NAME = $(shell echo $(CXX) | sed -e 's/ .*//' -e 's/.*\\///')
LOCI_REVISION_NAME = '\${GIT_BRANCH}-\${GIT_INFO}'
\n")


# --------------------------------------------------------------------------
# comp.conf: copied from src/conf/<compiler>.conf only when absent, so build
# trees can be hand-edited and survive re-configure (tmpcopy semantics).
# --------------------------------------------------------------------------
if(NOT EXISTS "${CMAKE_BINARY_DIR}/comp.conf")
  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/src/conf/${LOCI_COMPILER}.conf"
    "${CMAKE_BINARY_DIR}/comp.conf" COPYONLY)
endif()

# --------------------------------------------------------------------------
# sys.conf
# --------------------------------------------------------------------------
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(LOCI_DYNAMIC_LOADING_LINK "-ldl")
else()
  set(LOCI_DYNAMIC_LOADING_LINK "")
endif()
if(LOCI_CUDA)
  set(LOCI_CUDA_MACHINE_SPECIFIC "$(CUDA_INCLUDE) \\")
  set(LOCI_CUDA_BASE_LIBS "$(CUDA_LIBS) \\")
else()
  set(LOCI_CUDA_MACHINE_SPECIFIC "")
  set(LOCI_CUDA_BASE_LIBS "")
endif()
if(LOCI_BOUNDS_CHECK)
  set(LOCI_BOUNDS01 1)
else()
  set(LOCI_BOUNDS01 0)
endif()
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/cmake/sys.conf.in"
  "${CMAKE_BINARY_DIR}/sys.conf")
# Normalise blank lines: legacy appends exactly one blank line after each
# section, so never allow runs of blank lines or trailing blank lines at EOF.
# Also drop trailing space on lines whose value is empty: legacy builds every
# "VAR = <value>" line with echo(1) token joining, which leaves no trailing
# space when <value> is empty.  Lines with actual content keep their exact
# spacing (some legacy continuation lines legitimately end in a space).
file(READ "${CMAKE_BINARY_DIR}/sys.conf" _loci_sysconf)
string(REGEX REPLACE "\n\n\n+" "\n\n" _loci_sysconf "${_loci_sysconf}")
string(REGEX REPLACE "((^|\n)[A-Za-z_0-9]+ ?=) +(\n|$)" "\\1\\3"
  _loci_sysconf "${_loci_sysconf}")
string(REGEX REPLACE "\n+$" "\n" _loci_sysconf "${_loci_sysconf}")
file(WRITE "${CMAKE_BINARY_DIR}/sys.conf" "${_loci_sysconf}")

# --------------------------------------------------------------------------
# Loci.conf symlink (legacy: ln -s src/conf/Loci.conf)
# --------------------------------------------------------------------------
file(REMOVE "${CMAKE_BINARY_DIR}/Loci.conf")
file(CREATE_LINK "${CMAKE_CURRENT_SOURCE_DIR}/src/conf/Loci.conf"
  "${CMAKE_BINARY_DIR}/Loci.conf" SYMBOLIC)

# --------------------------------------------------------------------------
# Symlink-copy helpers (tmpcopy's copy_with_symlinks equivalent)
# --------------------------------------------------------------------------
function(loci_symlink_file src dst)
  get_filename_component(_d "${dst}" DIRECTORY)
  file(MAKE_DIRECTORY "${_d}")
  if(IS_SYMLINK "${dst}")
    file(REMOVE "${dst}")
  endif()
  if(NOT EXISTS "${dst}")
    file(CREATE_LINK "${src}" "${dst}" SYMBOLIC)
  endif()
endfunction()

# Mirror a directory tree, symlinking files with build-relevant extensions
# (same extension set as tmpcopy's find command).
function(loci_symlink_tree src dst)
  file(GLOB_RECURSE _files LIST_DIRECTORIES false
    RELATIVE "${src}"
    CONFIGURE_DEPENDS
    "${src}/*.cc" "${src}/*.cpp" "${src}/*.c" "${src}/*.loci" "${src}/*.sh"
    "${src}/*.bash" "${src}/*.mk" "${src}/*.par" "${src}/*.h" "${src}/*.hh"
    "${src}/*.lh" "${src}/*.hpp" "${src}/*.md" "${src}/*.tex" "${src}/*.pdf"
    "${src}/*.png" "${src}/*.svg" "${src}/*.gif" "${src}/*.html"
    "${src}/*.css" "${src}/*.js" "${src}/*.xml" "${src}/*.obj"
    "${src}/*.ugrid" "${src}/*.tag" "${src}/*.sty" "${src}/*.txt"
    "${src}/*.dat" "${src}/*.vog" "${src}/*.vars" "${src}/Makefile"
    "${src}/Loci" "${src}/overset")
  foreach(_f ${_files})
    loci_symlink_file("${src}/${_f}" "${dst}/${_f}")
  endforeach()
endfunction()

# --------------------------------------------------------------------------
# include/ tree: all of src/include + generated Config/ headers
# --------------------------------------------------------------------------
file(GLOB _inc_entries LIST_DIRECTORIES true
  CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/include/*")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/include/Config")
foreach(_e ${_inc_entries})
  get_filename_component(_n "${_e}" NAME)
  if(IS_DIRECTORY "${_e}")
    file(GLOB_RECURSE _subfiles LIST_DIRECTORIES false
      CONFIGURE_DEPENDS "${_e}/*")
    foreach(_f ${_subfiles})
      file(RELATIVE_PATH _rel "${CMAKE_CURRENT_SOURCE_DIR}/src/include" "${_f}")
      loci_symlink_file("${_f}" "${CMAKE_BINARY_DIR}/include/${_rel}")
    endforeach()
  else()
    loci_symlink_file("${_e}" "${CMAKE_BINARY_DIR}/include/${_n}")
  endif()
endforeach()

# Generated headers (src/Makefile: include/Config/version_{info,details}.h)
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/include/Config/version_info.h"
  CONTENT
"#ifndef CONFIG_LOCI_INFO_H
#define CONFIG_LOCI_INFO_H
#define LOCI_VERSION_MAJOR ${LOCI_VERSION_MAJOR}
#define LOCI_VERSION_MINOR ${LOCI_VERSION_MINOR}
#endif
")
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/include/Config/version_details.h"
  CONTENT
"#ifndef CONFIG_LOCI_DETAILS_H
#define CONFIG_LOCI_DETAILS_H
#define LOCI_VERSION \"${LOCI_GIT_INFO}\"
#define LOCI_BRANCH \"${LOCI_GIT_BRANCH}\"
#endif
")

# --------------------------------------------------------------------------
# bin/ helpers: mpinorun (serial MPI launcher used by sys.conf MPI_RUN) and
# extract_movie (shell script installed into bin)
# --------------------------------------------------------------------------
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/bin" "${CMAKE_BINARY_DIR}/lib")
foreach(_script mpinorun extract_movie)
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/FVMtools/${_script}")
    loci_symlink_file("${CMAKE_CURRENT_SOURCE_DIR}/src/FVMtools/${_script}"
      "${CMAKE_BINARY_DIR}/bin/${_script}")
  endif()
endforeach()

# --------------------------------------------------------------------------
# quickTest/ and docs/ trees (test suites + documentation build)
# --------------------------------------------------------------------------
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/quickTest")
  loci_symlink_tree("${CMAKE_CURRENT_SOURCE_DIR}/quickTest"
    "${CMAKE_BINARY_DIR}/quickTest")
  if(LOCI_QUICKTEST AND NOT EXISTS "${CMAKE_BINARY_DIR}/quickTest/test.conf")
    configure_file("${CMAKE_CURRENT_SOURCE_DIR}/quickTest/test.conf"
      "${CMAKE_BINARY_DIR}/quickTest/test.conf" COPYONLY)
  endif()
endif()
loci_symlink_tree("${CMAKE_CURRENT_SOURCE_DIR}/docs"
  "${CMAKE_BINARY_DIR}/docs")
