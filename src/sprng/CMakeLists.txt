# libsprng -- vendored FSU parallel random number generator
# (legacy src/sprng/Makefile; note pmlcg is intentionally excluded upstream)
set(LOCI_SPRNG_OBJS
  primes_32 primes_64 fwrap_mpi cputime makeseed store simple_mpi memory
  communicate checkid sprng cmrg lcg lcg64 lfg mlfg)

set(LOCI_SPRNG_SOURCES)
foreach(_o ${LOCI_SPRNG_OBJS})
  file(GLOB _f CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${_o}.c")
  list(APPEND LOCI_SPRNG_SOURCES ${_f})
endforeach()

add_library(sprng SHARED ${LOCI_SPRNG_SOURCES})
set_target_properties(sprng PROPERTIES OUTPUT_NAME sprng)
# legacy: COPT = CC_OPT1 (lower optimization), -DSPRNG_MPI -DAdd_
target_compile_options(sprng PRIVATE ${LOCI_OPTLESS_FLAGS})
target_compile_definitions(sprng PRIVATE SPRNG_MPI Add_)
target_link_libraries(sprng PRIVATE loci_defs)
target_include_directories(sprng PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
install(TARGETS sprng LIBRARY DESTINATION lib COMPONENT runtime
  PERMISSIONS ${LOCIO_DIR_PERMS} ${LOCIO_EXE_PERMS})

add_library(sprng_static STATIC ${LOCI_SPRNG_SOURCES})
target_compile_options(sprng_static PRIVATE ${LOCI_OPTLESS_FLAGS})
target_compile_definitions(sprng_static PRIVATE SPRNG_MPI Add_)
target_link_libraries(sprng_static PRIVATE loci_defs)
target_include_directories(sprng_static PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
set_target_properties(sprng_static PROPERTIES OUTPUT_NAME sprng
  EXCLUDE_FROM_ALL TRUE)
