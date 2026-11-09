# lpp_run.cmake -- run the Loci preprocessor on one .loci/.cloci file and
# emit a dependency file from the trailing "//DEPEND:" comment lpp appends
# (same mechanism as the legacy %.d: %.lcc~ rule in src/conf/Loci.conf).
#
# Usage:
#   cmake -DLPP=<exe> -DLIBDIR=<loci lib dir> -DSRC=<file> -DOUT=<file>
#         -DDEPFILE=<file> [-DXFLAG=-x] [-I ...extra includes...]
#         -P lpp_run.cmake

cmake_minimum_required(VERSION 3.20)
cmake_policy(SET CMP0007 NEW)

set(_env "$ENV{LD_LIBRARY_PATH}")
set(ENV{LD_LIBRARY_PATH} "${LIBDIR}:${_env}")
set(ENV{DYLD_LIBRARY_PATH} "${LIBDIR}:$ENV{DYLD_LIBRARY_PATH}")

set(_cmd "${LPP}")
if(XFLAG)
  list(APPEND _cmd "${XFLAG}")
endif()
list(APPEND _cmd ${EXTRA_ARGS} "${SRC}" -o "${OUT}")

execute_process(COMMAND ${_cmd} RESULT_VARIABLE _rc)
if(NOT _rc EQUAL 0)
  message(FATAL_ERROR "lpp failed (exit ${_rc}) on ${SRC}")
endif()

# Extract the DEPEND line appended by lpp, if any.
file(READ "${OUT}" _content)
string(REGEX MATCHALL "[^\n]+" _lines "${_content}")
list(GET _lines -1 _last)
set(_deps "")
if(_last MATCHES "//DEPEND: (.*)")
  set(_deps "${CMAKE_MATCH_1}")
  string(STRIP "${_deps}" _deps)
  string(REGEX REPLACE "[ \t]+" " " _deps "${_deps}")
  string(REPLACE " " ";" _deps "${_deps}")
endif()

# Depfile: targets must use the same spelling CMake uses for the output.
file(TO_NATIVE_PATH "${OUT}" _out_native)
set(_depcontent "${_out_native}:")
foreach(_d ${_deps})
  if(IS_ABSOLUTE "${_d}")
    set(_dd "${_d}")
  else()
    get_filename_component(_srcdir "${SRC}" DIRECTORY)
    set(_dd "${_srcdir}/${_d}")
  endif()
  string(APPEND _depcontent " ${_dd}")
endforeach()
string(APPEND _depcontent "\n")
file(WRITE "${DEPFILE}" "${_depcontent}")
