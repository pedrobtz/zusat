# Literals the solver has proved outright

Reports which literals are fixed at the root of the search: true in
every model, or false in every model. This is the formula's *backbone*
as far as the solver has discovered it, and unlike
[`sat_value()`](https://pedrobtz.github.io/zusat/reference/sat_value.md)
it does not depend on a particular model.

## Usage

``` r
sat_fixed(solver, literals)
```

## Arguments

- solver:

  A `zusat_solver`.

- literals:

  Numeric vector of literals to ask about.

## Value

A logical vector: `TRUE` where the literal is implied, `FALSE` where its
negation is implied, `NA` where neither has been established.

## Details

Useful for reading off what is already forced before deciding what to
ask next, and for simplifying a problem between rounds.

The answer grows as the solver learns: a literal reported `NA` now may
be fixed after another
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
or
[`sat_simplify()`](https://pedrobtz.github.io/zusat/reference/sat_simplify.md).
It is what has been proved so far, not everything that is true.

## Examples

``` r
s <- sat_solver(list(1, c(-1, 2)))
sat_solve(s)
#> <zusat_solution> sat  (2 variables, 0 active clauses, 0.000s)
#>  variable value
#>         1  TRUE
#>         2  TRUE
sat_fixed(s, c(1, 2, -1))
#> [1]  TRUE  TRUE FALSE
```
