# Which assumptions caused unsatisfiability

After
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
returns `"unsat"` for a call made with assumptions, this reports the
subset the solver actually used to derive the conflict.

## Usage

``` r
sat_failed(solver, assumptions)
```

## Arguments

- solver:

  A `zusat_solver`.

- assumptions:

  The same literals passed to
  [`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md).

## Value

A logical vector marking the assumptions that were used.

## Details

It is an unsatisfiable core over the *assumptions*, not over the
clauses. CaDiCaL does not expose clause-level cores, so unlike some
solvers there is no way to ask which of the original clauses are jointly
contradictory.

## Examples

``` r
s <- sat_solver(list(c(1, 2)))
sat_solve(s, assumptions = c(-1, -2))
#> <zusat_solution> unsat  (2 variables, 1 active clause, 0.000s)
sat_failed(s, c(-1, -2))
#> [1] TRUE TRUE
```
