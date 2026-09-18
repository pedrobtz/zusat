test_that("a formula can be solved without a solver object", {
  sol <- sat_solve(list(c(1, 2), c(-1, 2)))

  expect_s3_class(sol, "zusat_solution")
  expect_equal(sat_status(sol), "sat")
  expect_true(sat_is_sat(sol))
})

test_that("contradictions are unsat", {
  sol <- sat_solve(list(1, -1))

  expect_equal(sat_status(sol), "unsat")
  expect_false(sat_is_sat(sol))
})

test_that("the empty clause makes a formula unsat", {
  expect_equal(sat_status(sat_solve(list(numeric()))), "unsat")
})

test_that("a solution is a data frame whether or not it is satisfiable", {
  # type stability is the reason for this shape: calling code can index the
  # result without first branching on the status
  sat <- sat_solve(list(c(1, 2)))
  unsat <- sat_solve(list(1, -1))

  expect_s3_class(sat, "data.frame")
  expect_s3_class(unsat, "data.frame")
  expect_named(sat, c("variable", "value"))
  expect_named(unsat, c("variable", "value"))
  expect_equal(nrow(unsat), 0L)
})

test_that("the returned model satisfies every clause", {
  formula <- list(c(1, 2, -3), c(-1, 3), c(-2, 3), c(1, -2, 3))
  sol <- sat_solve(formula)
  expect_true(sat_is_sat(sol))

  expect_true(satisfies_all(formula, sat_assignment(sol)))
})

test_that("solving is incremental across calls", {
  s <- sat_solver(list(c(1, 2)))
  expect_true(sat_is_sat(sat_solve(s)))

  sat_add(s, -1)
  sat_add(s, -2)
  expect_equal(sat_status(sat_solve(s)), "unsat")
})

test_that("a solver can be seeded with a formula", {
  seeded <- sat_solver(list(c(1, 2), c(-1, 2)))
  built <- sat_solver()
  sat_add(built, list(c(1, 2), c(-1, 2)))

  expect_equal(sat_n_vars(seeded), sat_n_vars(built))
  expect_equal(sat_n_clauses(seeded), sat_n_clauses(built))
})

test_that("sat_add takes one clause or many", {
  one <- sat_solver()
  sat_add(one, c(1, 2))
  expect_equal(sat_n_clauses(one), 1)

  many <- sat_solver()
  sat_add(many, list(c(1, 2), c(-1, 3), c(2, 3)))
  expect_equal(sat_n_clauses(many), 3)
})

test_that("assumptions apply to one call only", {
  s <- sat_solver(list(c(1, 2)))

  expect_equal(sat_status(sat_solve(s, assumptions = c(-1, -2))), "unsat")
  expect_true(sat_is_sat(sat_solve(s))) # formula itself is still satisfiable
})

test_that("failed assumptions identify the conflicting subset", {
  s <- sat_solver(list(c(1, 2)))
  assumptions <- c(-1, -2)

  expect_equal(sat_status(sat_solve(s, assumptions = assumptions)), "unsat")

  failed <- sat_failed(s, assumptions)
  expect_type(failed, "logical")
  expect_length(failed, 2L)
  expect_true(any(failed))
})

test_that("pigeonhole instances are unsatisfiable", {
  holes <- 4L
  pigeons <- 5L
  v <- function(i, j) (i - 1L) * holes + j

  clauses <- lapply(seq_len(pigeons), function(i) {
    vapply(seq_len(holes), function(j) v(i, j), numeric(1))
  })
  for (j in seq_len(holes)) {
    for (pair in utils::combn(pigeons, 2L, simplify = FALSE)) {
      clauses <- c(clauses, list(c(-v(pair[1], j), -v(pair[2], j))))
    }
  }

  expect_equal(sat_status(sat_solve(clauses)), "unsat")
})

test_that("variable and clause counts track the formula", {
  s <- sat_solver()
  expect_equal(sat_n_vars(s), 0L)
  expect_equal(sat_n_clauses(s), 0)

  sat_add(s, c(1, 5))
  expect_equal(sat_n_vars(s), 5L)
  expect_equal(sat_n_clauses(s), 1)
})

test_that("sat_value reads the model directly", {
  s <- sat_solver(list(1, 2))
  expect_true(sat_is_sat(sat_solve(s)))
  expect_equal(sat_value(s, 1:2), c(TRUE, TRUE))
})

test_that("options can be read and written", {
  s <- sat_solver()
  expect_type(sat_option(s, "elim"), "integer")

  sat_option(s, "elim", 0)
  expect_equal(sat_option(s, "elim"), 0L)
})

test_that("the bundled solver reports its version", {
  expect_match(sat_signature(), "^cadical-")
})

test_that("objects print informatively", {
  s <- sat_solver(list(c(1, 2)))
  expect_output(print(s), "zusat_solver")
  expect_output(print(s), "variables")

  expect_output(print(sat_solve(s)), "zusat_solution")
  expect_output(print(sat_solve(list(1, -1))), "unsat")
})

test_that("solving something that is neither formula nor solver errors", {
  expect_error(sat_solve(42), "list of clauses or a zusat_solver")
  expect_error(sat_solve("x"), "list of clauses or a zusat_solver")
})

# ---------------------------------------------------------------------------
# Adapted from rpicosat's suite (MIT, Dirk Schumacher). Its input-validation
# cases are the valuable part: they cover coercions that as.integer() would
# otherwise perform silently, turning a malformed formula into a different
# well-formed one. Its exact-model assertions are deliberately not copied --
# any satisfying assignment is a correct answer, so pinning one makes the
# test brittle against a solver change rather than checking correctness.

test_that("invalid literals are rejected", {
  s <- sat_solver()
  expect_error(sat_add(s, c(1, 0)), "must not contain 0")
  expect_error(sat_add(s, c(1, NA)), "must not be NA")
})

test_that("literals must be numeric", {
  s <- sat_solver()
  expect_error(sat_add(s, c("1", "2")), "must be numeric")
  expect_error(sat_add(s, factor(c(1, 2))), "must be numeric")
  expect_error(sat_add(s, TRUE), "must be numeric")
})

test_that("literals must be whole numbers", {
  # as.integer(1.7) is 1L, so without this a typo silently changes the formula
  expect_error(sat_add(sat_solver(), c(1.7, 2)), "whole numbers")
})

test_that("doubles that are whole are accepted", {
  # R users write c(1, -2) far more often than c(1L, -2L)
  s <- sat_solver()
  expect_silent(sat_add(s, c(1, -2)))
  expect_true(sat_is_sat(sat_solve(s)))
})

test_that("assumptions get the same validation as clauses", {
  s <- sat_solver(list(c(1, 2)))
  expect_error(sat_solve(s, assumptions = "1"), "must be numeric")
  expect_error(sat_solve(s, assumptions = 0), "must not contain 0")
  expect_error(sat_solve(s, assumptions = 1.5), "whole numbers")
})

test_that("an implication chain propagates under an assumption", {
  # 1 => 2, 2 => 3. Assuming 1 forces all three true, so unlike a general
  # model this one is uniquely determined and safe to assert exactly.
  s <- sat_solver(list(c(-1, 2), c(-2, 3)))

  sol <- sat_solve(s, assumptions = 1)
  expect_true(sat_is_sat(sol))
  expect_equal(sat_value(s, 1:3), c(TRUE, TRUE, TRUE))
})
