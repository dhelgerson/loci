# lpp -- the Loci preprocessor (legacy src/lpp/Makefile)
set(LOCI_LPP_SOURCES
  template_model.cc template_ast.cc template_parser.cc template_engine.cc
  lpp.cc parseLEX.cc parseAST.cc main.cc)

add_executable(lpp ${LOCI_LPP_SOURCES})
# legacy: lpp links only libTools + libm (+ PTHREADS_LIB), not the full LIBS
target_link_libraries(lpp PRIVATE loci_defs Tools m ${LOCI_PTHREADS_LIB}
  loci_exe_link)
install(TARGETS lpp RUNTIME DESTINATION bin COMPONENT runtime
  PERMISSIONS ${LOCIO_DIR_PERMS} ${LOCIO_EXE_PERMS})
