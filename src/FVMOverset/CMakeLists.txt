# FVMOverset: overset-grid module (legacy src/FVMOverset/Makefile)
loci_glob_sources(LOCI_OVERSET_SRCS)
loci_prepare_sources(LOCI_OVERSET_PREPARED ${LOCI_OVERSET_SRCS})

loci_add_module_flavors(NAME fvmoverset
  TARGETS fvmoverset_m fvmoversetFAD_m fvmoversetVFAD_m
  OUT_NAMES fvmoverset_m fvmoversetFAD_m fvmoversetVFAD_m
  SOURCES ${LOCI_OVERSET_PREPARED})
