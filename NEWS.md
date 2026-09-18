# zusat 0.1.0

* First release. Solves Boolean satisfiability problems with a bundled
  copy of the CaDiCaL solver, so no external solver is required.
* `sat_solve()` solves a formula or an incremental solver, returning a
  type-stable data frame of variable assignments.
* `sat_solutions()` enumerates models, with `vars` to project onto the
  variables that matter.
* `read_dimacs()` and `write_dimacs()` for the format every solver and
  benchmark set speaks.
* `sat_limit()` bounds how hard a solve may work, so a solve can return
  `"unknown"` rather than running indefinitely.
* `sat_constrain()` adds a clause for one solve only; `sat_fixed()` reports
  literals proved at the root; `sat_simplify()` runs inprocessing alone.
* `sat_at_most()`, `sat_at_least()` and `sat_exactly()` encode cardinality
  constraints, choosing between a pairwise and a sequential-counter encoding
  automatically.
* `sat_trace_proof()` and `sat_close_proof()` record a DRAT or LRAT proof of
  unsatisfiability, checkable by external tools such as `drat-trim`.
