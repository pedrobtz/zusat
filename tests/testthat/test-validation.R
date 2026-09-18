# Regression tests for a code review of the C boundary and the R validation
# layer. Every case here is one the review demonstrated: each either killed
# the R session, corrupted memory, or returned a confident wrong answer
# rather than raising.

# --- literal magnitude ------------------------------------------------------
#
# CaDiCaL allocates variable arrays densely up to the largest index it has
# seen, and its own input check rejects only INT_MIN. Before the bound,
# sat_add(s, .Machine$integer.max) killed the R process outright -- SIGKILL,
# no error, nothing to catch. That is why this is checked in R rather than
# left to the solver.

test_that("a literal beyond the maximum variable index is rejected", {
  s <- sat_solver()
  expect_error(sat_add(s, .Machine$integer.max), "at most")
  expect_error(sat_add(s, 3e9), "at most")
  expect_error(sat_add(s, -3e9), "at most")
})

test_that("the maximum variable index itself is usable", {
  # the boundary has to work, not merely fail politely one past it
  limit <- .Call(zusat_max_var_get)
  s <- sat_solver()
  expect_silent(sat_add(s, limit))
  expect_equal(sat_n_vars(s), limit)
})

test_that("non-finite literals are rejected before coercion", {
  # trunc(Inf) is Inf, so Inf passed the whole-number test and became NA in
  # as.integer(), surfacing as "missing value where TRUE/FALSE needed"
  s <- sat_solver()
  expect_error(sat_add(s, Inf), "must be finite")
  expect_error(sat_add(s, -Inf), "must be finite")
  expect_error(sat_add(s, NaN), "must not be NA")
})

test_that("rejected literals leave no warning behind", {
  # the coercion warning was the symptom of the value travelling further
  # than it should have
  s <- sat_solver()
  expect_silent(try(sat_add(s, 3e9), silent = TRUE))
  expect_silent(try(sat_add(s, Inf), silent = TRUE))
})

test_that("assumptions and constraints share the literal bound", {
  s <- sat_solver(list(c(1, 2)))
  expect_error(sat_solve(s, assumptions = 3e9), "at most")
  expect_error(sat_constrain(s, 3e9), "at most")
  expect_error(sat_at_most(s, c(1, 3e9), 1), "at most")
})

# --- sat_value: variable numbers, not raw coercion --------------------------

test_that("sat_value rejects what as.integer() would have coerced", {
  s <- sat_solver(list(1))
  sat_solve(s)
  expect_error(sat_value(s, "1"), "must be numeric")
  expect_error(sat_value(s, 1.5), "whole numbers")
  expect_error(sat_value(s, 0), "must not contain 0")
})

test_that("sat_value rejects a negative literal", {
  # it silently returned the negated value, while the help says the argument
  # is a variable index
  s <- sat_solver(list(1))
  sat_solve(s)
  expect_error(sat_value(s, -1), "not negative literals")
})

test_that("sat_value reports NA for a variable the solver has never seen", {
  # it returned FALSE -- a confident answer about a variable the formula does
  # not mention. NA is the truthful reading, and matches how an unassigned
  # variable already reads. Not an error: projecting onto a free variable is
  # legitimate, and sat_solutions() depends on it.
  s <- sat_solver(list(1))
  sat_solve(s)
  expect_true(is.na(sat_value(s, 999)))
})

# --- state guards -----------------------------------------------------------
#
# These all reached CaDiCaL's REQUIRE macros, which report through
# __PRETTY_FUNCTION__ and an internal file name: the user saw
# "CaDiCaL aborted (cadical/solver.cpp:892)".

test_that("reading a model before solving is an error, not a contract violation", {
  s <- sat_solver(list(c(1, 2)))
  expect_error(sat_value(s, 1), "call sat_solve")
})

test_that("reading a model after unsat is an error", {
  s <- sat_solver(list(1, -1))
  expect_equal(sat_status(sat_solve(s)), "unsat")
  expect_error(sat_value(s, 1), "no model available")
})

test_that("failed assumptions after a satisfiable solve is an error", {
  s <- sat_solver(list(1))
  expect_true(sat_is_sat(sat_solve(s, assumptions = 1)))
  expect_error(sat_failed(s, 1), "returned \"unsat\"")
})

test_that("constraint_failed needs an unsatisfiable solve", {
  s <- sat_solver(list(c(1, 2)))
  sat_solve(s)
  expect_error(sat_constraint_failed(s), "returned \"unsat\"")
})

test_that("tracing is refused after a solve, not only after a clause", {
  # the guard tested sat_n_vars() > 0, which a solve on an empty solver
  # leaves at 0 -- so this reached CaDiCaL and leaked the open file
  s <- sat_solver()
  sat_solve(s)
  expect_error(sat_trace_proof(s, tempfile()), "before adding clauses or solving")
})

test_that("a refused trace leaves the solver usable and unTraced", {
  s <- sat_solver()
  sat_solve(s)
  try(sat_trace_proof(s, tempfile()), silent = TRUE)

  expect_false(sat_is_tracing(s))
  sat_add(s, list(c(1, 2)))
  expect_true(sat_is_sat(sat_solve(s)))
})

test_that("setting an option after clauses is an error, not a contract violation", {
  # Solver::set requires CONFIGURING for everything except the reporting
  # options, so this reached CaDiCaL and aborted through its internals
  s <- sat_solver(list(c(1, 2)))
  expect_error(sat_option(s, "elim", 0), "freshly created solver")
})

test_that("the reporting options stay settable at any time", {
  # CaDiCaL exempts these four from the CONFIGURING requirement
  s <- sat_solver(list(c(1, 2)))
  sat_solve(s)
  for (opt in c("quiet", "report", "verbose")) {
    expect_silent(sat_option(s, opt, 0))
  }
})

test_that("reading an option is unrestricted", {
  s <- sat_solver(list(c(1, 2)))
  sat_solve(s)
  expect_type(sat_option(s, "elim"), "integer")
})

# --- enumeration ------------------------------------------------------------

test_that("limit = 0 reports unknown, not unsat", {
  # status was initialised to "unsat" and the loop never ran, so a
  # satisfiable formula was reported unsatisfiable without a solve
  sols <- sat_solutions(list(c(1, 2)), limit = 0)

  expect_equal(sat_status(sols), "unknown")
  expect_equal(sat_n_solutions(sols), 0L)
  expect_false(sat_complete(sols))
})

test_that("limit = 0 on an unsatisfiable formula is also unknown", {
  # nothing was computed either way; the formula's status is not the point
  expect_equal(sat_status(sat_solutions(list(1, -1), limit = 0)), "unknown")
})

test_that("a genuinely exhausted enumeration is still complete", {
  sols <- sat_solutions(list(c(1, 2)), limit = 100)
  expect_equal(sat_status(sols), "sat")
  expect_true(sat_complete(sols))
})

test_that("repeated variables in vars do not multiply the rows", {
  sols <- sat_solutions(list(c(1, 2)), vars = c(1, 1, 2))

  expect_equal(sat_n_solutions(sols), 3L)
  expect_equal(nrow(sols) / sat_n_solutions(sols), 2) # two distinct variables
  expect_setequal(unique(sols$variable), c(1L, 2L))
})

test_that("projecting onto a free variable enumerates both polarities", {
  # a variable the formula never constrains doubles the answer set, which is
  # the documented behaviour sat_solutions() relies on -- so vars is not
  # bounded by what the solver currently knows
  constrained <- sat_solutions(list(c(1, 2)), vars = 1:2)
  with_free <- sat_solutions(list(c(1, 2)), vars = 1:3)

  expect_equal(sat_n_solutions(constrained), 3L)
  expect_equal(sat_n_solutions(with_free), 6L)
})

# --- cardinality ------------------------------------------------------------

test_that("a repeated variable in a cardinality constraint is rejected", {
  # the pairwise encoding emitted (-1 | -1), a unit clause forcing x1 false,
  # so at_most(c(1,1,2), 1) quietly made x1 unsatisfiable
  s <- sat_solver()
  expect_error(sat_at_most(s, c(1, 1, 2), 1), "must not repeat")
  expect_error(sat_at_least(s, c(1, 1, 2), 1), "must not repeat")
  expect_error(sat_exactly(s, c(1, 1, 2), 1), "must not repeat")
})

test_that("a variable and its negation together are also rejected", {
  s <- sat_solver()
  expect_error(sat_at_most(s, c(1, -1), 1), "must not repeat")
})

test_that("distinct literals are still accepted", {
  s <- sat_solver()
  expect_silent(sat_at_most(s, c(1, -2, 3), 1))
})

# --- DIMACS -----------------------------------------------------------------

test_that("an out-of-range literal names the file rather than becoming NA", {
  # it coerced to NA with only a warning, the file appeared to read, and the
  # failure surfaced later from sat_add() with no mention of the source
  path <- tempfile(fileext = ".cnf")
  writeLines(c("p cnf 2 2", "1 3000000000 0", "-1 0"), path)

  expect_error(read_dimacs(path), "beyond the maximum variable index")
  expect_error(read_dimacs(path), basename(path))
  expect_silent(try(read_dimacs(path), silent = TRUE))
})

# --- sat_solve input --------------------------------------------------------

test_that("a data frame is rejected rather than solved column by column", {
  # is.list() is TRUE for a data frame, so this was accepted silently
  expect_error(sat_solve(data.frame(a = c(1, 2))), "list of clauses")
})

test_that("a solution object is rejected as input", {
  # a zusat_solution is a data frame, so it hit the same path
  sol <- sat_solve(list(c(1, 2)))
  expect_error(sat_solve(sol), "list of clauses")
})

# --- terminator lifetime ----------------------------------------------------
#
# The interrupt flag handed to ccadical_set_terminate() used to be a stack
# slot in zusat_solve(). ccadical_solve() can exit by longjmp -- a contract
# violation now raises an R error -- which skips the line that clears the
# terminator, leaving CaDiCaL holding a dead stack address. Inprocessing polls
# the terminator from two dozen modules, so the next sat_simplify() would
# write through it. The flag now lives in the handle, where its address is
# valid for as long as the solver is.
#
# The triggering path is hard to construct from R, so these exercise the
# lifetime rather than the crash: repeated interleaving of the calls that
# install and read the terminator, which under gctorture and rchk in CI is
# where a stale pointer would show.

test_that("solve and simplify interleave without disturbing each other", {
  s <- sat_solver(list(c(1, 2), c(-1, 3), c(-2, 3)))

  for (i in 1:5) {
    expect_true(sat_is_sat(sat_solve(s)))
    expect_equal(sat_simplify(s), "unknown")
  }
  expect_true(sat_is_sat(sat_solve(s)))
})

test_that("simplify reports its own status and leaves the formula intact", {
  s <- sat_solver(list(1, -1))
  expect_equal(sat_simplify(s), "unsat")
  expect_equal(sat_status(sat_solve(s)), "unsat")
})

test_that("a solver survives many solves without leaking the terminator", {
  s <- sat_solver(list(c(1, 2)))
  for (i in 1:20) sat_solve(s, assumptions = if (i %% 2) 1 else -1)
  expect_true(sat_is_sat(sat_solve(s)))
})
