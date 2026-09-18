# zusat 0.0.0.9000

* Initial version: R bindings for the bundled CaDiCaL SAT solver.
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
