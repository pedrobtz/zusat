# Identify which assumptions caused unsatisfiability

After
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
returns `"unsat"` for a call made with assumptions, this reports the
subset of those assumptions the solver actually used. It is a small
unsatisfiable core over the assumptions, not over clauses.

## Usage

``` r
sat_failed(solver, assumptions)
```

## Arguments

- solver:

  A `zusat_solver`.

- assumptions:

  The same integer vector passed to
  [`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md).

## Value

A logical vector marking the assumptions that were used.
