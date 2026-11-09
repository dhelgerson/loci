# libTools -- general-purpose utility library (legacy src/Tools/Makefile)
set(LOCI_TOOLS_SOURCES
  fpe.cc ftrn_reader.cc identity.cc eventNotify.cc debugger.cc
  parse.cc options_list.cc expr.cc digraph.cc unit_type.cc
  fpe_sun.c mpi_stubb.cc intervalSet.cc variable.cc)

add_library(Tools SHARED ${LOCI_TOOLS_SOURCES})
target_link_libraries(Tools PRIVATE loci_opt)
set_target_properties(Tools PROPERTIES OUTPUT_NAME Tools)
target_include_directories(Tools PRIVATE ${CMAKE_BINARY_DIR}/include/Tools)
install(TARGETS Tools LIBRARY DESTINATION lib COMPONENT runtime
  PERMISSIONS ${LOCIO_DIR_PERMS} ${LOCIO_EXE_PERMS})

# legacy also provided 'make libTools.a' in this directory
add_library(Tools_static STATIC ${LOCI_TOOLS_SOURCES})
add_library(Loci::Tools_static ALIAS Tools_static)
target_link_libraries(Tools_static PRIVATE loci_opt)
set_target_properties(Tools_static PROPERTIES OUTPUT_NAME Tools
  EXCLUDE_FROM_ALL TRUE)
