# Solve a formula

Solves either a formula given directly, or the current state of a
solver. Both return the same kind of object, so code that reads the
result does not need to know which was used.

## Usage

``` r
sat_solve(x, assumptions = integer(), ...)

# S3 method for class 'zusat_solver'
sat_solve(x, assumptions = integer(), ...)

# Default S3 method
sat_solve(x, assumptions = integer(), ...)
```

## Arguments

- x:

  A list of clauses, or a `zusat_solver`.

- assumptions:

  Numeric vector of literals assumed true for this call only.
  Assumptions are never retained between calls. When the result is
  unsatisfiable,
  [`sat_failed()`](https://pedrobtz.github.io/zusat/reference/sat_failed.md)
  reports which of them the solver used.

- ...:

  Passed to methods.

## Value

A
[zusat_solution](https://pedrobtz.github.io/zusat/reference/zusat_solution.md).

## Details

Long solves respond to Ctrl-C. The solver stops at its next safe point
and raises a catchable error; a solver handle stays usable afterwards.

## See also

[`sat_status()`](https://pedrobtz.github.io/zusat/reference/sat_status.md)
to read the outcome,
[`sat_solutions()`](https://pedrobtz.github.io/zusat/reference/sat_solutions.md)
to enumerate more than one model.

## Examples

``` r
# a formula directly
sat_solve(list(c(1, 2), c(-1, 2)))
#> <zusat_solution> sat  (2 variables, 2 active clauses, 0.000s)
#>  variable value
#>         1  TRUE
#>         2  TRUE

# or a solver, for incremental work
s <- sat_solver(list(c(1, 2)))
sat_solve(s, assumptions = -1)
#> <zusat_solution> sat  (2 variables, 1 active clause, 0.000s)
#>  variable value
#>         1 FALSE
#>         2  TRUE
```
