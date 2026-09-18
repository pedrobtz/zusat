# The outcome of a solve

The outcome of a solve

## Usage

``` r
sat_status(x)

sat_is_sat(x)
```

## Arguments

- x:

  A
  [zusat_solution](https://pedrobtz.github.io/zusat/reference/zusat_solution.md)
  or
  [zusat_solutions](https://pedrobtz.github.io/zusat/reference/zusat_solutions.md)
  object.

## Value

`sat_status()` returns one of `"sat"`, `"unsat"` or `"unknown"`.
`sat_is_sat()` returns `TRUE` only for `"sat"`.

`"unknown"` means the solver stopped before deciding, which happens when
a resource limit was set. It is not a weaker `"unsat"`.

## Examples

``` r
sol <- sat_solve(list(c(1, 2)))
sat_status(sol)
#> [1] "sat"
sat_is_sat(sol)
#> [1] TRUE
```
