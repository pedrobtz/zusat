# Is this solver recording a proof?

Is this solver recording a proof?

## Usage

``` r
sat_is_tracing(solver)
```

## Arguments

- solver:

  A `zusat_solver`.

## Value

A single logical.

## Examples

``` r
s <- sat_solver()
sat_is_tracing(s)
#> [1] FALSE
sat_trace_proof(s, tempfile())
sat_is_tracing(s)
#> [1] TRUE
```
