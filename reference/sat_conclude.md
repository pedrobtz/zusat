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
