# Create a CaDiCaL solver

Creates an incremental SAT solver backed by a vendored copy of CaDiCaL.
The returned handle keeps state across calls, so clauses added earlier
remain in effect: this is what makes incremental solving possible.

## Usage

``` r
sat_solver()
```

## Value

An object of class `zusat_solver`.

## Details

The underlying solver is released automatically when the handle is
garbage collected.

## Examples

``` r
s <- sat_solver()
sat_add(s, c(1L, 2L))
sat_solve(s)
#> [1] "sat"
```
