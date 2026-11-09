# LociSources.cmake -- helpers replicating src/conf/Loci.conf build rules:
#   * loci_compile_files wildcard glob (loci_glob_sources)
#   * .loci -> .lcc~ and .cloci -> .lcu~ preprocessing via lpp, with depfiles

# Glob source files the way the loci_compile_files make function does.
function(loci_glob_sources out)
  set(_dir "${ARGN}")
  if(NOT _dir)
    set(_dir "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
  if(NOT _dir MATCHES "/$")
    string(APPEND _dir "/")
  endif()
  set(_pat)
  foreach(_e c cc cpp C loci cloci)
    file(GLOB _found LIST_DIRECTORIES false CONFIGURE_DEPENDS
      "${_dir}*.${_e}")
    list(APPEND _pat ${_found})
  endforeach()
  list(SORT _pat)
  set(${out} "${_pat}" PARENT_SCOPE)
endfunction()

# Preprocess one lpp source.  out_var receives the generated source path,
# already marked GENERATED.  ARGN are extra lpp include flags (-I...).
# Each input file is preprocessed exactly once per build.
define_property(GLOBAL PROPERTY LOCI_LPP_MAP BRIEF_DOCS "map of
  loci source -> generated output")
function(loci_lpp_source src out_var)
  get_property(_map GLOBAL PROPERTY LOCI_LPP_MAP)
  list(FIND _map "${src}" _seen)
  if(NOT _seen EQUAL -1)
    math(EXPR _oi "${_seen} + 1")
    list(GET _map ${_oi} _prev_out)
    set(${out_var} "${_prev_out}" PARENT_SCOPE)
    return()
  endif()

  get_filename_component(_abs "${src}" ABSOLUTE)
  get_filename_component(_name "${_abs}" NAME_WE)

  set(_outdir "${CMAKE_CURRENT_BINARY_DIR}/.lpp")
  file(MAKE_DIRECTORY "${_outdir}")

  if(_abs MATCHES "\\.cloci$")
    set(_out "${_outdir}/${_name}.lcu~")
    set(_xflag "")
    set(_lang CUDA)
    set(_xsuffix "cu")
  else()
    set(_out "${_outdir}/${_name}.lcc~")
    set(_xflag "-x")
    set(_lang CXX)
    set(_xsuffix "c++")
  endif()
  set(_dep "${_out}.d")

  # Pack the include flags into one -D argument (';' survives into the
  # -P script as a CMake list separator via $<SEMICOLON>).
  string(JOIN "$<SEMICOLON>" _lpp_extra "-I${CMAKE_BINARY_DIR}/include"
    ${ARGN})

  add_custom_command(OUTPUT "${_out}"
    COMMAND ${CMAKE_COMMAND}
      -DLPP=$<TARGET_FILE:lpp>
      -DLIBDIR=${CMAKE_BINARY_DIR}/lib
      -DSRC=${_abs}
      -DOUT=${_out}
      -DDEPFILE=${_dep}
      -DXFLAG=${_xflag}
      -DEXTRA_ARGS=${_lpp_extra}
      -P ${CMAKE_SOURCE_DIR}/cmake/lpp_run.cmake
    DEPENDS "${_abs}" lpp
    DEPFILE "${_dep}"
    COMMENT "lpp ${_name}"
    VERBATIM)

  set_source_files_properties("${_out}" PROPERTIES
    GENERATED TRUE
    LANGUAGE ${_lang}
    COMPILE_FLAGS "-x ${_xsuffix}")

  set(${out_var} "${_out}" PARENT_SCOPE)
  set_property(GLOBAL APPEND PROPERTY LOCI_LPP_MAP "${src}" "${_out}")
endfunction()

# Expand a list of sources: .loci/.cloci files are replaced by their
# generated preprocessed outputs; plain sources pass through.
# Uses ${LOCI_TARGET_LPP_INCLUDES} as extra lpp include flags.
function(loci_prepare_sources out)
  set(_result)
  foreach(_s ${ARGN})
    if(_s MATCHES "\\.(loci|cloci)$")
      loci_lpp_source("${_s}" _gen ${LOCI_TARGET_LPP_INCLUDES})
      list(APPEND _result "${_gen}")
    else()
      list(APPEND _result "${_s}")
    endif()
  endforeach()
  set(${out} "${_result}" PARENT_SCOPE)
endfunction()
