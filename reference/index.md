# Package index

## Solving

Solve a formula directly, or build one up incrementally.

- [`sat_solver()`](https://pedrobtz.github.io/zusat/reference/sat_solver.md)
  : Create a CaDiCaL solver
- [`sat_add()`](https://pedrobtz.github.io/zusat/reference/sat_add.md) :
  Add clauses to a solver
- [`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
  : Solve a formula
- [`sat_solutions()`](https://pedrobtz.github.io/zusat/reference/sat_solutions.md)
  : Enumerate satisfying assignments

## Reading results

The outcome of a solve, and the model behind it.

- [`sat_status()`](https://pedrobtz.github.io/zusat/reference/sat_status.md)
  [`sat_is_sat()`](https://pedrobtz.github.io/zusat/reference/sat_status.md)
  : The outcome of a solve
- [`sat_assignment()`](https://pedrobtz.github.io/zusat/reference/sat_assignment.md)
  : A solution as a named logical vector
- [`sat_value()`](https://pedrobtz.github.io/zusat/reference/sat_value.md)
  : Read variable assignments directly from a solver
- [`sat_n_solutions()`](https://pedrobtz.github.io/zusat/reference/sat_n_solutions.md)
  [`sat_complete()`](https://pedrobtz.github.io/zusat/reference/sat_n_solutions.md)
  : Number of solutions found, and whether that is all of them
- [`zusat_solution`](https://pedrobtz.github.io/zusat/reference/zusat_solution.md)
  : The result of a solve
- [`zusat_solutions`](https://pedrobtz.github.io/zusat/reference/zusat_solutions.md)
  : The result of an enumeration

## Cardinality constraints

At most, at least, or exactly k of a set of literals – the constraints
most real models are built from.

- [`sat_at_most()`](https://pedrobtz.github.io/zusat/reference/cardinality.md)
  [`sat_at_least()`](https://pedrobtz.github.io/zusat/reference/cardinality.md)
  [`sat_exactly()`](https://pedrobtz.github.io/zusat/reference/cardinality.md)
  : Cardinality constraints

## Steering the search

Assumptions, temporary constraints, resource limits and what the solver
has already proved.

- [`sat_failed()`](https://pedrobtz.github.io/zusat/reference/sat_failed.md)
  : Which assumptions caused unsatisfiability
- [`sat_limit()`](https://pedrobtz.github.io/zusat/reference/sat_limit.md)
  : Bound how hard a solve may work
- [`sat_constrain()`](https://pedrobtz.github.io/zusat/reference/sat_constrain.md)
  : Add a clause that holds for one solve only
- [`sat_constraint_failed()`](https://pedrobtz.github.io/zusat/reference/sat_constraint_failed.md)
  : Did the constraint cause unsatisfiability?
- [`sat_fixed()`](https://pedrobtz.github.io/zusat/reference/sat_fixed.md)
  : Literals the solver has proved outright
- [`sat_simplify()`](https://pedrobtz.github.io/zusat/reference/sat_simplify.md)
  : Simplify a formula without solving it
- [`sat_option()`](https://pedrobtz.github.io/zusat/reference/sat_option.md)
  : Get or set a CaDiCaL option

## Proofs

Make an unsatisfiability claim checkable by an independent tool.

- [`sat_trace_proof()`](https://pedrobtz.github.io/zusat/reference/sat_trace_proof.md)
  : Record a proof of unsatisfiability
- [`sat_close_proof()`](https://pedrobtz.github.io/zusat/reference/sat_close_proof.md)
  : Finish writing a proof
- [`sat_is_tracing()`](https://pedrobtz.github.io/zusat/reference/sat_is_tracing.md)
  : Is this solver recording a proof?
- [`sat_conclude()`](https://pedrobtz.github.io/zusat/reference/sat_conclude.md)
  : Write the concluding proof step

## Files and metadata

- [`read_dimacs()`](https://pedrobtz.github.io/zusat/reference/read_dimacs.md)
  : Read a formula from a DIMACS CNF file
- [`write_dimacs()`](https://pedrobtz.github.io/zusat/reference/write_dimacs.md)
  : Write a formula to a DIMACS CNF file
- [`sat_n_vars()`](https://pedrobtz.github.io/zusat/reference/sat_n_vars.md)
  [`sat_n_clauses()`](https://pedrobtz.github.io/zusat/reference/sat_n_vars.md)
  : Size of the formula a solver holds
- [`sat_signature()`](https://pedrobtz.github.io/zusat/reference/sat_signature.md)
  : Version of the bundled CaDiCaL
- [`zusat`](https://pedrobtz.github.io/zusat/reference/zusat-package.md)
  [`zusat-package`](https://pedrobtz.github.io/zusat/reference/zusat-package.md)
  : zusat: Boolean satisfiability with CaDiCaL
