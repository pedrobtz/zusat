# zusat

<!-- badges: start -->
[![R-CMD-check](https://github.com/pedrobtz/zusat/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pedrobtz/zusat/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

R bindings for [CaDiCaL](https://github.com/arminbiere/cadical), a modern
CDCL Boolean satisfiability (SAT) solver by Armin Biere and colleagues.

The CaDiCaL sources are bundled, so there is nothing to install beyond the
package itself and a C++ compiler.

## Installation

``` r
# install.packages("pak")
pak::pak("pedrobtz/zusat")
```

## Usage

Clauses use DIMACS conventions: `i` means "variable *i* is true", `-i` means
its negation. No terminating zero is needed.

``` r
library(zusat)

# (x1 OR x2) AND (NOT x1 OR x2) AND (x1 OR NOT x2)
s <- sat_solver()
sat_add(s, c(1, 2))
sat_add(s, c(-1, 2))
sat_add(s, c(1, -2))

sat_solve(s)
#> [1] "sat"

sat_model(s)
#> [1] TRUE TRUE
```

`NA` in a model marks a variable the solver left unassigned because either
polarity extends the model.

### Incremental solving

The solver keeps its state, so you can add clauses and re-solve without
rebuilding the formula:

``` r
s <- sat_solver()
sat_add(s, c(1, 2))
sat_solve(s)      #> "sat"

sat_add(s, -1)
sat_add(s, -2)
sat_solve(s)      #> "unsat"
```

### Assumptions

Assumptions hold for a single `sat_solve()` call. When the result is
`"unsat"`, `sat_failed()` reports which assumptions the solver actually
used — a small unsatisfiable core over the assumptions:

``` r
s <- sat_solver()
sat_add(s, c(1, 2))

sat_solve(s, assumptions = c(-1, -2))   #> "unsat"
sat_failed(s, c(-1, -2))                #> TRUE TRUE

sat_solve(s)                            #> "sat" (assumptions did not persist)
```

### Tuning

CaDiCaL exposes several hundred integer options:

``` r
sat_option(s, "elim")        # read
sat_option(s, "elim", 0L)    # disable bounded variable elimination
```

## Interrupting

Long solves respond to Ctrl-C. The solver stops at its next safe point and
raises a catchable R error; the solver handle stays usable afterwards.

## Updating the bundled solver

`tools/vendor-cadical.sh [git-ref]` re-vendors CaDiCaL from upstream and
records the exact commit in `src/cadical/VENDORED`. The sources are used
unmodified; the build is configured entirely through `-D` flags in
`src/Makevars`, which documents why each one is needed.

## Licence

zusat is MIT licensed. The bundled CaDiCaL is also MIT licensed — see
`inst/CADICAL_LICENSE` and `inst/COPYRIGHTS`.
