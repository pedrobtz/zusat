# Add clauses to a solver

Clauses use DIMACS conventions: a positive number `i` is the literal
"variable i is true", a negative number `-i` is its negation. No
terminating zero is needed; it is added internally.

## Usage

``` r
sat_add(solver, x)
```

## Arguments

- solver:

  A `zusat_solver` from
  [`sat_solver()`](https://pedrobtz.github.io/zusat/reference/sat_solver.md).

- x:

  Either one clause, as a numeric vector of non-zero literals, or
  several, as a list of such vectors. An empty vector is the empty
  clause, which makes the formula unsatisfiable.

## Value

`solver`, invisibly, so calls can be chained.

## Examples

``` r
s <- sat_solver()
sat_add(s, c(1, -2))                    # one clause
sat_add(s, list(c(2, 3), c(-1, 3)))     # several
```
