# FVMAdapt: mesh adaptation module + support library
# (legacy src/FVMAdapt/Makefile)
#
# INCLUDES = -I$(LOCI_BASE)/include/FVMAdapt $(LIBXML2_INCLUDE)
#            $(LIBXML2_DEFINE)
set(LOCI_ADAPT_INCLUDES "-I${CMAKE_BINARY_DIR}/include/FVMAdapt")
if(LOCI_LIBXML2_INCLUDE)
  list(APPEND LOCI_ADAPT_INCLUDES "${LOCI_LIBXML2_INCLUDE}")
endif()
set(LOCI_TARGET_LPP_INCLUDES "-I${CMAKE_CURRENT_SOURCE_DIR};${LOCI_ADAPT_INCLUDES}")

loci_glob_sources(LOCI_ADAPT_MODULE)
loci_glob_sources(LOCI_ADAPT_LIB "${CMAKE_CURRENT_SOURCE_DIR}/library")

loci_prepare_sources(LOCI_ADAPT_MODULE_SRCS ${LOCI_ADAPT_MODULE})
loci_prepare_sources(LOCI_ADAPT_LIB_SRCS ${LOCI_ADAPT_LIB})

# fvmadapt_m.so (module, links LIBXML2_LIBS) and libfvmadaptfunc.so
loci_add_module_flavors(NAME fvmadapt
  TARGETS fvmadapt_m
  OUT_NAMES fvmadapt_m
  EXTRA_DEFS ${LOCI_LIBXML2_DEFINE}
  SOURCES ${LOCI_ADAPT_MODULE_SRCS})
target_include_directories(fvmadapt_m PRIVATE
  "${CMAKE_BINARY_DIR}/include/FVMAdapt"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${LOCI_XML2_INCDIR}")
if(LOCI_LIBXML2_LIBS)
  target_link_libraries(fvmadapt_m PRIVATE ${LOCI_XML2_LINK})
endif()

add_library(fvmadaptfunc SHARED ${LOCI_ADAPT_LIB_SRCS})
target_compile_definitions(fvmadaptfunc PRIVATE ${LOCI_LIBXML2_DEFINE})
target_compile_options(fvmadaptfunc PRIVATE ${LOCI_DEBUG_FLAGS}
  ${LOCI_OPT_FLAGS})
target_include_directories(fvmadaptfunc PRIVATE
  "${CMAKE_BINARY_DIR}/include/FVMAdapt"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${LOCI_XML2_INCDIR}")
target_link_libraries(fvmadaptfunc PRIVATE loci_defs loci_deps)
set_target_properties(fvmadaptfunc PROPERTIES OUTPUT_NAME fvmadaptfunc)
install(TARGETS fvmadaptfunc LIBRARY DESTINATION lib COMPONENT runtime
  PERMISSIONS ${LOCIO_DIR_PERMS} ${LOCIO_EXE_PERMS})
