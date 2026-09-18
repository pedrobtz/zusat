# The result of a solve

[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
returns an object of class `zusat_solution`. It *is* a data frame, with
one row per variable and columns:

## Details

- variable:

  integer, the variable number

- value:

  logical, its value in the model. `NA` marks a variable the solver left
  unassigned because either polarity extends the model.

The outcome is carried as an attribute rather than a column, so the
object stays type-stable: an unsatisfiable result is the same data frame
with no rows, not a different type. Calling code can therefore index a
result without first branching on what came back, and a result drops
into dplyr, ggplot2 or a join with no conversion.

Read the outcome with
[`sat_status()`](https://pedrobtz.github.io/zusat/reference/sat_status.md)
or
[`sat_is_sat()`](https://pedrobtz.github.io/zusat/reference/sat_status.md),
never by checking [`nrow()`](https://rdrr.io/r/base/nrow.html): a
satisfiable formula with no variables also has zero rows.

## Attributes

`status` (one of `"sat"`, `"unsat"`, `"unknown"`), `n_vars`, `n_clauses`
and `elapsed` seconds. Prefer the accessors over reading these directly.

## See also

[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md),
[`sat_status()`](https://pedrobtz.github.io/zusat/reference/sat_status.md),
[`sat_assignment()`](https://pedrobtz.github.io/zusat/reference/sat_assignment.md)

## Examples

``` r
sol <- sat_solve(list(c(1, 2)))
class(sol)
#> [1] "zusat_solution" "data.frame"    
sat_status(sol)
#> [1] "sat"
```
