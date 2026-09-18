# A formula hard enough that a small conflict budget cannot finish it.
# Pigeonhole is resolution-hard, so the effort needed grows with the size and
# no amount of clever inprocessing avoids it -- which is exactly what makes it
# a reliable way to provoke a limit.
#
# 7-into-6 is chosen deliberately: unbounded it is decided in about 0.04s,
# but it still needs far more than one conflict, so a 1-conflict budget
# reliably yields "unknown". Larger instances work too and cost the suite
# real time -- 11-into-10 takes roughly 80 seconds to decide.
pigeonhole <- function(pigeons, holes) {
  v <- function(i, j) (i - 1L) * holes + j
  clauses <- lapply(seq_len(pigeons), function(i) {
    vapply(seq_len(holes), function(j) v(i, j), numeric(1))
  })
  for (j in seq_len(holes)) {
    for (pair in utils::combn(pigeons, 2L, simplify = FALSE)) {
      clauses <- c(clauses, list(c(-v(pair[1], j), -v(pair[2], j))))
    }
  }
  clauses
}

test_that("a conflict limit makes a hard solve give up", {
  # Without this, "unknown" is documented but unreachable: nothing else in
  # the package can produce it.
  s <- sat_solver(pigeonhole(7L, 6L))
  sat_limit(s, "conflicts", 1)

  expect_equal(sat_status(sat_solve(s)), "unknown")
})

test_that("a generous limit still decides an easy formula", {
  s <- sat_solver(list(c(1, 2), c(-1, 2)))
  sat_limit(s, "conflicts", 100000)

  expect_equal(sat_status(sat_solve(s)), "sat")
})

test_that("limits last one solve only", {
  # the same contract as assumptions, and easy to get wrong
  s <- sat_solver(pigeonhole(7L, 6L))

  sat_limit(s, "conflicts", 1)
  expect_equal(sat_status(sat_solve(s)), "unknown")

  # no limit set this time, so it must decide
  expect_equal(sat_status(sat_solve(s)), "unsat")
})

test_that("an unknown result is not a weaker unsat", {
  s <- sat_solver(pigeonhole(7L, 6L))
  sat_limit(s, "conflicts", 1)
  sol <- sat_solve(s)

  expect_false(sat_is_sat(sol))
  expect_equal(sat_status(sol), "unknown")
  expect_equal(nrow(sol), 0L)
})

test_that("a misspelled limit is rejected rather than ignored", {
  # ccadical_limit() discards the flag telling us the name was unknown, so
  # without this check a typo yields an unbounded solve that looks bounded
  s <- sat_solver()
  expect_error(sat_limit(s, "conflict", 10), "unknown limit")
  expect_error(sat_limit(s, "timeout", 10), "unknown limit")
  expect_error(sat_limit(s, c("a", "b"), 10), "single limit name")
  expect_error(sat_limit(s, "conflicts", "many"), "must be a single number")
})

test_that("every documented limit name is accepted", {
  s <- sat_solver(list(c(1, 2)))
  for (name in zusat:::sat_limits) {
    expect_silent(sat_limit(s, name, 1000))
  }
})

test_that("a constraint applies to one solve and is then discarded", {
  s <- sat_solver(list(1)) # x1 must be true

  sat_constrain(s, -1) # ... but require x1 false, just this once
  expect_equal(sat_status(sat_solve(s)), "unsat")

  expect_equal(sat_status(sat_solve(s)), "sat")
})

test_that("a constraint is a clause, not a unit assumption", {
  # at least one of x1, x2 false -- not expressible with assumptions
  s <- sat_solver(list(c(1, 2)))
  sat_constrain(s, c(-1, -2))

  sol <- sat_solve(s)
  expect_true(sat_is_sat(sol))

  m <- sat_value(s, 1:2)
  m[is.na(m)] <- TRUE
  expect_false(all(m)) # the constraint forced at least one false
})

test_that("constraint_failed reports responsibility for unsat", {
  s <- sat_solver(list(1))
  sat_constrain(s, -1)

  expect_equal(sat_status(sat_solve(s)), "unsat")
  expect_true(sat_constraint_failed(s))
})

test_that("an empty constraint makes the next solve unsat", {
  s <- sat_solver(list(c(1, 2)))
  sat_constrain(s, numeric())

  expect_equal(sat_status(sat_solve(s)), "unsat")
  expect_equal(sat_status(sat_solve(s)), "sat")
})

test_that("constraints validate their literals", {
  s <- sat_solver()
  expect_error(sat_constrain(s, c(1, 0)), "must not contain 0")
  expect_error(sat_constrain(s, "1"), "must be numeric")
})

test_that("fixed literals report what the solver has proved", {
  # x1 is a unit, so it is true in every model; x2 follows from it
  s <- sat_solver(list(1, c(-1, 2)))
  expect_true(sat_is_sat(sat_solve(s)))

  expect_true(sat_fixed(s, 1))
  expect_false(sat_fixed(s, -1)) # the negation is refuted
  expect_true(sat_fixed(s, 2))
})

test_that("an undetermined literal is NA, not FALSE", {
  # x4 appears only in a two-literal clause, so neither polarity is forced
  s <- sat_solver(list(c(1, 2), c(4, 5)))
  expect_true(sat_is_sat(sat_solve(s)))

  expect_true(is.na(sat_fixed(s, 4)))
  expect_true(is.na(sat_fixed(s, -4)))
})

test_that("sat_fixed is vectorised and validates input", {
  s <- sat_solver(list(1))
  sat_solve(s)

  expect_length(sat_fixed(s, c(1, -1)), 2L)
  expect_error(sat_fixed(s, 0), "must not contain 0")
})

test_that("simplify runs without deciding an undecidable formula", {
  s <- sat_solver(list(c(1, 2), c(-1, 3), c(-2, 3), c(-3, 4)))
  expect_equal(sat_simplify(s), "unknown")

  # and the formula is still there afterwards
  expect_true(sat_is_sat(sat_solve(s)))
})

test_that("simplify can settle a formula on its own", {
  s <- sat_solver(list(1, -1))
  expect_equal(sat_simplify(s), "unsat")
})

test_that("simplify preserves satisfiability", {
  formula <- list(c(1, 2, -3), c(-1, 3), c(-2, 3), c(1, -2, 3))

  direct <- sat_status(sat_solve(formula))

  s <- sat_solver(formula)
  sat_simplify(s)
  after <- sat_status(sat_solve(s))

  expect_equal(after, direct)
  expect_true(satisfies_all(formula, sat_assignment(sat_solve(s))))
})
