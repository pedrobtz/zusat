# Write the concluding proof step

Emits the conclusion of the last solve into the proof. Only meaningful
for the interactive formats (IDRUP and LIDRUP), where a proof records a
whole session of solves rather than a single refutation. For DRAT and
LRAT the refutation already ends the proof and this does nothing.

## Usage

``` r
sat_conclude(solver)
```

## Arguments

- solver:

  A `zusat_solver`.

## Value

`solver`, invisibly.

## Examples

``` r
# a no-op for DRAT, but harmless and shown here for the call shape
path <- tempfile(fileext = ".drat")
s <- sat_solver()
sat_trace_proof(s, path)
sat_add(s, list(1, -1))
sat_solve(s)
#> <zusat_solution> unsat  (1 variable, 0 active clauses, 0.000s)
sat_conclude(s)
sat_close_proof(s)
```
