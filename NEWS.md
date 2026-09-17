# zusat 0.0.0.9000

* Initial version: R bindings for the bundled CaDiCaL SAT solver.
* `sat_solve()` solves a formula or an incremental solver, returning a
  type-stable data frame of variable assignments.
* `sat_solutions()` enumerates models, with `vars` to project onto the
  variables that matter.
