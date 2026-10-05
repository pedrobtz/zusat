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
  several, as a list of such vectors. An empty vector such as
  [`integer()`](https://rdrr.io/r/base/integer.html) is the empty
  clause, which makes the formula unsatisfiable. `NULL` is not a clause
  and is an error, as is a variable a cardinality constraint introduced
  as auxiliary (see
  [`sat_reserve()`](https://pedrobtz.github.io/zusat/reference/sat_reserve.md)).

## Value

`solver`, invisibly, so calls can be chained.

## Details

Every clause is checked before any is added, so an error part-way
through a list leaves the solver as it was.

## Examples

``` r
s <- sat_solver()
sat_add(s, c(1, -2))                    # one clause
sat_add(s, list(c(2, 3), c(-1, 3)))     # several
```
