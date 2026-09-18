# Add several clauses at once

Add several clauses at once

## Usage

``` r
sat_add_all(solver, clauses)
```

## Arguments

- solver:

  A `zusat_solver`.

- clauses:

  A list of integer vectors, each one a clause.

## Value

`solver`, invisibly.

## Examples

``` r
s <- sat_solver()
sat_add_all(s, list(c(1L, 2L), c(-1L, 2L)))
```
