# Loci

C++ library + declarative (logic-relational, rule-scheduled) programming
framework for CFD-type field simulations. LGPL-3.0. Default branch `dev` is
unstable; `stable41` is the production branch.

## Build

- Must build from a **git clone**, not a tarball: version comes from
  `git describe` at configure time. Run `git submodule init` first; `ext/`
  pins known-good dependency versions (hdf5-1.14.5, petsc v3.22.2, scotch
  v7.0.8, cgns v4.4.0, ...).
- Normal flow from the repo root:
  ```bash
  ./configure --no-sub-dir --prefix=$HOME/local   # --help for options
  make install                                     # -j works
  ```
- `./configure` generates the root `Makefile` and populates the `OBJ/` build
  tree (or `--obj-dir` dir) by **symlinking** source files from `src/` via
  `tmpcopy`. Always edit files under `src/`, not `OBJ/`. `OBJ/` doubles as an
  in-place `LOCI_BASE` for compiling/tests against an unbuilt install.
- Configure writes `OBJ/sys.conf` (library/launcher paths scanned from
  `$PATH`/`$LD_LIBRARY_PATH`) and `OBJ/comp.conf` (copied from
  `src/conf/<compiler>.conf`). Fix misdetection by editing these, not by
  patching Makefiles.
- Hard deps: MPI + HDF5. `--nompi` needs a *serial* HDF5. Partitioner:
  PT-Scotch (`--with-scotch`) or ParMETIS (`--with-parmetis`); also
  `--with-petsc`, `--with-cgns`, `--bounds-check`. libxml2 enables
  XML-region mesh adaptation; CGNS/TecIO are optional.
- Root targets: `make default` (build+install into OBJ), `make install`,
  `make install_minimal` (skips PDF docs), `make test`, `make docs`,
  `make clean`, `make distclean`.

## Build (CMake, new)

- A CMake build system (`CMakeLists.txt` + `cmake/` modules) is being added
  alongside the legacy configure flow and is intended to be functionally
  equivalent; verified on `dev` (MPI + serial HDF5, `--no-sub-dir --no-metis`
  equivalents): identical install tree, identical quickTest results.
  ```bash
  cmake -S . -B build -DCMAKE_INSTALL_PREFIX=$HOME/local \
        -DLOCI_MPI_DIR=$MPI_HOME -DLOCI_HDF5_DIR=$H5_HOME
  cmake --build build -j            # or: ninja -C build
  cmake --install build
  ```
- The CMake binary dir replicates the legacy `OBJ/` layout (`sys.conf`,
  `comp.conf`, symlinked `Loci.conf`, `include/`, `lib/`, `bin/`,
  `quickTest/`, `docs/`), so it doubles as `LOCI_BASE` for unmodified
  quickTest suites and app Makefiles.
- Options mirror configure: `LOCI_MPI=OFF` (= `--nompi`; installs
  `bin/mpinorun`, which the legacy install omits), `LOCI_MPI_DIR`,
  `LOCI_MPI_DRIVER=OFF`, `LOCI_HDF5_DIR`, `LOCI_SCOTCH_DIR`,
  `LOCI_PARMETIS_DIR`, `LOCI_METIS_DIR`, `LOCI_PETSC_DIR`, `LOCI_CGNS_DIR`,
  `LOCI_TEC360_DIR`, `LOCI_CUDA_DIR`, `LOCI_BOUNDS_CHECK`, `LOCI_NO_METIS`,
  `LOCI_NO_SUB_DIR`, `LOCI_OBJ_DIR`. Detection follows configure's
  PATH/`$LD_LIBRARY_PATH` scanning and writes the same `sys.conf` text.
- Extra targets: `docs` (runs the legacy docs Makefile; needs pdflatex +
  doxygen), `install_minimal`, `uninstall` (manifest-based), `tarball`
  (git-archive source tarball). Legacy `make install` == `docs` build +
  install; `install_minimal` installs everything present without building
  PDFs.
- `.loci` preprocessing runs `lpp` via `cmake/lpp_run.cmake` with DEPFILE
  scanning, so ninja/make rebuilds honor lpp's `//DEPEND:` output.

## CI/CD (regression gates)

- `.github/workflows/cmake-parity.yml` guards the CMake migration: on every
  PR/push it builds and tests Loci **twice** on the same runner (legacy
  `./configure && make` as reference, then CMake) and requires strict
  equality via two scripts (also runnable locally, see their usage headers):
  - `cmake/ci/parity_check.sh`: identical installed file sets (bin/lib/include/
    docs), byte-identical headers + `Loci.conf`/`comp.conf`/`version.conf`/
    `sys.conf` (paths normalized), identical aggregated quickTest
    `TestResults`, no symlinks in the install tree. One allow-listed
    exception: on an **untagged** checkout `include/Config/version_info.h`
    (legacy sed-embeds the raw hash into `LOCI_VERSION_MAJOR/MINOR`, CMake
    writes numeric 0/0); tagged checkouts are compared byte-exact there too.
  - `cmake/ci/consumer_check.sh`: builds the unmodified heat tutorial app
    against both install trees with its stock Makefile and requires identical
    numerical output (`mpirun -np 3`).
  Plus jobs for the `--nompi` stub build (serial smoke tests) and a
  bounds-check variant under both build systems; `dist` publishes the git
  tarball artifact (`tarball` target).
- CI does not build PDF docs (no pdflatex); it uses `make install_minimal`
  on the legacy side, which installs the same files when PDFs are absent.
- The pre-existing Spack workflows (`.github/workflows/ci*.yaml`,
  `build-quicktest.yaml`) are untouched and still exercise the legacy flow.

## Tests (quickTest)

- `make test` builds first, then runs suites from `OBJ/quickTest` with
  `LOCI_BASE=<OBJ>`. Suites: `Containers Tools FVMModUnitTests FVM
  SystemTests FVMAdaptTest`.
- Suites are allowed to fail: each writes a `PASSED`/`FAILED` line into an
  aggregated `TestResults`; a suite make-error is captured, not raised. Check
  with `grep FAIL TestResults`, don't trust the exit code of a single suite.
- Run one suite (from repo root, against a built OBJ tree):
  ```bash
  make -C quickTest <Suite> LOCI_BASE=$PWD/OBJ
  ```
  `FVMModUnitTests` builds its `FVMModUnitTest` binary via its `tests` entry
  target automatically.
- FVMAdaptTest groups run individually and need `TEST_BASE` plus libxml2-enabled
  Loci tools, an MPI launcher, `h5dump`, `timeout`:
  ```bash
  make -C quickTest/FVMAdaptTest PlanInputs LOCI_BASE=$PWD/OBJ TEST_BASE=$PWD/quickTest
  ```
- MPI tests launch with `-np 3` (`quickTest/test.conf`, `MPIRUN` comes from
  `OBJ/sys.conf`). On single-core machines reduce `-np 3` to `-np 1` there.
- `FVM` compiles a `fluidTest` app and diffs output against references with
  `ndiff`; `Tools`/`Containers` use vendored doctest
  (`quickTest/contrib/doctest`). CI (workflow_dispatch only) builds through
  Spack with the external `loci_spack` recipe, `spack install --test=root`.
- With the CMake build, each suite is registered as a CTest test that shells
  out to the same legacy suite Makefiles and fails on any `FAILED` line:
  `ctest -L quicktest --test-dir build` (equivalent of `make test`).

## Source layout / codegen

- Core: `src/include` (public headers, include as `<Loci>` or `GLoci.h`),
  `src/System` (scheduler/runtime, distribution), `src/Tools`, `src/lpp`
  (the `lpp` preprocessor). Modules on top: `src/FVMMod`, `src/FVMAdapt`,
  `src/FVMOverset`, `src/FVMtools`. `src/sprng` is vendored FSU RNG;
  `2dgv/` is a standalone X11/PS viewer.
- `.loci` files are **not C++**: `bin/lpp` preprocesses them to `*.lcc~`
  (`LPP_I_SUFFIX`) before C++ compilation; rules live in
  `src/conf/Loci.conf`. Never edit a generated `.lcc~`; edit the `.loci`.
- App/test Makefiles call `AUTOMATIC_FILES = $(call loci_compile_files,)`, so
  adding a `.c/.cc/.loci` file to a directory auto-adds it to the build —
  Makefile `FILES` lists are not needed.
- Application Makefiles should be modeled on `docs/tutorial/heat/Makefile`
  (set `LOCI_BASE`, `include $(LOCI_BASE)/Loci.conf`).

## Conventions (CONTRIBUTING.md)

- Commit title ≤ 50 chars, prefixed with the issue number: `[#108]: Add X to
  Y` (imperative). PRs target `dev` and are squash-merged; keep changes narrow.
- No drive-by fixes (typos, comments, formatting) in a feature PR — open an
  issue instead. Match surrounding code style; there is no formal style guide
  or formatter.
- Generated docs go to OBJ or the install prefix; never commit them under
  `docs/`. `make docs` builds tutorial PDF + Doxygen into OBJ.
