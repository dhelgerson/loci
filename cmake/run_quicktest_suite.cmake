# run_quicktest_suite.cmake -- run one quickTest suite through the unmodified
# GNU-make suite Makefile and fail if any case FAILED (mirrors the top-level
# quickTest/Makefile TestResults summary semantics).
#
#   cmake -DSUITE=<name> -DBASE=<build dir> -DGNU_MAKE=<make> -P this

execute_process(
  COMMAND ${GNU_MAKE} -C ${BASE}/quickTest ${SUITE}
          LOCI_BASE=${BASE} TEST_BASE=${BASE}/quickTest
  RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)

set(_res ${BASE}/quickTest/${SUITE}/TestResults)
set(_fail FALSE)
if(NOT _rc EQUAL 0)
  set(_fail TRUE)
endif()
if(EXISTS "${_res}")
  file(READ "${_res}" _content)
  message(STATUS "${SUITE} results:\n${_content}")
  if(_content MATCHES "FAIL")
    set(_fail TRUE)
  endif()
else()
  message(STATUS "no TestResults file produced for ${SUITE}")
  set(_fail TRUE)
endif()
message(STATUS "${_out}")
if(_rc EQUAL 0)
  # make tolerates suite failures; the summary check above decides
  set(_fail ${_fail})
endif()
if(_fail)
  message(FATAL_ERROR "quickTest suite ${SUITE} FAILED\n${_err}")
endif()
