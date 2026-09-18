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

## Solving a formula

Clauses use DIMACS conventions: `i` means "variable *i* is true", `-i` means
its negation. No terminating zero is needed.

``` r
library(zusat)

# (x1 OR x2) AND (NOT x1 OR x2)
sat_solve(list(c(1, 2), c(-1, 2)))
#> <zusat_solution> sat  (2 variables, 2 active clauses, 0.000s)
#>  variable value
#>         1  TRUE
#>         2  TRUE
```

A solution is a data frame of `variable` and `value`, so it drops straight
into the rest of R:

``` r
sol <- sat_solve(list(c(1, 2), c(-1, 3)))

sat_status(sol)       #> "sat"
sat_is_sat(sol)       #> TRUE
sat_assignment(sol)   #> named logical vector
subset(sol, value)    #> just the true variables
```

The shape is the same whether or not the formula was satisfiable — an
unsatisfiable result is a data frame with no rows, not a different type — so
you can index it without branching first. `NA` marks a variable the solver
left unassigned because either polarity extends the model.

``` r
sat_solve(list(1, -1))
#> <zusat_solution> unsat  (1 variable, 0 active clauses, 0.000s)
```

## Enumerating solutions

``` r
sat_solutions(list(c(1, 2)))
#> <zusat_solutions> sat  (3 solutions)
#>  solution variable value
#>         1        1  TRUE
#>         1        2  TRUE
#>         2        1 FALSE
#>         2        2  TRUE
#>         3        1  TRUE
#>         3        2 FALSE
```

Encodings introduce auxiliary variables, and models that differ only in those
are usually the same answer repeated. `vars` projects onto the variables you
care about, so each distinct assignment of them is returned once:

``` r
sat_n_solutions(sat_solutions(list(c(1, 2)), vars = 1:3))  #> 6
sat_n_solutions(sat_solutions(list(c(1, 2)), vars = 1:2))  #> 3
```

Enumeration stops at `limit` (1000 by default, because the count is usually
exponential). Check whether it finished:

``` r
sols <- sat_solutions(cnf, limit = 100)
sat_complete(sols)   #> FALSE means there may be more
```

## Incremental solving

A solver keeps its state, so adding a clause and re-solving reuses everything
already learned. This is where CaDiCaL earns its keep over a one-shot call.

``` r
s <- sat_solver(list(c(1, 2)))

sat_solve(s)         #> sat
sat_add(s, -1)       # one clause
sat_add(s, -2)       # ...
sat_solve(s)         #> unsat
```

`sat_solve()` works on a formula or a solver, so the calling code reads the
same either way.

### Assumptions

Assumptions hold for a single call. When the result is unsatisfiable,
`sat_failed()` reports which of them the solver actually used — an
unsatisfiable core over the assumptions:

``` r
s <- sat_solver(list(c(1, 2)))

sat_solve(s, assumptions = c(-1, -2))   #> unsat
sat_failed(s, c(-1, -2))                #> TRUE TRUE

sat_solve(s)                            #> sat — assumptions did not persist
```

CaDiCaL does not expose cores over the original *clauses*, only over
assumptions. If you need to know which clauses conflict, encode each one with
a selector variable and assume the selectors.

### Bounding a solve

SAT is NP-complete, so an innocuous-looking formula can run far longer than
you are willing to wait. A limit makes the solver give up and return
`"unknown"` instead of an answer:

``` r
s <- sat_solver(hard_formula)
sat_limit(s, "conflicts", 10000)

sol <- sat_solve(s)
if (sat_status(sol) == "unknown") {
  # gave up within budget -- not the same as unsatisfiable
}
```

Like assumptions, a limit applies to the next `sat_solve()` only.

### Temporary constraints

Assumptions fix individual literals. A constraint is a whole clause that
applies to one solve and is then discarded — useful for asking "what if at
least one of these were false?" without permanently changing the formula:

``` r
s <- sat_solver(list(c(1, 2)))

sat_constrain(s, c(-1, -2))   # at least one of x1, x2 false
sat_solve(s)
sat_constraint_failed(s)      # did the constraint cause unsat?

sat_solve(s)                  # constraint is gone
```

### What the solver has already proved

`sat_fixed()` reports literals true in every model, or false in every model —
the formula's backbone as far as the solver has discovered it:

``` r
s <- sat_solver(list(1, c(-1, 2)))
sat_solve(s)

sat_fixed(s, c(1, 2, 3))   #> TRUE TRUE NA
```

`sat_simplify()` runs CaDiCaL's inprocessing without searching, which
occasionally settles a formula outright and otherwise leaves it smaller.

### Tuning

CaDiCaL has several hundred integer options:

``` r
sat_option(s, "elim")        # read
sat_option(s, "elim", 0)     # disable bounded variable elimination
```

## Interrupting

Long solves respond to Ctrl-C. The solver stops at its next safe point and
raises a catchable error; the handle stays usable afterwards.

## Updating the bundled solver

`tools/vendor-cadical.sh [git-ref]` re-vendors CaDiCaL from upstream, applies
the R compatibility rewrites, and records the exact commit, a manifest and
per-file checksums. `tools/vendor/verify` checks the tree against them.

## Licence

zusat is MIT licensed. The bundled CaDiCaL is also MIT licensed — see
`inst/CADICAL_LICENSE` and `inst/COPYRIGHTS`.
