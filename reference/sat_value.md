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
  solver knows about.

## Value

A logical vector the same length as `vars`. `NA` marks a variable the
solver left unassigned because either polarity extends the model.

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
