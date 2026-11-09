###############################################################################
# Loci -- CMake build
#
# Replaces the legacy ./configure + GNU make build.  The binary directory is
# laid out like the legacy OBJ directory (Loci.conf/sys.conf/comp.conf/
# version.conf + include/ lib/ bin/ quickTest/ docs/) so the unmodified
# quickTest suites and external Loci application Makefiles work unchanged.
#
# Key options (see README section "Building with CMake"):
#   LOCI_MPI=ON/OFF            OFF == --nompi (MPI stub layer, serial HDF5)
#   LOCI_MPI_DRIVER=ON         use mpicc/mpicxx drivers (--no-mpi-driver)
#   LOCI_BOUNDS_CHECK=OFF      --bounds-check
#   LOCI_PTHREADS=OFF          --with-pthreads
#   LOCI_NO_SUB_DIR=OFF        --no-sub-dir (install directly into prefix)
#   LOCI_NO_METIS=OFF          --no-metis
#   LOCI_COMPILER=""           force legacy profile: gcc | llvm | icc
#   LOCI_HDF5_DIR, LOCI_MPI_DIR, LOCI_CGNS_DIR, LOCI_PETSC_DIR,
#   LOCI_METIS_DIR, LOCI_PARMETIS_DIR, LOCI_SCOCH_DIR, LOCI_TEC360_DIR,
#   LOCI_TECIO_DIR, LOCI_CUDA_DIR      dependency locations
###############################################################################
cmake_minimum_required(VERSION 3.20)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Version from `git describe` before project() so project VERSION can use it
find_package(Git QUIET)
set(LOCI_GIT_INFO "unknown-version")
if(GIT_FOUND AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
  execute_process(COMMAND ${GIT_EXECUTABLE} describe --abbrev=6 --always
    --dirty --tags
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    OUTPUT_VARIABLE LOCI_GIT_INFO OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
endif()
set(_loci_projver "0.0.0")
if(LOCI_GIT_INFO MATCHES "^v([0-9]+)\\.([0-9]+)")
  set(_loci_projver "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.0")
endif()

project(Loci VERSION ${_loci_projver} LANGUAGES C CXX)

# ---------------------------------------------------------------------------
# Options mirroring ./configure
# ---------------------------------------------------------------------------
option(LOCI_MPI "Build with MPI (uncheck for the serial stub build, = --nompi)" ON)
option(LOCI_MPI_DRIVER "Compile through mpicc/mpicxx driver binaries" ON)
option(LOCI_PTHREADS "Enable POSIX threads (= --with-pthreads)" OFF)
option(LOCI_BOUNDS_CHECK "Array bounds checking (= --bounds-check)" OFF)
option(LOCI_NATIVE "Pass -march=native to gcc-family compilers" ON)
option(LOCI_NO_SUB_DIR "Install directly into prefix (no versioned subdir)" OFF)
option(LOCI_NO_METIS "Disable graph partitioners (= --no-metis)" OFF)
option(LOCI_CUDA "Enable CUDA runtime support (= --with-cuda)" OFF)
option(LOCI_QUICKTEST "Register quickTest suites with CTest" ON)
option(LOCI_BUILD_2dGV "Build the standalone 2dgv X11 viewer" OFF)
option(LOCI_BUILD_GEOMTOOLS "Build the geomTools utilities (not in the default legacy build)" OFF)

foreach(_d MPI HDF5 CGNS PETSC METIS PARMETIS SCOTCH TEC360 TECIO CUDA)
  set(LOCI_${_d}_DIR "" CACHE PATH "Location of the ${_d} package")
endforeach()
set(LOCI_COMPILER "" CACHE STRING
  "Legacy compiler profile to mirror: gcc, llvm or icc (default: auto)")

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  # Loci carries its own optimization flags (legacy COPT/CC_OPT semantics);
  # do not let build-type flags stack on top of them.
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "" FORCE)
  set(CMAKE_C_FLAGS_RELEASE "" CACHE STRING "" FORCE)
  set(CMAKE_CXX_FLAGS_RELEASE "" CACHE STRING "" FORCE)
endif()

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)          # all conf files: g++ -std=c++17
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_SKIP_BUILD_RPATH FALSE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

include(LociCompilerConfig)
include(LociDeps)
include(LociSysConf)
include(LociSources)

# ---------------------------------------------------------------------------
# Flag/define interfaces equivalent to the Loci.conf suffix rules.
#   loci_defs     DEFINES + LOCI_INCLUDES + MACHINE_SPECIFIC equivalents
#   loci_deps     BASE_LIBS equivalents
#   loci_opt      + CC_OPT   tier (default COPT)
#   loci_opt_less + CC_OPT1  tier (COPTLESS: FVMtools, sprng, libadf)
# ---------------------------------------------------------------------------
add_library(loci_defs INTERFACE)
target_compile_definitions(loci_defs INTERFACE
  LOCI_SYS_${LOCI_SYS_TYPE}
  LOCI_ARCH_${LOCI_ARCH_TYPE}
  "LOCI_RPATH=\"${LOCI_RPATH}\""
  ${LOCI_MISC}
  ${LOCI_BOUNDS_DEFINES}
  ${LOCI_PTHREADS_DEFINE}
  ${LOCI_PETSC_DEFS}
  ${LOCI_CGNS_DEFS}
  ${LOCI_METIS_DEFS}
  ${LOCI_TEC360_DEFS}
  ${LOCI_CUDA_DEFS}
)
target_include_directories(loci_defs INTERFACE
  "${CMAKE_BINARY_DIR}/include"                       # LOCI_INCLUDES
  "${CMAKE_SOURCE_DIR}/src/sprng/include"
  "${LOCI_HDF5_INCLUDE_DIR}"
  "${LOCI_PETSC_INCDIR}"
  "${LOCI_METIS_INCDIR}"
  "${LOCI_CGNS_INCDIR}"
  "${LOCI_TEC360_INCDIR}"
  "${LOCI_CUDA_INCDIR}"
)
if(LOCI_MPI)
  target_link_libraries(loci_defs INTERFACE MPI::MPI_CXX)
else()
  # legacy: MPI_INCLUDE = -DMPI_STUBB -I$(LOCI_BASE)/include/MPI_stubb
  target_compile_definitions(loci_defs INTERFACE MPI_STUBB)
  target_include_directories(loci_defs INTERFACE
    "${CMAKE_BINARY_DIR}/include/MPI_stubb")
endif()

add_library(loci_deps INTERFACE)
target_link_libraries(loci_deps INTERFACE
  ${LOCI_HDF5_LIBS}
  ${LOCI_PETSC_LINK}
  ${LOCI_METIS_LIBS}
  ${LOCI_CGNS_LINK}
  ${LOCI_FORTRAN_LIBS}
  ${CMAKE_DL_LIBS}          # DYNAMIC_LOADING_LINK
  ${LOCI_PTHREADS_LIB}
)

add_library(loci_opt INTERFACE)
target_link_libraries(loci_opt INTERFACE loci_defs loci_deps)
target_compile_options(loci_opt INTERFACE
  ${LOCI_DEBUG_FLAGS}
  "$<$<COMPILE_LANGUAGE:C>:${LOCI_C_OPT_FLAGS}>"
  "$<$<COMPILE_LANGUAGE:CXX>:${LOCI_OPT_FLAGS}>")

add_library(loci_opt_less INTERFACE)
target_link_libraries(loci_opt_less INTERFACE loci_defs loci_deps)
target_compile_options(loci_opt_less INTERFACE
  ${LOCI_DEBUG_FLAGS}
  "$<$<COMPILE_LANGUAGE:C>:${LOCI_OPTLESS_FLAGS}>"
  "$<$<COMPILE_LANGUAGE:CXX>:${LOCI_OPTLESS_FLAGS}>")

# executables: LDFLAGS = -rdynamic $(CC_OPTIMIZE)
add_library(loci_exe_link INTERFACE)
target_link_options(loci_exe_link INTERFACE -rdynamic)

set(CMAKE_BUILD_RPATH "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_INSTALL_RPATH "${LOCI_RPATH}")

# install(FILES) permission model matching Install.bash's `chmod -R a+rX`
set(LOCIO_FILE_PERMS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
set(LOCIO_EXE_PERMS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ
  GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
set(LOCIO_DIR_PERMS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ
  GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

# ---------------------------------------------------------------------------
# Subdirectories (lpp must be defined before any .loci consumers)
# ---------------------------------------------------------------------------
add_subdirectory(src/Tools)
add_subdirectory(src/lpp)
add_subdirectory(src/System)
add_subdirectory(src/sprng)
add_subdirectory(src/FVMMod)
add_subdirectory(src/FVMAdapt)
add_subdirectory(src/FVMOverset)
add_subdirectory(src/FVMtools)
if(LOCI_BUILD_2dGV)
  add_subdirectory(2dgv)
endif()

# ---------------------------------------------------------------------------
# Testing: drive the unmodified quickTest GNU-make suites via CTest
# ---------------------------------------------------------------------------
find_program(GNU_MAKE_EXECUTABLE make)
if(LOCI_QUICKTEST AND GNU_MAKE_EXECUTABLE)
  enable_testing()
  set(_loci_suites Containers Tools FVMModUnitTests FVM SystemTests
    FVMAdaptTest)
  set(_loci_test_env
    "LD_LIBRARY_PATH=${CMAKE_BINARY_DIR}/lib:$ENV{LD_LIBRARY_PATH}"
    "DYLD_LIBRARY_PATH=${CMAKE_BINARY_DIR}/lib:$ENV{DYLD_LIBRARY_PATH}"
    "LOCI_BASE=${CMAKE_BINARY_DIR}")
  if(LOCI_MPI)
    get_filename_component(_loci_mpi_bin "${MPIEXEC_EXECUTABLE}" DIRECTORY)
    list(PREPEND _loci_test_env "PATH=${_loci_mpi_bin}:$ENV{PATH}")
  endif()
  foreach(_suite ${_loci_suites})
    add_test(NAME quickTest.${_suite}
      COMMAND ${CMAKE_COMMAND}
        -DSUITE=${_suite}
        -DBASE=${CMAKE_BINARY_DIR}
        -DGNU_MAKE=${GNU_MAKE_EXECUTABLE}
        -P ${CMAKE_SOURCE_DIR}/cmake/run_quicktest_suite.cmake)
    set_tests_properties(quickTest.${_suite} PROPERTIES
      ENVIRONMENT "${_loci_test_env}"
      LABELS quicktest
      TIMEOUT 3600)
  endforeach()
  add_custom_target(quicktest
    COMMAND ${CMAKE_CTEST_COMMAND} -L quicktest --output-on-failure
    DEPENDS lpp Loci Tools sprng fvm_m fvmFAD_m fvmVFAD_m fvmadapt_m
            fvmoverset_m extract plot3d2vog vogcheck refmesh marker refine
    USES_TERMINAL
    COMMENT "Running the quickTest suites (mirrors legacy 'make test')")
  add_custom_target(testclean
    COMMAND ${GNU_MAKE_EXECUTABLE} -C ${CMAKE_BINARY_DIR}/quickTest
            distclean LOCI_BASE=${CMAKE_BINARY_DIR}
            TEST_BASE=${CMAKE_BINARY_DIR}/quickTest
    COMMENT "Legacy 'make testclean' equivalent")
endif()

# ---------------------------------------------------------------------------
# Documentation (tutorial PDF + doxygen) through the existing docs Makefile
# ---------------------------------------------------------------------------
if(GNU_MAKE_EXECUTABLE)
  add_custom_target(docs
    COMMAND ${GNU_MAKE_EXECUTABLE} -C ${CMAKE_BINARY_DIR}/docs
            LOCI_BASE=${CMAKE_BINARY_DIR}
    DEPENDS lpp
    USES_TERMINAL
    COMMENT "Building tutorial PDF and Doxygen docs into ${CMAKE_BINARY_DIR}/docs")
  add_custom_target(docs-clean
    COMMAND ${GNU_MAKE_EXECUTABLE} -C ${CMAKE_BINARY_DIR}/docs clean
            LOCI_BASE=${CMAKE_BINARY_DIR})
endif()

# ---------------------------------------------------------------------------
# Install: replicates src/scripts/Install.bash (see component notes)
# ---------------------------------------------------------------------------
# (TARGETS/FILES installs are declared in subdirectories; here the shared
#  config files, headers, and docs.)
install(FILES
    "${CMAKE_SOURCE_DIR}/src/conf/Loci.conf"
    "${CMAKE_BINARY_DIR}/sys.conf"
    "${CMAKE_BINARY_DIR}/comp.conf"
  DESTINATION . COMPONENT conf
  PERMISSIONS ${LOCIO_FILE_PERMS})
# Install.bash normalizes the GIT_INFO/GIT_BRANCH lines at install time
install(FILES
    "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/version-install.conf"
  DESTINATION . COMPONENT conf RENAME version.conf
  PERMISSIONS ${LOCIO_FILE_PERMS})

# real copies of the public headers (legacy: cp -r of the include tree),
# then the generated Config/version_*.h from the build tree on top
install(DIRECTORY "${CMAKE_SOURCE_DIR}/src/include/"
  DESTINATION include COMPONENT headers
  FILE_PERMISSIONS ${LOCIO_FILE_PERMS}
  DIRECTORY_PERMISSIONS ${LOCIO_DIR_PERMS})
# version_details.h is only regenerated on re-configure; install anyway
install(FILES
    "${CMAKE_BINARY_DIR}/include/Config/version_details.h"
    "${CMAKE_BINARY_DIR}/include/Config/version_info.h"
  DESTINATION include/Config COMPONENT headers PERMISSIONS ${LOCIO_FILE_PERMS})

# tutorial/doxygen outputs land in the build docs tree only if `docs` ran;
# replicate Install.bash's "install if present" behavior
install(CODE "
  set(_tut \"${CMAKE_BINARY_DIR}/docs/tutorial/docs/tutorial.pdf\")
  if(EXISTS \${_tut})
    install(FILES \${_tut} DESTINATION docs COMPONENT docs
            PERMISSIONS ${LOCIO_FILE_PERMS})
  endif()
  set(_sl \"${CMAKE_SOURCE_DIR}/docs/tutorial/LociTutorialSlides/LociSlides.pdf\")
  if(EXISTS \${_sl})
    install(FILES \${_sl} DESTINATION docs COMPONENT docs
            PERMISSIONS ${LOCIO_FILE_PERMS})
  endif()
  set(_dh \"${CMAKE_BINARY_DIR}/docs/doxygen/html\")
  if(EXISTS \${_dh})
    install(DIRECTORY \${_dh} DESTINATION docs/doxygen COMPONENT docs
            FILE_PERMISSIONS ${LOCIO_FILE_PERMS}
            DIRECTORY_PERMISSIONS ${LOCIO_DIR_PERMS})
  endif()
")
file(GLOB LOCI_TUTORIAL_HEAT_FILES
  "${CMAKE_SOURCE_DIR}/docs/tutorial/heat/*.loci"
  "${CMAKE_SOURCE_DIR}/docs/tutorial/heat/*.lh"
  "${CMAKE_SOURCE_DIR}/docs/tutorial/heat/*.vars"
  "${CMAKE_SOURCE_DIR}/docs/tutorial/heat/*.vog")
install(FILES
    "${CMAKE_SOURCE_DIR}/docs/tutorial/heat/Makefile"
    ${LOCI_TUTORIAL_HEAT_FILES}
  DESTINATION docs/heat COMPONENT docs OPTIONAL PERMISSIONS ${LOCIO_FILE_PERMS})
install(DIRECTORY
    "${CMAKE_SOURCE_DIR}/docs/tutorial/1D-Diffusion"
    "${CMAKE_SOURCE_DIR}/docs/tutorial/Datatypes"
  DESTINATION docs COMPONENT docs OPTIONAL
  FILES_MATCHING PATTERN "Makefile" PATTERN "*.loci" PATTERN "*.lh"
                 PATTERN "*.cc" PATTERN "*.vars" PATTERN "*.vog"
  PERMISSIONS ${LOCIO_DIR_PERMS} ${LOCIO_FILE_PERMS})

# ---------------------------------------------------------------------------
# Legacy convenience targets: make install_minimal / uninstall / tarball
#
# Legacy semantics (src/Makefile): 'install' = default + docs + Install.bash,
# 'install_minimal' = default + Install.bash (tutorial example files are still
# installed; PDFs/doxygen are installed only if they exist). The CMake
# equivalent of legacy 'make install' is therefore:
#     cmake --build <dir> --target docs && cmake --install <dir>
# and install_minimal below installs everything that exists.
# ---------------------------------------------------------------------------
add_custom_target(install_minimal
  COMMAND ${CMAKE_COMMAND} --install ${CMAKE_BINARY_DIR}
  COMMENT "Install without building docs (legacy install_minimal)")

add_custom_target(uninstall
  COMMAND ${CMAKE_COMMAND}
    -DBINARY_DIR=${CMAKE_BINARY_DIR}
    -DPREFIX=${CMAKE_INSTALL_PREFIX}
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/Uninstall.cmake
  COMMENT "Remove installed files (legacy 'make uninstall')")

add_custom_target(tarball
  COMMAND ${CMAKE_COMMAND}
    -DSRC=${CMAKE_CURRENT_SOURCE_DIR}
    -DREV=${LOCI_REVISION_NAME}
    -DGIT_INFO=${LOCI_GIT_INFO}
    -DGIT_BRANCH=${LOCI_GIT_BRANCH}
    -DGIT_EXECUTABLE=${GIT_EXECUTABLE}
    -P ${CMAKE_SOURCE_DIR}/cmake/MakeTarball.cmake
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  COMMENT "Source tarball via git archive (legacy 'make tarball')")

add_custom_target(tarball-with-docs
  COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target docs
  COMMAND bash ${CMAKE_SOURCE_DIR}/src/scripts/tarball_with_docs.sh
          "${LOCI_REVISION_NAME}" "${LOCI_GIT_INFO}" "${LOCI_GIT_BRANCH}"
          "${CMAKE_BINARY_DIR}"
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  DEPENDS docs
  USES_TERMINAL
  COMMENT "Tarball with prebuilt documentation (legacy 'make tarball-with-docs')")

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
message(STATUS "")
message(STATUS "Loci ${LOCI_GIT_INFO} (${LOCI_GIT_BRANCH}) configuration:")
message(STATUS "  install prefix ....... ${LOCI_INSTALL_PATH}")
message(STATUS "  MPI .................. ${LOCI_MPI} (driver: ${LOCI_MPI_DRIVER})")
message(STATUS "  HDF5 ................. ${LOCI_HDF5_BASE}")
message(STATUS "  PETSc ................ ${LOCI_PETSC_DEFS}")
message(STATUS "  partitioner libs ..... ${LOCI_METIS_LIBS}")
message(STATUS "  CGNS ................. ${LOCI_CGNS_BASE}")
message(STATUS "  bounds checking ...... ${LOCI_BOUNDS_CHECK}")
message(STATUS "  LOCI_RPATH define .... ${LOCI_RPATH}")
message(STATUS "  binary dir doubles as LOCI_BASE for quickTest/app builds")
message(STATUS "")
