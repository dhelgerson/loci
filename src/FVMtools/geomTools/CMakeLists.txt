# geomTools utilities (legacy src/FVMtools/geomTools/Makefile; NOT part of
# the default legacy build -- enable with LOCI_BUILD_GEOMTOOLS=ON)
# geomTools Makefile: INCLUDES = -I$(LOCI_BASE)/include -DUSE_LOCI_TYPES
set(LOCI_TARGET_LPP_INCLUDES "-DUSE_LOCI_TYPES")

function(geom_tool name)
  cmake_parse_arguments(T "NO_LIBS" "" "SOURCES" ${ARGN})
  loci_prepare_sources(_srcs ${T_SOURCES})
  add_executable(${name} ${_srcs})
  target_compile_options(${name} PRIVATE
    ${LOCI_DEBUG_FLAGS} ${LOCI_OPTLESS_FLAGS})
  target_compile_definitions(${name} PRIVATE USE_LOCI_TYPES)
  if(NOT T_NO_LIBS)
    target_link_libraries(${name} PRIVATE
      loci_defs Loci Tools loci_deps m sprng loci_exe_link)
  endif()
  install(TARGETS ${name} RUNTIME DESTINATION bin COMPONENT runtime
    PERMISSIONS ${LOCIO_DIR_PERMS} ${LOCIO_EXE_PERMS})
endfunction()

geom_tool(computegeom SOURCES compute_geom.cc svdcmp.cc)
geom_tool(adjustpos SOURCES
  adjust_pos.cc surface_delta.cc mesh_deform.cc approx.loci nodeData.loci
  constraints.loci idw.loci rotor.cc treeApprox.cc geomRep.cc)
geom_tool(getgeom NO_LIBS SOURCES get_geom.cc)
geom_tool(viscousFix SOURCES viscousFix.cc)
