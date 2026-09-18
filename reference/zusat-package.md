# zusat: Boolean satisfiability with CaDiCaL

Solves Boolean satisfiability (SAT) problems using a bundled copy of
CaDiCaL. Nothing needs installing beyond this package and a C++
compiler.

## Getting started

A formula is a list of clauses; a clause is a numeric vector of literals
in DIMACS convention, where `i` means "variable *i* is true" and `-i`
its negation. No terminating zero is needed.

    sat_solve(list(c(1, 2), c(-1, 2)))

The result is a data frame of `variable` and `value`, with the outcome
in an attribute that
[`sat_status()`](https://pedrobtz.github.io/zusat/reference/sat_status.md)
reads. It keeps that shape whether or not the formula was satisfiable,
so you can index it without branching first.

## The harder part

The API is small. Turning a question into clauses is where the work is,
and where mistakes produce a confident wrong answer rather than an
error. The article *Modelling a problem as SAT* works an example through
end to end.

## Map of the package

- Solving:

  [`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
  for a formula or a solver,
  [`sat_solver()`](https://pedrobtz.github.io/zusat/reference/sat_solver.md)
  and
  [`sat_add()`](https://pedrobtz.github.io/zusat/reference/sat_add.md)
  to build one up incrementally,
  [`sat_solutions()`](https://pedrobtz.github.io/zusat/reference/sat_solutions.md)
  to enumerate more than one model.

- Cardinality:

  [`sat_at_most()`](https://pedrobtz.github.io/zusat/reference/cardinality.md),
  [`sat_at_least()`](https://pedrobtz.github.io/zusat/reference/cardinality.md)
  and
  [`sat_exactly()`](https://pedrobtz.github.io/zusat/reference/cardinality.md)
  encode "at most k of these", which CNF cannot state directly and most
  real models need.

- Steering:

  Assumptions via
  [`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md),
  a one-shot clause via
  [`sat_constrain()`](https://pedrobtz.github.io/zusat/reference/sat_constrain.md),
  resource limits via
  [`sat_limit()`](https://pedrobtz.github.io/zusat/reference/sat_limit.md),
  and
  [`sat_fixed()`](https://pedrobtz.github.io/zusat/reference/sat_fixed.md)
  for what the solver has already proved.

- Proofs:

  [`sat_trace_proof()`](https://pedrobtz.github.io/zusat/reference/sat_trace_proof.md)
  records a DRAT or LRAT derivation, so an unsatisfiability claim can be
  checked by a tool that trusts neither CaDiCaL nor this package.

- Files:

  [`read_dimacs()`](https://pedrobtz.github.io/zusat/reference/read_dimacs.md)
  and
  [`write_dimacs()`](https://pedrobtz.github.io/zusat/reference/write_dimacs.md),
  the format every solver and benchmark set speaks.

## Two things that bite

`"unknown"` is not a weaker `"unsat"`. It means the solver stopped
inside a limit set by
[`sat_limit()`](https://pedrobtz.github.io/zusat/reference/sat_limit.md)
without deciding, and the question is still open.

Enumeration stops at `limit`, and a truncated result looks exactly like
an exhaustive one.
[`sat_complete()`](https://pedrobtz.github.io/zusat/reference/sat_n_solutions.md)
is how you tell them apart.

## See also

Useful links:

- <https://pedrobtz.github.io/zusat/>

- <https://github.com/pedrobtz/zusat>

- Report bugs at <https://github.com/pedrobtz/zusat/issues>

## Author

**Maintainer**: Pedro Batista <pedrobtz@gmail.com>

Authors:

- Pedro Batista <pedrobtz@gmail.com>

Other contributors:

- Armin Biere (Author of the bundled CaDiCaL solver) \[copyright
  holder\]

- Mathias Fleury (Author of the bundled CaDiCaL solver) \[copyright
  holder\]

- Katalin Fazekas (Author of the bundled CaDiCaL solver) \[copyright
  holder\]

- Nils Froleyks (Author of the bundled CaDiCaL solver) \[copyright
  holder\]
