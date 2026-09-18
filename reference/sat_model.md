# Read variable assignments from a satisfying model

Only meaningful directly after
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
returned `"sat"`.

## Usage

``` r
sat_model(solver, vars = seq_len(sat_n_vars(solver)))
```

## Arguments

- solver:

  A `zusat_solver`.

- vars:

  Integer vector of variable indices. Defaults to all variables known to
  the solver.

## Value

A logical vector the same length as `vars`. `NA` marks a variable the
solver left unassigned because either polarity extends the model.

## Examples

``` r
s <- sat_solver()
sat_add(s, c(1L, 2L))
if (sat_solve(s) == "sat") sat_model(s)
#> [1] TRUE TRUE
```
