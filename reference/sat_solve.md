# Solve the current formula

Long solves can be interrupted with Ctrl-C; the solver stops at its next
safe point and the handle stays usable.

## Usage

``` r
sat_solve(solver, assumptions = integer())
```

## Arguments

- solver:

  A `zusat_solver`.

- assumptions:

  Integer vector of literals assumed true for this call only.
  Assumptions are not retained across calls.

## Value

One of `"sat"`, `"unsat"`, or `"unknown"`.

## Examples

``` r
s <- sat_solver()
sat_add(s, c(1L, 2L))
sat_solve(s)
#> [1] "sat"
sat_solve(s, assumptions = -1L)
#> [1] "sat"
```
