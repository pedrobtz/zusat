# A solution as a named logical vector

Convenient when a model is used to index or subset, where the data frame
is more structure than the task needs.

## Usage

``` r
sat_assignment(x)
```

## Arguments

- x:

  A
  [zusat_solution](https://pedrobtz.github.io/zusat/reference/zusat_solution.md).

## Value

A logical vector named by variable number, empty when the formula was
not satisfiable. `NA` marks a variable the solver left unassigned
because either polarity extends the model.

## Examples

``` r
sol <- sat_solve(list(c(1, 2), c(-1, 3)))
sat_assignment(sol)
#>    1    2    3 
#> TRUE TRUE TRUE 
```
