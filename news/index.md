# Changelog

## zusat 0.1.0

- First release. Solves Boolean satisfiability problems with a bundled
  copy of the CaDiCaL solver, so no external solver is required.
- [`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
  solves a formula or an incremental solver, returning a type-stable
  data frame of variable assignments.
- [`sat_solutions()`](https://pedrobtz.github.io/zusat/reference/sat_solutions.md)
  enumerates models, with `vars` to project onto the variables that
  matter.
- [`read_dimacs()`](https://pedrobtz.github.io/zusat/reference/read_dimacs.md)
  and
  [`write_dimacs()`](https://pedrobtz.github.io/zusat/reference/write_dimacs.md)
  for the format every solver and benchmark set speaks.
- [`sat_limit()`](https://pedrobtz.github.io/zusat/reference/sat_limit.md)
  bounds how hard a solve may work, so a solve can return `"unknown"`
  rather than running indefinitely.
- [`sat_constrain()`](https://pedrobtz.github.io/zusat/reference/sat_constrain.md)
  adds a clause for one solve only;
  [`sat_fixed()`](https://pedrobtz.github.io/zusat/reference/sat_fixed.md)
  reports literals proved at the root;
  [`sat_simplify()`](https://pedrobtz.github.io/zusat/reference/sat_simplify.md)
  runs inprocessing alone.
- [`sat_at_most()`](https://pedrobtz.github.io/zusat/reference/cardinality.md),
  [`sat_at_least()`](https://pedrobtz.github.io/zusat/reference/cardinality.md)
  and
  [`sat_exactly()`](https://pedrobtz.github.io/zusat/reference/cardinality.md)
  encode cardinality constraints, choosing between a pairwise and a
  sequential-counter encoding automatically.
- [`sat_trace_proof()`](https://pedrobtz.github.io/zusat/reference/sat_trace_proof.md)
  and
  [`sat_close_proof()`](https://pedrobtz.github.io/zusat/reference/sat_close_proof.md)
  record a DRAT or LRAT proof of unsatisfiability, checkable by external
  tools such as `drat-trim`.
