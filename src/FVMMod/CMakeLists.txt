# loci_add_module_flavors(NAME <mod> TARGETS <t1> <t2> <t3>
#                         OUT_NAMES <n1> <n2> <n3> SOURCES <...>)
#
# Builds a loadable Loci module in the three legacy flavors: plain, FAD
# (forward autodiff) and VFAD (vector autodiff) -- same objects compiled
# with -DUSE_AUTODIFF [-DUSEVFAD] -DAUTODIFF_MODULE, linked as
# <name>_m.so / <name>FAD_m.so / <name>VFAD_m.so without libLoci (symbols
# resolve at dlopen time), matching src/conf/Loci.conf's %_lo/_FAD/_VFAD
# suffix rules.
function(loci_add_module_flavors)
  cmake_parse_arguments(MOD "" "NAME" "TARGETS;OUT_NAMES;SOURCES;EXTRA_DEFS" ${ARGN})
  list(LENGTH MOD_TARGETS _n)
  foreach(_i RANGE 0 ${_n})
    if(_i EQUAL ${_n})
      break()
    endif()
    list(GET MOD_TARGETS ${_i} _tgt)
    list(GET MOD_OUT_NAMES ${_i} _out)
    set(_fdefs ${MOD_EXTRA_DEFS})
    if(_i GREATER 0)
      list(APPEND _fdefs USE_AUTODIFF AUTODIFF_MODULE)
      if(_i EQUAL 2)
        list(APPEND _fdefs USEVFAD)
      endif()
    endif()
    add_library(${_tgt} SHARED ${MOD_SOURCES})
    target_link_libraries(${_tgt} PRIVATE loci_defs loci_deps)
    target_compile_options(${_tgt} PRIVATE ${LOCI_DEBUG_FLAGS}
      ${LOCI_OPT_FLAGS})
    target_compile_definitions(${_tgt} PRIVATE ${MOD_EXTRA_DEFS} ${_fdefs})
    set_target_properties(${_tgt} PROPERTIES
      PREFIX "" SUFFIX ".so" NO_SONAME ON
      OUTPUT_NAME ${_out}
      LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    install(TARGETS ${_tgt} LIBRARY DESTINATION lib COMPONENT runtime
      PERMISSIONS ${LOCIO_DIR_PERMS} ${LOCIO_EXE_PERMS})
  endforeach()
endfunction()

# FVMMod: physics/numerics module library (legacy src/FVMMod/Makefile).
# Sources: this directory plus limiters/ and cellgradient/ subdirectories,
# discovered by the loci_compile_files wildcard equivalent.
loci_glob_sources(LOCI_FVMMOD_BASE)
loci_glob_sources(LOCI_FVMMOD_LIMITERS "${CMAKE_CURRENT_SOURCE_DIR}/limiters")
loci_glob_sources(LOCI_FVMMOD_CELLEG "${CMAKE_CURRENT_SOURCE_DIR}/cellgradient")
loci_prepare_sources(LOCI_FVMMOD_SRCS
  ${LOCI_FVMMOD_BASE} ${LOCI_FVMMOD_LIMITERS} ${LOCI_FVMMOD_CELLEG})

loci_add_module_flavors(NAME fvm
  TARGETS fvm_m fvmFAD_m fvmVFAD_m
  OUT_NAMES fvm_m fvmFAD_m fvmVFAD_m
  SOURCES ${LOCI_FVMMOD_SRCS})
