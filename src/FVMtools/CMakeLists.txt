# FVMtools: pre/post-processing executables (legacy src/FVMtools/Makefile).
# Every target in this directory compiles at the COPTLESS optimization tier
# (Makefile sets COPT = $(COPTLESS)); link order matches $(LIBS).

set(LOCI_TARGET_LPP_INCLUDES "-I${CMAKE_CURRENT_SOURCE_DIR}/libadf")

# libadf: vendored GRIDPro ADF reader used by ccm2vog (own Makefile builds
# libadf.a at COPTLESS with no Loci linkage)
add_library(adf STATIC
  libadf/ADF_interface.c libadf/ADF_internals.c)
set_target_properties(adf PROPERTIES OUTPUT_NAME adf EXCLUDE_FROM_ALL TRUE)
target_compile_options(adf PRIVATE ${LOCI_OPTLESS_FLAGS})
target_include_directories(adf PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/libadf)

# loci_tool(name ...): mirrors one link rule from the legacy Makefile.
#   SOURCES  .c/.cc/.loci files (resolved and lpp-preprocessed)
#   LIBS     extra libraries (defaults to the standard $(LIBS))
#   NO_LIBS  link nothing but the object files (getgeom rule)
#   NO_INSTALL  create the target but do not install it
function(loci_tool name)
  cmake_parse_arguments(T "NO_LIBS;NO_INSTALL" "" "SOURCES;LIBS" ${ARGN})
  loci_prepare_sources(_srcs ${T_SOURCES})
  add_executable(${name} ${_srcs})
  target_compile_options(${name} PRIVATE
    ${LOCI_DEBUG_FLAGS} ${LOCI_OPTLESS_FLAGS})
  target_include_directories(${name} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/libadf)
  if(NOT T_NO_LIBS)
    target_link_libraries(${name} PRIVATE
      ${T_LIBS} loci_defs Loci Tools loci_deps m sprng loci_exe_link)
  endif()
  if(NOT T_NO_INSTALL)
    install(TARGETS ${name} RUNTIME DESTINATION bin COMPONENT runtime
      PERMISSIONS ${LOCIO_DIR_PERMS} ${LOCIO_EXE_PERMS})
  endif()
endfunction()

# --- extract and the vog converters (APPS list of the legacy Makefile) ---
loci_tool(extract SOURCES
  extract.cc extract_ensight.cc extract_2dgv.cc extract_ascii.cc
  extract_tecplot.cc extract_vtk.cc extract_fv.cc extract_cut.cc
  extract_surf.cc extract_mean.cc extract_cgns.cc
  LIBS ${LOCI_TEC360_LIB})

loci_tool(plot3d2vog SOURCES plot3d2vog.cc vogtools.cc)
loci_tool(make_periodic SOURCES make_periodic.cc predicates.c vogtools.cc)
loci_tool(ugrid2vog SOURCES ugrid2vog.cc vogtools.cc)
loci_tool(msh2vog SOURCES msh2vog.cc vogtools.cc)
loci_tool(foam2vog SOURCES foam2vog.cc vogtools.cc)
loci_tool("cfd++2vog" SOURCES "cfd++2vog.cc" vogtools.cc)
loci_tool(fluent2vog SOURCES fluent2vog.cc vogtools.cc)
loci_tool(cobalt2vog SOURCES cobalt2vog.cc vogtools.cc)
loci_tool(vogmerge SOURCES vogmerge.cc)
loci_tool(vogcut SOURCES vogcut.cc vogtools.cc)
loci_tool(vogcheck SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/vogCheck.loci)
loci_tool(extruder SOURCES extruder.cc)
loci_tool(vog2surf SOURCES vog2surf.cc)
loci_tool(ccm2vog SOURCES ccm2vog.cc vogtools.cc LIBS adf)

# mesh adaptation tools, linked against libfvmadaptfunc
loci_tool(refmesh SOURCES refmesh.cc LIBS fvmadaptfunc)
loci_tool(marker SOURCES marker.cc LIBS fvmadaptfunc)
loci_tool(refine SOURCES refine.cc LIBS fvmadaptfunc)

# --- CGNS tools (built unconditionally; without CGNS they compile to the
#     same unsupported-format stubs the legacy build produced) ---
loci_tool(cgns2vog SOURCES cgns2vog.cc hash.c vogtools.cc)
loci_tool(ugrid2cgns SOURCES ugrid2cgns.cc hash.c binaryio.c getargs.c)
loci_tool(cgns2ugrid SOURCES cgns2ugrid.c hash.c binaryio.c getargs.c)
loci_tool(cgns2ensight SOURCES cgns2ensight.cc)
loci_tool(cgns2surf SOURCES cgns2surf.cc hash.c)

# ugridmirror has a legacy make rule but is not in APPS/install; keep the
# same on-demand-only behavior
add_executable(ugridmirror ugridmirror.cc vogtools.cc)
target_compile_options(ugridmirror PRIVATE
  ${LOCI_DEBUG_FLAGS} ${LOCI_OPTLESS_FLAGS})
target_link_libraries(ugridmirror PRIVATE
  loci_defs Loci Tools loci_deps m sprng loci_exe_link)
set_target_properties(ugridmirror PROPERTIES EXCLUDE_FROM_ALL TRUE)

# extract_movie is a shell script installed into bin (not compiled)
install(PROGRAMS ${CMAKE_CURRENT_SOURCE_DIR}/extract_movie
  DESTINATION bin COMPONENT runtime PERMISSIONS ${LOCIO_EXE_PERMS})

# In --nompi builds the installed sys.conf sets MPI_RUN=$(LOCI_BASE)/bin/mpinorun
# but the legacy Install.bash never copied it; the CMake build installs it so
# that the serial launcher actually exists.
if(NOT LOCI_MPI)
  install(PROGRAMS ${CMAKE_CURRENT_SOURCE_DIR}/mpinorun
    DESTINATION bin COMPONENT runtime PERMISSIONS ${LOCIO_EXE_PERMS})
endif()

if(LOCI_BUILD_GEOMTOOLS)
  add_subdirectory(geomTools)
endif()
