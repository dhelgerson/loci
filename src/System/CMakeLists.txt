# libLoci -- the core framework library (legacy src/System/Makefile).
set(LOCI_SYSTEM_OBJS
  Initialize Loci_Datatypes store_rep Map constraint DMap DMultiMap rule
  fact_db execute depend_graph2 scheduler sched_tools sched_mlg sched_types
  sched_decompose sched_comp comp_impl comp_reduce comp_recurse comp_internal
  comp_dag comp_cond comp_loop comp_chomp comp_tools distribute categories
  comp_constraint comp_map param_rule sched_db hdf5_readwrite mod_db
  visit_assemble visit_deco visit_tools visit_viz visit_chomp dynamic_exec
  multiStoreIO mpi_containerIO dist_tools distribute_io distribute_container
  dist_internal FVMGridReader FVMGridWriter FVMStuff kd_tree pnn orb
  interpolate_tools thread gpusupport docreport)

set(LOCI_SYSTEM_SOURCES)
foreach(_o ${LOCI_SYSTEM_OBJS})
  file(GLOB _f CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/${_o}.cc"
    "${CMAKE_CURRENT_SOURCE_DIR}/${_o}.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/${_o}.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/${_o}.C")
  list(SORT _f)
  list(GET _f 0 _first)
  list(APPEND LOCI_SYSTEM_SOURCES "${_first}")
endforeach()

# Loci_version.cc is compiled separately and appended in the legacy link line
list(APPEND LOCI_SYSTEM_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/Loci_version.cc)

add_library(Loci SHARED ${LOCI_SYSTEM_SOURCES})
add_library(Loci::Loci ALIAS Loci)
set_target_properties(Loci PROPERTIES OUTPUT_NAME Loci)
# legacy link: objects + $(BASE_LIBS) only (no -lTools/-lsprng)
target_link_libraries(Loci PRIVATE loci_opt)
target_include_directories(Loci PRIVATE "${CMAKE_SOURCE_DIR}/src/sprng/include")
target_compile_definitions(Loci PRIVATE
  "LOCI_RPATH=\"${LOCI_RPATH}\"")
install(TARGETS Loci LIBRARY DESTINATION lib COMPONENT runtime
  PERMISSIONS ${LOCIO_DIR_PERMS} ${LOCIO_EXE_PERMS})
