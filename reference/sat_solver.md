# Create a CaDiCaL solver

Creates an incremental SAT solver backed by a bundled copy of CaDiCaL.
The handle keeps its state across calls, so clauses added earlier stay
in effect. This is what makes incremental solving possible, and it is
the reason to reach for a solver rather than calling
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
on a formula: adding a clause and re-solving reuses everything the
solver already learned.

## Usage

``` r
sat_solver(formula = NULL)
```

## Arguments

- formula:

  Optional list of clauses to seed the solver with, as in
  [`sat_add()`](https://pedrobtz.github.io/zusat/reference/sat_add.md).
  Equivalent to creating an empty solver and adding them.

## Value

An object of class `zusat_solver`.

## Details

The underlying solver is released when the handle is garbage collected.

## See also

[`sat_add()`](https://pedrobtz.github.io/zusat/reference/sat_add.md) to
add clauses,
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
to solve.

## Examples

``` r
s <- sat_solver(list(c(1, 2), c(-1, 2)))
sat_solve(s)
#> <zusat_solution> sat  (2 variables, 2 active clauses, 0.001s)
#>  variable value
#>         1  TRUE
#>         2  TRUE

# incremental: the second solve reuses the first one's work
sat_add(s, -2)
sat_solve(s)
#> <zusat_solution> unsat  (2 variables, 2 active clauses, 0.000s)
```
