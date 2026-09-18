# Size of the formula a solver holds

`sat_n_clauses()` reports CaDiCaL's count of *active* original clauses,
which is not the same as the number passed to
[`sat_add()`](https://pedrobtz.github.io/zusat/reference/sat_add.md).
Clauses the solver learned during search are excluded, being an artefact
of search rather than of the formula. So are clauses it has since
disposed of: a unit clause becomes a fixed assignment and stops being
counted, and simplification removes others. Adding `1` and `-1` and then
solving therefore leaves a count of zero.

## Usage

``` r
sat_n_vars(solver)

sat_n_clauses(solver)
```

## Arguments

- solver:

  A `zusat_solver`.

## Value

A single number.

## Details

If you need the number of clauses you supplied, count them yourself –
the solver does not keep that figure.

## Examples

``` r
s <- sat_solver(list(c(1, 2), c(-1, 3)))
sat_n_vars(s)
#> [1] 3
sat_n_clauses(s)
#> [1] 2
```
