# LociCompilerConfig.cmake
#
# Mirrors the compiler semantics of the legacy src/conf/<name>.conf files
# (gcc.conf, llvm.conf, icc.conf) so a CMake build produces objects compiled
# with the same flags/defines the legacy GNU make build used.
#
# Sets:
#   LOCI_SYS_TYPE, LOCI_ARCH_TYPE      uname-derived tokens (spaces/dots -> _)
#   LOCI_COMPILER                      gcc | llvm | icc (name of legacy conf)
#   COMP_NAME                          compiler token baked into install dir name
#   LOCI_DEBUG_FLAGS, LOCI_DEBUG_DEFINES   from LOCI_DEBUG environment variable
#   LOCI_BOUNDS_DEFINES                from LOCI_BOUNDS_CHECK
#   LOCI_MISC                          -DARCH_LINUX / -DARCH_MACOS
#   LOCI_OPT_FLAGS / LOCI_OPTLESS_FLAGS    C++ optimization flag tiers
#                                          (CC_OPT vs CC_OPT1/COPTLESS)
#   LOCI_C_OPT_FLAGS                   C file flags (C_OPT)
#   LOCI_RPATH_FLAG                    -Wl,-rpath, style flag

# ---------------------------------------------------------------------------
# Platform tokens (Loci.conf: SYS_TYPE/ARCH_TYPE from uname)
# ---------------------------------------------------------------------------
string(REGEX REPLACE "[ .-]" "_" LOCI_SYS_TYPE "${CMAKE_SYSTEM_NAME}")
string(REGEX REPLACE "[ .-]" "_" LOCI_ARCH_TYPE "${CMAKE_SYSTEM_PROCESSOR}")

# ---------------------------------------------------------------------------
# Which legacy compiler profile to mirror/use
# ---------------------------------------------------------------------------
if(NOT LOCI_COMPILER)
  if(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
    set(LOCI_COMPILER gcc)
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(LOCI_COMPILER llvm)
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "Intel")
    set(LOCI_COMPILER icc)
  else()
    set(LOCI_COMPILER gcc)
    message(WARNING
      "Unrecognized C++ compiler '${CMAKE_CXX_COMPILER_ID}', using the gcc "
      "flag profile (src/conf/gcc.conf) as the closest match. Override with "
      "-DLOCI_COMPILER=<gcc|llvm|icc>.")
  endif()
endif()
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/conf/${LOCI_COMPILER}.conf")
  message(FATAL_ERROR "LOCI_COMPILER='${LOCI_COMPILER}' has no profile "
    "src/conf/${LOCI_COMPILER}.conf")
endif()
message(STATUS "Loci: using compiler profile '${LOCI_COMPILER}' "
  "(src/conf/${LOCI_COMPILER}.conf)")

# COMP_NAME: legacy computes it in comp.conf as the first token of $(CXX)
# after removing the path; with MPI drivers CXX is 'mpicxx -std=c++17'.
if(LOCI_MPI_CXX_COMPILER_TOKEN)
  get_filename_component(COMP_NAME "${LOCI_MPI_CXX_COMPILER_TOKEN}" NAME)
else()
  get_filename_component(COMP_NAME "${CMAKE_CXX_COMPILER}" NAME)
endif()

# ---------------------------------------------------------------------------
# BOUNDS_CHECK (legacy: --bounds-check -> BOUNDS_CHECK=1 in sys.conf)
# ---------------------------------------------------------------------------
if(LOCI_BOUNDS_CHECK)
  if(LOCI_COMPILER STREQUAL "llvm")
    set(LOCI_BOUNDS_DEFINES
      -DBOUNDS_CHECK
      -D_LIBCPP_ENABLE_DEBUG_MODE=1
      -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_DEBUG)
  else()
    set(LOCI_BOUNDS_DEFINES -DBOUNDS_CHECK -D_GLIBCXX_ASSERTIONS)
  endif()
else()
  set(LOCI_BOUNDS_DEFINES)
endif()

# ---------------------------------------------------------------------------
# LOCI_DEBUG environment variable semantics (from src/conf/*.conf):
# when set, add debug flags, define DEBUG and downgrade optimization:
#   0 -> -O0, 1 -> -O1, 2 -> -O2, otherwise keep -O3
# ---------------------------------------------------------------------------
set(LOCI_OPT_LEVEL 3)
if(DEFINED ENV{LOCI_DEBUG})
  set(LOCI_DEBUG_FLAGS -Wall -g3 -ggdb)
  if(LOCI_COMPILER STREQUAL "gcc")
    list(APPEND LOCI_DEBUG_FLAGS -fno-eliminate-unused-debug-symbols)
  endif()
  set(LOCI_DEBUG_DEFINES -DDEBUG)
  if("$ENV{LOCI_DEBUG}" STREQUAL "0")
    set(LOCI_OPT_LEVEL 0)
  elseif("$ENV{LOCI_DEBUG}" STREQUAL "1")
    set(LOCI_OPT_LEVEL 1)
  elseif("$ENV{LOCI_DEBUG}" STREQUAL "2")
    set(LOCI_OPT_LEVEL 2)
  endif()
  message(STATUS "Loci: configuring in DEBUG mode = $ENV{LOCI_DEBUG}")
else()
  set(LOCI_DEBUG_FLAGS -Wall)
  set(LOCI_DEBUG_DEFINES)
endif()
if(LOCI_COMPILER STREQUAL "llvm" AND APPLE)
  # llvm.conf: Darwin adds these to the base DEBUG flags
  list(APPEND LOCI_DEBUG_FLAGS
    -Wno-unused-function -Wno-unused-variable -Wno-type-safety)
endif()

# ---------------------------------------------------------------------------
# Architecture/optimization flag sets
# ---------------------------------------------------------------------------
set(_loci_math_flags -fno-math-errno -fno-trapping-math -fstrict-aliasing
  -fomit-frame-pointer)
if(LOCI_COMPILER STREQUAL "llvm")
  list(APPEND _loci_math_flags -ffinite-math-only)
elseif(NOT APPLE)
  list(APPEND _loci_math_flags -fno-signaling-nans)
endif()

list(JOIN _loci_math_flags " " _loci_arch_flags_str)
if(LOCI_COMPILER STREQUAL "gcc" AND LOCI_NATIVE)
  set(_loci_native " -march=native")
else()
  set(_loci_native "")
endif()

if(LOCI_OPT_LEVEL EQUAL 0)
  set(_loci_Ox "-O0")
elseif(LOCI_OPT_LEVEL EQUAL 1)
  set(_loci_Ox "-O1")
elseif(LOCI_OPT_LEVEL EQUAL 2)
  set(_loci_Ox "-O2")
else()
  set(_loci_Ox "-O3")
endif()

if(LOCI_COMPILER STREQUAL "icc")
  # icc.conf equivalents
  set(LOCI_OPT_FLAGS
    "${_loci_Ox} -restrict -no-prec-div -inline-factor=150 "
    "-diag-disable cpu-dispatch -ansi_alias -ip")
  separate_arguments(LOCI_OPT_FLAGS UNIX_COMMAND "${LOCI_OPT_FLAGS}")
  set(LOCI_OPTLESS_FLAGS -O1 -ansi_alias -fp-model precise)
  set(LOCI_C_OPT_FLAGS ${LOCI_OPT_FLAGS})
else()
  string(STRIP "${_loci_Ox} ${_loci_arch_flags_str}${_loci_native}"
    _loci_opt_str)
  separate_arguments(LOCI_OPT_FLAGS UNIX_COMMAND "${_loci_opt_str}")
  if(LOCI_OPT_LEVEL EQUAL 0)
    set(_loci_optl "-O0")
  else()
    set(_loci_optl "-O1")  # OPTL = OPT1 in the legacy conf files
  endif()
  string(STRIP "${_loci_optl}${_loci_native}" _loci_optless_str)
  separate_arguments(LOCI_OPTLESS_FLAGS UNIX_COMMAND "${_loci_optless_str}")
  set(LOCI_C_OPT_FLAGS "${_loci_Ox}")
  separate_arguments(LOCI_C_OPT_FLAGS UNIX_COMMAND "${LOCI_C_OPT_FLAGS}")
endif()

# ---------------------------------------------------------------------------
# ARCH define (configure: MISC=-DARCH_LINUX / -DARCH_MACOS)
# ---------------------------------------------------------------------------
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(LOCI_MISC -DARCH_LINUX)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(LOCI_MISC -DARCH_MACOS)
else()
  set(LOCI_MISC)
endif()

set(LOCI_RPATH_FLAG "-Wl,-rpath,")
if(CMAKE_SYSTEM_NAME STREQUAL "SunOS" AND LOCI_COMPILER STREQUAL "llvm")
  set(LOCI_RPATH_FLAG "-L")
endif()
