# 2dgv: standalone X11/PostScript viewer for Loci grids (legacy 2dgv/Makefile
# and Imakefile; never part of the top-level default build -- enable with
# LOCI_BUILD_2dGV=ON)
find_package(X11 REQUIRED COMPONENTS Xt Xaw)

loci_glob_sources(LOCI_2dGV_SRCS)

add_executable(2dgv ${LOCI_2dGV_SRCS})
target_compile_options(2dgv PRIVATE -O1)
target_include_directories(2dgv PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}
  ${X11_INCLUDE_DIR})
target_link_libraries(2dgv PRIVATE m
  ${X11_Xt_LIB} ${X11_Xaw_LIB} ${X11_X11_LIB})
set_target_properties(2dgv PROPERTIES RUNTIME_OUTPUT_DIRECTORY
  "${CMAKE_BINARY_DIR}/bin")
install(TARGETS 2dgv RUNTIME DESTINATION bin COMPONENT runtime
  PERMISSIONS ${LOCIO_DIR_PERMS} ${LOCIO_EXE_PERMS})
