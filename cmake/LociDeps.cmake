# LociDeps.cmake
#
# Dependency detection mirroring the legacy ./configure script.  Every
# dependency produces:
#   * include/define/link lists used by the CMake targets themselves, and
#   * the literal sys.conf fragment lines the legacy configure wrote, so
#     GNU-make consumers of the installed Loci.conf (quickTest suites and
#     external Loci applications) see identical variables.

# --------------------------------------------------------------------------
# Search-path helper: mimic configure's find_lib/find_exec scan of
# $LD_LIBRARY_PATH / $PATH / $CMAKE_PREFIX_PATH.
# --------------------------------------------------------------------------
function(loci_search_lib name search_paths out_dir)
  set(${out_dir} 0 PARENT_SCOPE)
  # legacy find_lib(): any file whose name starts with lib<name>. (includes
  # versioned shared objects) in a searched lib directory counts.
  foreach(_dir ${search_paths})
    if(_dir AND IS_DIRECTORY "${_dir}")
      foreach(_sub lib lib64 "")
        file(GLOB _hit "${_dir}/${_sub}/lib${name}.*")
        list(FILTER _hit INCLUDE REGEX "/lib${name}\\.(so|a|dylib)")
        if(_hit)
          set(${out_dir} "${_dir}" PARENT_SCOPE)
          return()
        endif()
      endforeach()
    endif()
  endforeach()
endfunction()

function(loci_lib_search_paths out)
  set(_paths)
  foreach(_v LOCI_MPI_DIR LOCI_HDF5_DIR LOCI_CGNS_DIR LOCI_PETSC_DIR
             LOCI_METIS_DIR LOCI_PARMETIS_DIR LOCI_SCOCH_DIR LOCI_TEC360_DIR)
    if(${_v})
      list(APPEND _paths "${${_v}}")
    endif()
  endforeach()
  list(APPEND _paths ${CMAKE_PREFIX_PATH})
  foreach(_env LD_LIBRARY_PATH DYLD_LIBRARY_PATH LIBRARY_PATH)
    if(DEFINED ENV{${_env}})
      string(REPLACE ":" ";" _envpaths "$ENV{${_env}}")
      list(APPEND _paths ${_envpaths})
    endif()
  endforeach()
  list(APPEND _paths /usr/local /usr)
  set(${out} "${_paths}" PARENT_SCOPE)
endfunction()

loci_lib_search_paths(LOCI_SEARCH_PATHS)

# --------------------------------------------------------------------------
# MPI
# --------------------------------------------------------------------------
set(LOCI_MPI_RUN "")
set(LOCI_MPI_STUB_DIR "")
if(LOCI_MPI)
  find_package(MPI REQUIRED COMPONENTS C CXX)
  # configure uses the driver compilers (mpicc/mpicxx) unless --no-mpi-driver
  set(MPI_C_COMPILER_TOKEN "none")
  set(MPI_CXX_COMPILER_TOKEN "none")
  set(MPI_F90_COMPILER_TOKEN "none")
  # configure's driver/token scan (configure ~lines 576-640): mpirun first,
  # mpiexec fallback; drivers found next to the launcher, preferring
  # mpic++ over mpicxx over mpiCC; mpicc and mpif90 by plain name.
  # configure's launcher/driver resolution (configure ~lines 576-640):
  # with --mpi-dir=DIR (LOCI_MPI_DIR) the launcher and drivers are looked for
  # only in DIR/bin and MPI_BASE=DIR; otherwise mpirun (falling back to
  # mpiexec) is found on PATH and MPI_BASE is the bin directory itself (the
  # legacy sed meant to strip "/bin" is a no-op, so the quirk is preserved
  # for byte-exact sys.conf parity). Drivers are matched next to the
  # launcher, preferring mpic++ over mpicxx over mpiCC.
  if(LOCI_MPI_DIR)
    find_program(LOCI_MPIRUN_EXE NAMES mpirun mpiexec
      HINTS "${LOCI_MPI_DIR}/bin" NO_DEFAULT_PATH REQUIRED)
    get_filename_component(_mpi_bin "${LOCI_MPIRUN_EXE}" DIRECTORY)
    set(LOCI_MPI_BASE "${LOCI_MPI_DIR}")
  else()
    find_program(LOCI_MPIRUN_EXE NAMES mpirun mpiexec REQUIRED)
    get_filename_component(_mpi_bin "${LOCI_MPIRUN_EXE}" DIRECTORY)
    set(LOCI_MPI_BASE "${_mpi_bin}")
  endif()
  if(LOCI_MPI_DRIVER)
    find_program(_loci_mpi_cc NAMES mpicc HINTS ${_mpi_bin} NO_DEFAULT_PATH)
    if(_loci_mpi_cc)
      set(MPI_C_COMPILER_TOKEN "mpicc")
    endif()
    find_program(_loci_mpi_f90 NAMES mpif90 HINTS ${_mpi_bin} NO_DEFAULT_PATH)
    if(_loci_mpi_f90)
      set(MPI_F90_COMPILER_TOKEN "mpif90")
    endif()
    foreach(_cxx "mpic++" mpicxx mpiCC)
      find_program(_loci_mpi_cxx NAMES "${_cxx}" HINTS ${_mpi_bin}
        NO_DEFAULT_PATH)
      if(_loci_mpi_cxx)
        set(MPI_CXX_COMPILER_TOKEN "${_cxx}")
        break()
      endif()
    endforeach()
  endif()
  get_filename_component(_mpi_launcher_name "${LOCI_MPIRUN_EXE}" NAME)
  set(LOCI_MPI_RUN "${_mpi_bin}/${_mpi_launcher_name}")

  if(MPI_C_COMPILER_TOKEN STREQUAL "none")
    # legacy: no driver -> plain compiler plus explicit -L/-l flags
    set(LOCI_MPI_LIBS_PLAIN "-L${LOCI_MPI_BASE}/lib")
    if(EXISTS "${LOCI_MPI_BASE}/lib/libmpi.a" OR
       EXISTS "${LOCI_MPI_BASE}/lib/libmpi.so" OR
       EXISTS "${LOCI_MPI_BASE}/lib/libmpi.dylib")
      string(APPEND LOCI_MPI_LIBS_PLAIN " -lmpi")
    elseif(EXISTS "${LOCI_MPI_BASE}/lib/libmpich.a" OR
           EXISTS "${LOCI_MPI_BASE}/lib/libmpich.so" OR
           EXISTS "${LOCI_MPI_BASE}/lib/libmpich.dylib")
      string(APPEND LOCI_MPI_LIBS_PLAIN " -lmpich")
    endif()
    set(LOCI_MPI_INCLUDE_DIR "-I${LOCI_MPI_BASE}/include")
  else()
    set(LOCI_MPI_LIBS_PLAIN "")
    set(LOCI_MPI_INCLUDE_DIR "")
  endif()

  set(LOCI_MPI_SYSCONF
"# MPI Libraries Setup
MPI_BASE = ${LOCI_MPI_BASE}
MPI_LIBS = ${LOCI_MPI_LIBS_PLAIN}
MPI_INCLUDE = ${LOCI_MPI_INCLUDE_DIR}
MPI_RUN=${LOCI_MPI_RUN}
MPI_C_COMPILER = ${MPI_C_COMPILER_TOKEN}
MPI_CXX_COMPILER = ${MPI_CXX_COMPILER_TOKEN}
MPI_F90_COMPILER = ${MPI_F90_COMPILER_TOKEN}
")
  message(STATUS "Loci: MPI found: ${MPIEXEC_EXECUTABLE} (driver: "
    "${MPI_CXX_COMPILER_TOKEN})")
else()
  # --nompi: build against the bundled MPI stub layer (legacy sys.conf text)
  set(LOCI_MPI_STUB_DIR "${CMAKE_BINARY_DIR}/include/MPI_stubb")
  set(LOCI_MPI_SYSCONF
"# MPI Libraries Setup
MPI_BASE =
MPI_LIBS =
MPI_INCLUDE = -DMPI_STUBB -I$(LOCI_BASE)/include/MPI_stubb
MPI_RUN = $(LOCI_BASE)/bin/mpinorun
MPI_C_COMPILER = none
MPI_CXX_COMPILER = none
MPI_F90_COMPILER = none
")
  message(STATUS "Loci: building WITHOUT MPI (stub layer), parallel "
    "execution disabled")
endif()

# --------------------------------------------------------------------------
# POSIX threads (configure default: disabled)
# --------------------------------------------------------------------------
if(LOCI_PTHREADS)
  set(LOCI_PTHREADS_DEFINE -DPTHREADS)
  set(LOCI_PTHREADS_LIB -lpthread)
else()
  set(LOCI_PTHREADS_DEFINE "")
  set(LOCI_PTHREADS_LIB "")
endif()

# --------------------------------------------------------------------------
# HDF5 (hard requirement; configure searches h5dump then libhdf5)
# --------------------------------------------------------------------------
find_program(LOCI_H5DUMP_EXECUTABLE h5dump HINTS ${LOCI_HDF5_DIR}/bin)
set(LOCI_HDF5_BASE "${LOCI_HDF5_DIR}")
if(NOT LOCI_HDF5_BASE OR NOT IS_DIRECTORY "${LOCI_HDF5_BASE}")
  if(LOCI_H5DUMP_EXECUTABLE)
    get_filename_component(_bin "${LOCI_H5DUMP_EXECUTABLE}" DIRECTORY)
    get_filename_component(LOCI_HDF5_BASE "${_bin}" DIRECTORY)
  else()
    loci_search_lib(hdf5 "${LOCI_SEARCH_PATHS}" LOCI_HDF5_BASE)
  endif()
endif()
if(NOT LOCI_HDF5_BASE OR NOT IS_DIRECTORY "${LOCI_HDF5_BASE}")
  message(FATAL_ERROR
    "Unable to find hdf5 libraries!  Pass -DLOCI_HDF5_DIR=<path> or put "
    "h5dump on PATH / library dirs in LD_LIBRARY_PATH (Loci cannot run "
    "without HDF5).")
endif()

# Replicate configure's libhdf5.settings parsing for the support libraries
set(LOCI_H5_SUPPORT_LIBS "-lz")
set(LOCI_H5_SUPPORT_LDFLAGS "")
set(_h5_settings "${LOCI_HDF5_BASE}/lib/libhdf5.settings")
if(EXISTS "${_h5_settings}")
  file(READ "${_h5_settings}" _h5s)
  string(REGEX MATCH "Extra libraries:[^\n]*" _m "${_h5s}")
  string(REGEX REPLACE "^Extra libraries:[ \t]*" "" _m "${_m}")
  string(STRIP "${_m}" _m)
  if(_m AND NOT _m MATCHES ";")
    set(LOCI_H5_SUPPORT_LIBS "${_m}")
    string(REGEX MATCH "AM_LDFLAGS:[^\n]*" _f "${_h5s}")
    string(REGEX REPLACE "^.*:" "" _f "${_f}")
    string(STRIP "${_f}" LOCI_H5_SUPPORT_LDFLAGS)
  endif()
endif()

set(LOCI_HDF5_LIBDIR "${LOCI_HDF5_BASE}/lib")
set(LOCI_HDF5_LIBNAME "-lhdf5")
set(LOCI_HDF5_INC_SUFFIX "include")
if(EXISTS "${LOCI_HDF5_BASE}/lib64/libhdf5.so")
  set(LOCI_HDF5_SYSCONF
"# HDF5 File I/O Libraries Setup
HDF5_BASE = ${LOCI_HDF5_BASE}
HDF5_LIBS = -L$(HDF5_BASE)/lib64 $(RPATH)$(HDF5_BASE)/lib64 -L$(HDF5_BASE)/lib $(RPATH)$(HDF5_BASE)/lib -lhdf5 -lz
HDF5_INCLUDE = -I$(HDF5_BASE)/include/
")
  set(LOCI_HDF5_LIBDIR "${LOCI_HDF5_BASE}/lib64")
elseif(EXISTS "${LOCI_HDF5_BASE}/lib/x86_64-linux-gnu/libhdf5_serial.so")
  set(LOCI_HDF5_LIBDIR "${LOCI_HDF5_BASE}/lib/x86_64-linux-gnu")
  set(LOCI_HDF5_LIBNAME "-lhdf5_serial")
  set(LOCI_HDF5_INC_SUFFIX "include/hdf5/serial")
  set(LOCI_HDF5_SYSCONF
"# HDF5 File I/O Libraries Setup
HDF5_BASE = ${LOCI_HDF5_BASE}
HDF5_LIBS = -L$(HDF5_BASE)/lib/x86_64-linux-gnu/ $(RPATH)$(HDF5_BASE)/lib/x86_64-linux-gnu -lhdf5_serial -lz
HDF5_INCLUDE = -I$(HDF5_BASE)/include/hdf5/serial
")
else()
  set(_h5_sysconf_libs
    "-L$(HDF5_BASE)/lib -lhdf5 $(RPATH)$(HDF5_BASE)/lib")
  if(LOCI_H5_SUPPORT_LDFLAGS)
    string(APPEND _h5_sysconf_libs " ${LOCI_H5_SUPPORT_LDFLAGS}")
  endif()
  string(APPEND _h5_sysconf_libs " ${LOCI_H5_SUPPORT_LIBS}")
  set(LOCI_HDF5_SYSCONF
"# HDF5 File I/O Libraries Setup
HDF5_BASE = ${LOCI_HDF5_BASE}
HDF5_LIBS = ${_h5_sysconf_libs}
HDF5_INCLUDE = -I$(HDF5_BASE)/include/
")
endif()
set(LOCI_HDF5_INCLUDE_DIR "${LOCI_HDF5_BASE}/${LOCI_HDF5_INC_SUFFIX}")
# BASE_LIBS in the legacy build carries $(RPATH)$(HDF5_BASE)/lib, which is
# what makes libLoci/libTools (and their consumers such as lpp) resolve
# libhdf5 without LD_LIBRARY_PATH; replicate that baked rpath.
set(LOCI_HDF5_LIBS -L"${LOCI_HDF5_LIBDIR}" "${LOCI_RPATH_FLAG}${LOCI_HDF5_LIBDIR}"
  "${LOCI_HDF5_LIBNAME}")
separate_arguments(_h5sup_libs UNIX_COMMAND "${LOCI_H5_SUPPORT_LIBS}")
if(LOCI_H5_SUPPORT_LDFLAGS)
  separate_arguments(_h5sup_ld UNIX_COMMAND "${LOCI_H5_SUPPORT_LDFLAGS}")
  list(APPEND LOCI_HDF5_LIBS ${_h5sup_ld})
endif()
list(APPEND LOCI_HDF5_LIBS ${_h5sup_libs})
message(STATUS "Loci: Using HDF5 libraries in directory ${LOCI_HDF5_BASE}")

# --------------------------------------------------------------------------
# libxml2 (configure checks /usr/include/libxml2 first)
# --------------------------------------------------------------------------
loci_search_lib(xml2 "${LOCI_SEARCH_PATHS}" _xml2_dir)
set(LOCI_XML2_BASE "/usr")
if(NOT IS_DIRECTORY "/usr/include/libxml2" AND NOT _xml2_dir EQUAL 0)
  set(LOCI_XML2_BASE "${_xml2_dir}")
endif()
if(IS_DIRECTORY "${LOCI_XML2_BASE}/include/libxml2")
  # configure lines 762-770: literal sys.conf text
  if(EXISTS "${LOCI_XML2_BASE}/lib64/libxml2.so" OR
     EXISTS "${LOCI_XML2_BASE}/lib64/libxml2.a")
    set(_xml2_sysconf_libs
      "-L${LOCI_XML2_BASE}/lib64 -L${LOCI_XML2_BASE}/lib $(RPATH)${LOCI_XML2_BASE}/lib64 $(RPATH)${LOCI_XML2_BASE}/lib -lxml2")
    set(LOCI_XML2_LINK -L"${LOCI_XML2_BASE}/lib64" -L"${LOCI_XML2_BASE}/lib"
      -lxml2)
  else()
    set(_xml2_sysconf_libs "-L${LOCI_XML2_BASE}/lib -lxml2")
    set(LOCI_XML2_LINK -L"${LOCI_XML2_BASE}/lib" -lxml2)
  endif()
  set(LOCI_LIBXML2_DEFINE -DUSE_LIBXML2)
  set(LOCI_LIBXML2_LIBS "${_xml2_sysconf_libs}")
  set(LOCI_LIBXML2_INCLUDE "-I${LOCI_XML2_BASE}/include/libxml2")
  set(LOCI_XML2_INCDIR "${LOCI_XML2_BASE}/include/libxml2")
  set(LOCI_LIBXML2_SYSCONF
"# libxml2 library setup
LIBXML2_DEFINE = -DUSE_LIBXML2
LIBXML2_LIBS = ${_xml2_sysconf_libs}
LIBXML2_INCLUDE = ${LOCI_LIBXML2_INCLUDE}
")
  message(STATUS "Loci: Using libxml2 found in "
    "${LOCI_XML2_BASE}/include/libxml2")
elseif(APPLE)
  # configure's Darwin fallback: plain -lxml2 (homebrew/system search paths)
  set(LOCI_LIBXML2_DEFINE -DUSE_LIBXML2)
  set(LOCI_LIBXML2_LIBS "-lxml2")
  set(LOCI_XML2_LINK -lxml2)
  set(LOCI_LIBXML2_INCLUDE "-I/usr/include/libxml2")
  set(LOCI_XML2_INCDIR "/usr/include/libxml2")
  set(LOCI_LIBXML2_SYSCONF
"# libxml2 library setup
LIBXML2_DEFINE = -DUSE_LIBXML2
LIBXML2_LIBS = -lxml2
LIBXML2_INCLUDE = -I/usr/include/libxml2
")
else()
  set(LOCI_LIBXML2_DEFINE)
  set(LOCI_LIBXML2_LIBS "")
  set(LOCI_XML2_LINK)
  set(LOCI_LIBXML2_INCLUDE "")
  set(LOCI_XML2_INCDIR "")
  set(LOCI_LIBXML2_SYSCONF
"# libxml2 library setup
LIBXML2_DEFINE =
LIBXML2_LIBS =
LIBXML2_INCLUDE =
")
  message(WARNING "Loci: libxml2 not found, disabling XML features!")
endif()

# --------------------------------------------------------------------------
# Graph partitioner: PT-Scotch or METIS/ParMETIS (configure auto-detects)
# --------------------------------------------------------------------------
set(LOCI_METIS_INCDIR "")
set(LOCI_METIS_LIBS "")
set(LOCI_METIS_DEFS "")
set(LOCI_METIS_INCLUDE "")
set(LOCI_METIS_BASE "")
set(LOCI_METIS_SYSCONF
"# METIS Library Setup
INSTALL_METIS=0
METIS_BASE=
METIS_LIBS=
METIS_INCLUDE=
")
if(LOCI_MPI AND NOT LOCI_NO_METIS)
  set(_scotch_base 0)
  set(_parmetis_base 0)
  set(_metis_base 0)
  if(LOCI_SCOCH_DIR)
    loci_search_lib(scotch "${LOCI_SCOCH_DIR}" _scotch_base)
  else()
    loci_search_lib(scotch "${LOCI_SEARCH_PATHS}" _scotch_base)
  endif()
  if(NOT _scotch_base EQUAL 0)
    set(LOCI_METIS_BASE "${_scotch_base}")
    set(LOCI_METIS_LIBS
      -L"${LOCI_METIS_BASE}/lib" "${LOCI_RPATH_FLAG}${LOCI_METIS_BASE}/lib"
      -lscotchmetisv5 -lptscotchparmetisv3 -lscotch -lptscotch -lscotcherrexit)
    set(LOCI_METIS_DEFS LOCI_USE_METIS USE_SCOTCH)
    set(LOCI_METIS_INCDIR "${LOCI_METIS_BASE}/include")
  else()
    if(LOCI_PARMETIS_DIR)
      loci_search_lib(parmetis "${LOCI_PARMETIS_DIR}" _parmetis_base)
    else()
      loci_search_lib(parmetis "${LOCI_SEARCH_PATHS}" _parmetis_base)
    endif()
    if(LOCI_METIS_DIR)
      loci_search_lib(metis "${LOCI_METIS_DIR}" _metis_base)
    else()
      loci_search_lib(metis "${LOCI_SEARCH_PATHS}" _metis_base)
    endif()
    if(NOT _parmetis_base EQUAL 0)
      if(_metis_base EQUAL 0)
        set(_metis_base "${_parmetis_base}")
      endif()
      set(LOCI_METIS_BASE "${_metis_base}")
      set(LOCI_METIS_LIBS -L"${_parmetis_base}/lib"
        "${LOCI_RPATH_FLAG}${_parmetis_base}/lib" -lparmetis)
      if("${_metis_base}" STREQUAL "${_parmetis_base}")
        list(APPEND LOCI_METIS_LIBS -lmetis)
      else()
        list(APPEND LOCI_METIS_LIBS -L"${_metis_base}/lib"
          "${LOCI_RPATH_FLAG}${_metis_base}/lib" -lmetis)
        set(LOCI_METIS_INC2 "${_parmetis_base}/include")
      endif()
      set(LOCI_METIS_INCDIR "${_metis_base}/include")
      set(LOCI_METIS_DEFS LOCI_USE_METIS)
    elseif(NOT _metis_base EQUAL 0)
      message(WARNING
        "Loci: serial METIS found but no ParMETIS/PT-Scotch; graph "
        "partitioning disabled (space-filling curve will be used). The "
        "legacy configure linked -lparmetis in this state and failed to "
        "build; CMake handles it gracefully instead.")
    endif()
  endif()
  if(LOCI_METIS_LIBS)
    set(LOCI_METIS_INCLUDE "-I${LOCI_METIS_INCDIR} -DLOCI_USE_METIS")
    if(LOCI_METIS_INC2)
      string(APPEND LOCI_METIS_INCLUDE " -I${LOCI_METIS_INC2}")
    endif()
    if(";${LOCI_METIS_DEFS};" MATCHES ";USE_SCOTCH;")
      string(APPEND LOCI_METIS_INCLUDE " -DUSE_SCOTCH")
    endif()
    set(LOCI_METIS_SYSCONF
"# METIS Library Setup
INSTALL_METIS=0
METIS_BASE= ${LOCI_METIS_BASE}
METIS_LIBS= ${LOCI_METIS_LIBS}
METIS_INCLUDE= ${LOCI_METIS_INCLUDE}
")
    message(STATUS "Loci: graph partitioner: ${LOCI_METIS_BASE}")
  endif()
endif()
if(NOT LOCI_METIS_LIBS AND LOCI_MPI)
  message(STATUS "Loci: Graph Partitioner such as METIS will not be used. "
    "Default partitioner will use space filling curves")
endif()

# --------------------------------------------------------------------------
# CGNS (optional; pre/post converters + Loci CGNS I/O)
# --------------------------------------------------------------------------
set(LOCI_CGNS_BASE "")
set(LOCI_CGNS_DEFS "")
set(LOCI_CGNS_INCDIR "")
set(LOCI_CGNS_LINK "")
set(LOCI_CGNS_SYSCONF
"# CGNS Library Setup
CGNS_BASE =
CGNS_INCLUDE =
CGNS_LIBS =
")
if(LOCI_CGNS_DIR AND IS_DIRECTORY "${LOCI_CGNS_DIR}/include")
  set(LOCI_CGNS_BASE "${LOCI_CGNS_DIR}")
else()
  loci_search_lib(cgns "${LOCI_SEARCH_PATHS}" _cgns_dir)
  if(NOT _cgns_dir EQUAL 0)
    set(LOCI_CGNS_BASE "${_cgns_dir}")
  endif()
endif()
if(LOCI_CGNS_BASE AND IS_DIRECTORY "${LOCI_CGNS_BASE}/include")
  set(LOCI_CGNS_DEFS USE_CGNS)
  set(LOCI_CGNS_INCDIR "${LOCI_CGNS_BASE}/include")
  set(LOCI_CGNS_LINK -L"${LOCI_CGNS_BASE}/lib"
    "${LOCI_RPATH_FLAG}${LOCI_CGNS_BASE}/lib" -lcgns)
  set(LOCI_CGNS_SYSCONF
"# CGNS Library Setup
CGNS_BASE = ${LOCI_CGNS_BASE}
CGNS_INCLUDE = -I$(CGNS_BASE)/include/ -DUSE_CGNS
CGNS_LIBS = -L$(CGNS_BASE)/lib $(RPATH)$(CGNS_BASE)/lib -lcgns
")
  message(STATUS "Loci: Using CGNS library found in ${LOCI_CGNS_BASE}")
else()
  set(LOCI_CGNS_BASE "")
  message(STATUS "Loci: libcgns not found, disabling CGNS features!")
endif()

# --------------------------------------------------------------------------
# Tecplot IO (optional)
#   LOCI_TEC360_DIR: static libtecio.a;  LOCI_TECIO_DIR: dynamic .so
# --------------------------------------------------------------------------
set(LOCI_TEC360_INCLUDE "")
set(LOCI_TEC360_LIB "")
set(LOCI_TEC360_DEFS "")
set(LOCI_TEC360_INCDIR "")
if(LOCI_TEC360_DIR AND
   (EXISTS "${LOCI_TEC360_DIR}/lib/libtecio.a" OR
    EXISTS "${LOCI_TEC360_DIR}/libtecio.a"))
  if(EXISTS "${LOCI_TEC360_DIR}/lib/libtecio.a")
    set(_tec_lib "${LOCI_TEC360_DIR}/lib/libtecio.a")
  else()
    set(_tec_lib "${LOCI_TEC360_DIR}/libtecio.a")
  endif()
  set(LOCI_TEC360_INCLUDE "-I${LOCI_TEC360_DIR}/include")
  set(LOCI_TEC360_INCDIR "${LOCI_TEC360_DIR}/include")
  set(LOCI_TEC360_DEFS USE_NATIVE_TECPLOT)
  set(LOCI_TEC360_LIB "${_tec_lib}")
elseif(LOCI_TECIO_DIR AND EXISTS "${LOCI_TECIO_DIR}/bin/libtecio.so")
  set(LOCI_TEC360_INCLUDE "-I${LOCI_TECIO_DIR}/include")
  set(LOCI_TEC360_INCDIR "${LOCI_TECIO_DIR}/include")
  set(LOCI_TEC360_DEFS USE_NATIVE_TECPLOT)
  set(LOCI_TEC360_LIB -L"${LOCI_TECIO_DIR}/bin" -ltecio)
else()
  message(STATUS "Loci: TECPLOT native IO library not found, older ascii "
    "format will be used instead.  Use -DLOCI_TEC360_DIR=<path> to enable "
    "native Tecplot output.")
endif()
set(LOCI_TEC_SYSCONF
"# TECPLOT Library Setup
TEC360INCLUDE = ${LOCI_TEC360_INCLUDE}
TEC360LIB = ${LOCI_TEC360_LIB}
")

# --------------------------------------------------------------------------
# PETSc (optional)
# --------------------------------------------------------------------------
set(LOCI_PETSC_DEFS "")
set(LOCI_PETSC_INCDIR "")
set(LOCI_PETSC_LINK "")
set(LOCI_PETSC_SYSCONF
"# PETSc Library Setup
# PETSc not found, Loci compiled without PETSc enabled
")
if(NOT LOCI_PETSC_DIR AND DEFINED ENV{PETSC_DIR})
  set(LOCI_PETSC_DIR "$ENV{PETSC_DIR}")
endif()
if(LOCI_PETSC_DIR AND IS_DIRECTORY "${LOCI_PETSC_DIR}")
  loci_search_lib(petsc "${LOCI_PETSC_DIR}" _petsc_dir)
  if(NOT _petsc_dir EQUAL 0)
    set(LOCI_PETSC_BASE "${LOCI_PETSC_DIR}")
    # extract the BLASLAPACK_LIB line from petscvariables, as configure did
    set(_blas_line "")
    foreach(_cand
        "${LOCI_PETSC_BASE}/conf/petscvariables"
        "${LOCI_PETSC_BASE}/lib/petsc/conf/petscvariables")
      if(EXISTS "${_cand}")
        file(STRINGS "${_cand}" _lines REGEX "^BLASLAPACK_LIB")
        if(_lines)
          list(GET _lines 0 _blas_line)
        endif()
        break()
      endif()
    endforeach()
    if(NOT _blas_line)
      file(GLOB _archvars "${LOCI_PETSC_BASE}/arch-*/conf/petscvariables")
      foreach(_av ${_archvars})
        file(STRINGS "${_av}" _lines REGEX "^BLASLAPACK_LIB")
        if(_lines)
          list(GET _lines 0 _blas_line)
          break()
        endif()
      endforeach()
    endif()
    if(NOT _blas_line)
      message(WARNING
        "Loci: BLAS library paths not extracted from PETSc config files! "
        "Is PETSc installed properly?")
    endif()
    set(LOCI_PETSC_DEFS USE_PETSC PETSC_USE_EXTERN_CXX)
    set(LOCI_PETSC_INCDIR "${LOCI_PETSC_BASE}/include")
    set(LOCI_PETSC_LINK -L"${LOCI_PETSC_BASE}/lib"
      "${LOCI_RPATH_FLAG}${LOCI_PETSC_BASE}/lib" -lpetsc)
    string(REGEX REPLACE "^BLASLAPACK_LIB[ \t]*=[ \t]*" "" _blas_libs
      "${_blas_line}")
    if(_blas_libs)
      separate_arguments(_blas_libs_list UNIX_COMMAND "${_blas_libs}")
      list(APPEND LOCI_PETSC_LINK ${_blas_libs_list})
    endif()
    set(LOCI_PETSC_SYSCONF
"# PETSc Library Setup
PETSC_BASE = ${LOCI_PETSC_BASE}
${_blas_line}
PETSC_LIBS = -L$(PETSC_BASE)/lib/ $(RPATH)$(PETSC_BASE)/lib/ -lpetsc $(BLASLAPACK_LIB)
PETSC_INCLUDE = -I$(PETSC_BASE)/include
PETSC_DEFINE = -DUSE_PETSC -DPETSC_USE_EXTERN_CXX
")
    message(STATUS "Loci: Using PETSc libraries found in ${LOCI_PETSC_BASE}")
  endif()
endif()

# --------------------------------------------------------------------------
# CUDA (optional, configure --with-cuda)
# --------------------------------------------------------------------------
set(LOCI_CUDA_DEFS "")
set(LOCI_CUDA_INCDIR "")
set(LOCI_CUDA_LINK "")
set(LOCI_CUDA_SYSCONF "")
if(LOCI_CUDA)
  if(NOT LOCI_CUDA_DIR)
    message(FATAL_ERROR "LOCI_CUDA=ON requires -DLOCI_CUDA_DIR=<path>")
  endif()
  enable_language(CUDA)
  find_library(LOCI_CUDART_LIBRARY cudart
    HINTS "${LOCI_CUDA_DIR}/lib64" "${LOCI_CUDA_DIR}/lib")
  if(NOT LOCI_CUDART_LIBRARY)
    message(FATAL_ERROR "cudart not found under ${LOCI_CUDA_DIR}")
  endif()
  set(LOCI_CUDA_DEFS USE_CUDA_RT)
  set(LOCI_CUDA_INCDIR "${LOCI_CUDA_DIR}/include")
  set(LOCI_CUDA_LINK -L"${LOCI_CUDA_DIR}/lib64" -lcudart
    "${LOCI_RPATH_FLAG}${LOCI_CUDA_DIR}/lib64")
  set(LOCI_CUDA_SYSCONF
"
# CUDA setup
CUDA_BASE = ${LOCI_CUDA_DIR}
CUDA_LIBS = -L$(CUDA_BASE)/lib64 -lcudart $(RPATH)$(CUDA_BASE)/lib64
CUDA_INCLUDE = -I$(CUDA_BASE)/include -I${LOCI_MPI_BASE}/include -DUSE_CUDA_RT
NVCC = nvcc -O3 -lineinfo -g -arch native --expt-relaxed-constexpr
")
endif()

# --------------------------------------------------------------------------
# Fortran support libs (configure gcc branch: gfortran on PATH plus
# libgfortran found -> -lgfortran; no gfortran but g77 present -> -lg2c)
# --------------------------------------------------------------------------
set(LOCI_FORTRAN_LIBS "")
if(LOCI_COMPILER STREQUAL "gcc")
  find_program(LOCI_GFORTRAN gfortran)
  if(LOCI_GFORTRAN)
    loci_search_lib(gfortran "${LOCI_SEARCH_PATHS}" _gfortran_dir)
    if(NOT _gfortran_dir EQUAL 0)
      set(LOCI_FORTRAN_LIBS "-lgfortran")
    endif()
  else()
    find_program(LOCI_G77 g77)
    if(LOCI_G77)
      set(LOCI_FORTRAN_LIBS "-lg2c")
    endif()
  endif()
endif()
