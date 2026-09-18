# Add a clause to a solver

Clauses use DIMACS conventions: a positive integer `i` is the literal
"variable i is true", a negative integer `-i` is its negation. Do not
include a terminating zero; that is added internally.

## Usage

``` r
sat_add(solver, literals)
```

## Arguments

- solver:

  A `zusat_solver` from
  [`sat_solver()`](https://pedrobtz.github.io/zusat/reference/sat_solver.md).

- literals:

  Integer vector of non-zero literals. An empty vector adds the empty
  clause, which makes the formula unsatisfiable.

## Value

`solver`, invisibly, so calls can be chained.

## Examples

``` r
s <- sat_solver()
sat_add(s, c(1L, -2L))
```
