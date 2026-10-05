# Reserve variable numbers before adding cardinality constraints

Declares variables `1` to `n` to the solver without adding any clause,
so that the auxiliary variables later cardinality constraints introduce
are allocated above them. Call it with the number of variables your
model uses, before the first
[`sat_at_most()`](https://pedrobtz.github.io/zusat/reference/cardinality.md),
[`sat_at_least()`](https://pedrobtz.github.io/zusat/reference/cardinality.md)
or
[`sat_exactly()`](https://pedrobtz.github.io/zusat/reference/cardinality.md).

## Usage

``` r
sat_reserve(solver, n)
```

## Arguments

- solver:

  A `zusat_solver`.

- n:

  The number of variables to reserve. Reserving fewer than the solver
  already knows does nothing; reserving into a range already used for
  auxiliary variables is an error.

## Value

`solver`, invisibly.

## Details

Without it, an encoding allocates above the variables in use so far, and
a variable you introduce afterwards can land on one of its auxiliaries.
The package refuses such a variable rather than let the two silently
merge, and that error is what this function avoids.

Like adding a clause, this moves the solver out of its initial
configuration state, so call
[`sat_trace_proof()`](https://pedrobtz.github.io/zusat/reference/sat_trace_proof.md)
and set options with
[`sat_option()`](https://pedrobtz.github.io/zusat/reference/sat_option.md)
first. It also invalidates the model of an earlier solve.

## See also

[cardinality](https://pedrobtz.github.io/zusat/reference/cardinality.md)

## Examples

``` r
s <- sat_solver()
sat_reserve(s, 24)
sat_exactly(s, 1:12, 1)
sat_exactly(s, 13:24, 1)
sat_n_vars(s) # 24 of ours, then the auxiliaries
#> [1] 46
```
