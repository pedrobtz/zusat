# CRAN submission comments

## Test environments

* local macOS, R 4.5.2
* GitHub Actions: macOS, Windows, Ubuntu (release and oldrel-1)
* R-hub containers matching CRAN's Linux flavors: `clang23`, `ubuntu-clang`,
  `ubuntu-gcc16`

## R CMD check results

0 errors | 0 warnings | 1 note

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Pedro Batista <pedrobtz@gmail.com>'
New submission
```

This is a new submission.

## Bundled third-party source

`src/cadical/` contains the CaDiCaL SAT solver (version 3.0.1, commit
`c607304`), by Armin Biere and colleagues, distributed under the MIT licence.
It is bundled rather than linked because there is no CaDiCaL system package on
the platforms CRAN builds for, and the solver is the entire purpose of the
package.

The licence is reproduced in `inst/CADICAL_LICENSE`, the authors are listed as
copyright holders in `Authors@R`, and `inst/COPYRIGHTS` records what is
bundled and under what terms.

`src/cadical/VENDORED` records the exact upstream commit, and
`tools/vendor-cadical.sh` regenerates the tree from it. `tools/vendor/verify`
checks the tree against a recorded manifest and per-file checksums, so the
bundled sources can be confirmed to match upstream.

## Modifications to the bundled sources

The CaDiCaL sources are modified during vendoring, by
`tools/vendor/patch-for-r.sh`, for two reasons. Both are recorded in that
script and reproducible.

**R's C API.** Upstream writes to `stdout` and `stderr` and calls `abort()` and
`exit()` on internal errors. Those are rerouted to `Rprintf`, `REprintf` and
`Rf_error`, so the package does not write outside R's console and cannot
terminate the R session.

**No child processes.** Upstream's compressed-file support forks and executes
`gzip`/`xz` and calls `_exit()` in the child. That path is compiled out with
`-DZUSAT_NO_PIPES`. The package never opens a file through CaDiCaL, so nothing
is lost; this is the configuration upstream already uses on Windows.

## C++ standard

`src/Makevars` sets `CXX_STD = CXX17`. This raises no note — `checking C++
specification` reports `OK` on R-release and `INFO specified C++17` on
R-devel — but since the usual advice is to drop such a specification unless
it is essential, here is why it is.

First, it is what makes the package link correctly at all. Every C++ source is
under `src/cadical/`, and `R CMD INSTALL` globs only `src/*.c*`, so without
`CXX_STD` it concludes the package is pure C and links the shared object with
the C compiler. The result carries no dependency on any C++ runtime. That
loads anyway wherever R has already brought in libstdc++, and fails at
`dlopen` on a libc++ toolchain with `undefined symbol: _ZNSt3__19to_stringEj`.
This was observed on the `clang23` container and fixed by declaring `CXX_STD`.

Second, the standard has to be 17 specifically, and a lower request is not an
option. R-devel rejects one outright — `NOTE Obsolete C++14 standard request
will be ignored` — and falls back to its default of `gnu++20`, where
libstdc++ 12 no longer supplies `<tuple>` transitively to one of the vendored
files and the package fails to compile.

## Compiled code and R CMD check

`checking compiled code` is clean. The rewrites described above are what make
it so; without them the vendored sources reach that check with `abort`,
`exit`, `printf` and `stderr` reachable from the compiled objects. Fifteen
source files are rewritten, plus two headers whose macros expand into other
translation units.

## Tests

The suite includes CaDiCaL's own regression corpus — 50 instances vendored
into `inst/extdata/cadical/`, with expected outcomes taken from upstream's
`run.sh` — and checks that this package's results agree with them. Cardinality
encodings are verified exhaustively for small sizes by enumerating every model
and comparing against the exact expected set.

No test requires network access or writes outside `tempdir()`.

## Method references

There are no published references describing methods original to this
package; it is a binding. The bundled solver is described in Biere et al.,
"CaDiCaL, Kissat, Paracooba, Plingeling and Treengeling entering the SAT
Competition 2020", and in the CaDiCaL repository linked from `DESCRIPTION`.
