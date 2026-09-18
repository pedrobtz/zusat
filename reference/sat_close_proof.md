# Finish writing a proof

Flushes and closes the proof file. The proof is incomplete until this
returns, so do not read the file before calling it.

## Usage

``` r
sat_close_proof(solver)
```

## Arguments

- solver:

  A `zusat_solver` that is tracing a proof.

## Value

`solver`, invisibly.

## See also

[`sat_trace_proof()`](https://pedrobtz.github.io/zusat/reference/sat_trace_proof.md)

## Examples

``` r
path <- tempfile(fileext = ".drat")
s <- sat_solver()
sat_trace_proof(s, path)
sat_add(s, list(1, -1))
sat_solve(s)
#> <zusat_solution> unsat  (1 variable, 0 active clauses, 0.000s)
sat_close_proof(s)
```
