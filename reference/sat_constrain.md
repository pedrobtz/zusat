# Add a clause that holds for one solve only

Assumptions can only fix individual literals. A constraint is a whole
clause – "at least one of these" – that applies to the next
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
and is then discarded.

## Usage

``` r
sat_constrain(solver, literals)
```

## Arguments

- solver:

  A `zusat_solver`.

- literals:

  Numeric vector of non-zero literals. An empty vector sets the empty
  constraint, which makes the next solve unsatisfiable.

## Value

`solver`, invisibly.

## Details

Without this, asking "is the formula satisfiable with at least one of
x1, x2, x3 true?" means permanently adding that clause and then having
no way to take it back.

A solver holds at most one constraint at a time; setting a new one
replaces the last.

## See also

[`sat_constraint_failed()`](https://pedrobtz.github.io/zusat/reference/sat_constraint_failed.md)
to learn whether it caused unsatisfiability.

## Examples

``` r
s <- sat_solver(list(c(1, 2)))

# require at least one of x1, x2 to be false, just this once
sat_constrain(s, c(-1, -2))
sat_solve(s)
#> <zusat_solution> sat  (2 variables, 1 active clause, 0.000s)
#>  variable value
#>         1  TRUE
#>         2 FALSE

# gone again
sat_solve(s)
#> <zusat_solution> sat  (2 variables, 1 active clause, 0.000s)
#>  variable value
#>         1  TRUE
#>         2  TRUE
```
