# MakeTarball.cmake -- replicate the legacy 'make tarball' target
# (toplevel.mk): git archive with a stamped src/version.conf overlay.
#   cmake -DSRC=<srcdir> -DREV=<branch-info> -DGIT_INFO=... -DGIT_BRANCH=...
#         -DGIT_EXECUTABLE=<git> -P this

execute_process(
  COMMAND ${CMAKE_COMMAND} -E cat "${SRC}/src/conf/version.conf"
  OUTPUT_VARIABLE _vconf OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REGEX REPLACE "(^|\n)GIT_INFO[^\n]*" "\\1GIT_INFO = ${GIT_INFO}"
  _vconf "${_vconf}")
string(REGEX REPLACE "(^|\n)GIT_BRANCH[^\n]*" "\\1GIT_BRANCH = ${GIT_BRANCH}"
  _vconf "${_vconf}")

execute_process(
  COMMAND ${GIT_EXECUTABLE} archive --format=tgz
          --prefix=Loci-${REV}/
          --add-virtual-file=Loci-${REV}/src/version.conf:${_vconf}
          -o Loci-${REV}.tgz HEAD
  WORKING_DIRECTORY ${SRC}
  RESULT_VARIABLE _rc)
if(NOT _rc EQUAL 0)
  message(FATAL_ERROR "git archive failed (${_rc}); 'tarball' requires a "
    "git checkout (same as the legacy target)")
endif()
message(STATUS "Wrote ${SRC}/Loci-${REV}.tgz")
