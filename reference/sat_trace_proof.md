# Record a proof of unsatisfiability

When a solver reports `"unsat"` you are taking its word for it. A proof
makes the claim checkable: CaDiCaL writes every step of the derivation
to a file, and an independent checker can verify that the empty clause
really does follow from your formula. Nothing about zusat, CaDiCaL or
this binding has to be trusted for that check to be meaningful.

## Usage

``` r
sat_trace_proof(solver, path, format = c("drat", "lrat"), binary = FALSE)
```

## Arguments

- solver:

  A `zusat_solver` with no clauses added yet.

- path:

  File to write the proof to. Overwritten if it exists.

- format:

  `"drat"` or `"lrat"`.

- binary:

  Write the binary encoding of the format. Smaller, but not readable and
  not accepted by every checker; the default writes text.

## Value

`solver`, invisibly.

## Details

A satisfiable formula needs no proof, because the model is the evidence
– you can check it yourself with
[`sat_assignment()`](https://pedrobtz.github.io/zusat/reference/sat_assignment.md).

## Tracing must start before any clause is added

CaDiCaL requires the solver to be freshly created. Add a clause first
and it refuses, because the proof would record only part of the
derivation and a partial proof is worse than none – it looks checkable
and is not. So trace first, then build the formula:

    s <- sat_solver()          # no formula yet
    sat_trace_proof(s, path)
    sat_add(s, clauses)        # now build it
    sat_solve(s)
    sat_close_proof(s)

Passing a formula to
[`sat_solver()`](https://pedrobtz.github.io/zusat/reference/sat_solver.md)
counts as adding clauses, so create the solver empty when you intend to
trace.

## Closing the file

The proof is not complete until
[`sat_close_proof()`](https://pedrobtz.github.io/zusat/reference/sat_close_proof.md)
returns. CaDiCaL buffers its output, so reading the file before then
gives a truncated proof that most checkers will reject. If a solver is
garbage collected while still tracing, the file is closed then instead.

## Formats

- `"drat"`:

  The default, and what nearly every checker reads – `drat-trim` being
  the usual one. Compact, but a checker has to reconstruct the reasoning
  for each step, which can take longer than the original solve.

- `"lrat"`:

  Records the antecedents of every step, so a checker verifies it by
  simple lookup rather than by re-deriving anything. Larger files, far
  faster and simpler to check, and the format used where the check
  itself has to be trusted.

Other formats CaDiCaL supports – FRAT, VeriPB, IDRUP, LIDRUP – are
reachable by setting the corresponding option with
[`sat_option()`](https://pedrobtz.github.io/zusat/reference/sat_option.md)
before calling this.

## See also

[`sat_close_proof()`](https://pedrobtz.github.io/zusat/reference/sat_close_proof.md),
[`sat_is_tracing()`](https://pedrobtz.github.io/zusat/reference/sat_is_tracing.md)

## Examples

``` r
path <- tempfile(fileext = ".drat")

s <- sat_solver()
sat_trace_proof(s, path)
sat_add(s, list(1, -1)) # contradictory
sat_solve(s)
#> <zusat_solution> unsat  (1 variable, 0 active clauses, 0.000s)
sat_close_proof(s)

# the proof ends with the empty clause, written as a bare "0"
tail(readLines(path), 1)
#> [1] "d -1 0"
```
