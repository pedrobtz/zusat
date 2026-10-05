# Read variable assignments directly from a solver

A lower-level alternative to the data frame returned by
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md),
for when only a few variables matter or the allocation shows up in a
profile. Meaningful only directly after a solve returned `"sat"`.

## Usage

``` r
sat_value(solver, vars = seq_len(sat_n_vars(solver)))
```

## Arguments

- solver:

  A `zusat_solver`.

- vars:

  Numeric vector of variable indices. Defaults to every variable the
  solver knows about. The model is invalidated by anything that changes
  the formula or the next solve –
  [`sat_add()`](https://pedrobtz.github.io/zusat/reference/sat_add.md),
  [`sat_constrain()`](https://pedrobtz.github.io/zusat/reference/sat_constrain.md),
  [`sat_reserve()`](https://pedrobtz.github.io/zusat/reference/sat_reserve.md)
  – so read it before making such a call, or solve again.

## Value

A logical vector the same length as `vars`. Every variable up to
[`sat_n_vars()`](https://pedrobtz.github.io/zusat/reference/sat_n_vars.md)
has a value, including one the formula never constrains (either value
would do, and the solver picks one). `NA` marks a variable above
[`sat_n_vars()`](https://pedrobtz.github.io/zusat/reference/sat_n_vars.md),
which the solver has never seen. To learn which variables are forced
rather than merely chosen, see
[`sat_fixed()`](https://pedrobtz.github.io/zusat/reference/sat_fixed.md).

## Examples

``` r
s <- sat_solver(list(c(1, 2)))
sat_solve(s)
#> <zusat_solution> sat  (2 variables, 1 active clause, 0.000s)
#>  variable value
#>         1  TRUE
#>         2  TRUE
sat_value(s, 1:2)
#> [1] TRUE TRUE
```
