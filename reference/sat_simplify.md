# Simplify a formula without solving it

Runs CaDiCaL's inprocessing – elimination, subsumption, probing and the
rest – without the search that
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
would do. Occasionally this settles the formula on its own, which is why
it returns a status.

## Usage

``` r
sat_simplify(solver)
```

## Arguments

- solver:

  A `zusat_solver`.

## Value

One of `"sat"`, `"unsat"` or `"unknown"`; `"unknown"` is the usual
outcome and simply means simplification alone did not decide it.

## Details

Worth doing before a long incremental session, or between rounds when
many clauses have been added.

Like
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md),
this consumes any assumptions and limits currently set.

## Examples

``` r
s <- sat_solver(list(c(1, 2), c(-1, 2), c(1, -2)))
sat_simplify(s)
#> [1] "unknown"
sat_solve(s)
#> <zusat_solution> sat  (2 variables, 0 active clauses, 0.000s)
#>  variable value
#>         1  TRUE
#>         2  TRUE
```
