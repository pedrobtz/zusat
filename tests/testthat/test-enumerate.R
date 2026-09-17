test_that("all models of a small formula are found", {
  # (x1 OR x2) has exactly three models over {x1, x2}
  sols <- sat_solutions(list(c(1, 2)))

  expect_equal(sat_status(sols), "sat")
  expect_equal(sat_n_solutions(sols), 3L)
  expect_true(sat_complete(sols))
})

test_that("every enumerated model satisfies the formula, and none repeats", {
  formula <- list(c(1, 2, -3), c(-1, 3), c(-2, 3))
  sols <- sat_solutions(formula)

  expect_true(sat_complete(sols))
  expect_gt(sat_n_solutions(sols), 0L)

  by_solution <- split(sols, sols$solution)
  assignments <- character()

  for (one in by_solution) {
    m <- stats::setNames(one$value, one$variable)
    expect_true(satisfies_all(formula, m))
    assignments <- c(assignments, paste(one$value, collapse = ""))
  }

  # distinctness is the whole point of blocking clauses
  expect_equal(anyDuplicated(assignments), 0L)
})

test_that("projection collapses models that differ only outside vars", {
  # x3 is unconstrained, so over {x1,x2,x3} each model of (x1 OR x2)
  # appears twice -- once per polarity of x3
  formula <- list(c(1, 2))

  all_vars <- sat_solutions(formula, vars = 1:3)
  projected <- sat_solutions(formula, vars = 1:2)

  expect_equal(sat_n_solutions(all_vars), 6L)
  expect_equal(sat_n_solutions(projected), 3L)
})

test_that("projection reports only the requested variables", {
  sols <- sat_solutions(list(c(1, 2), c(3, 4)), vars = c(1, 2))
  expect_setequal(unique(sols$variable), c(1L, 2L))
})

test_that("limit truncates and says so", {
  sols <- sat_solutions(list(c(1, 2)), limit = 2)

  expect_equal(sat_n_solutions(sols), 2L)
  expect_false(sat_complete(sols))
})

test_that("an exhausted enumeration is marked complete", {
  sols <- sat_solutions(list(c(1, 2)), limit = 100)

  expect_equal(sat_n_solutions(sols), 3L)
  expect_true(sat_complete(sols))
})

test_that("an unsatisfiable formula enumerates to nothing", {
  sols <- sat_solutions(list(1, -1))

  expect_equal(sat_status(sols), "unsat")
  expect_equal(sat_n_solutions(sols), 0L)
  expect_equal(nrow(sols), 0L)
  expect_true(sat_complete(sols))
})

test_that("assumptions constrain every solve in the enumeration", {
  sols <- sat_solutions(list(c(1, 2)), assumptions = -1)

  # with x1 false, x2 must be true: exactly one model
  expect_equal(sat_n_solutions(sols), 1L)
  expect_true(sat_complete(sols))
  expect_true(sols$value[sols$variable == 2L])
})

test_that("limit of zero returns nothing without solving", {
  sols <- sat_solutions(list(c(1, 2)), limit = 0)
  expect_equal(sat_n_solutions(sols), 0L)
})

test_that("enumerating from a solver consumes it", {
  # documented behaviour: blocking clauses are permanent
  s <- sat_solver(list(c(1, 2)))
  sols <- sat_solutions(s)

  expect_equal(sat_n_solutions(sols), 3L)
  # every model has been blocked, so the solver is now unsatisfiable
  expect_equal(sat_status(sat_solve(s)), "unsat")
})

test_that("negative literals are rejected as vars", {
  expect_error(sat_solutions(list(c(1, 2)), vars = -1), "not negative literals")
})

test_that("limit must be a single non-negative number", {
  expect_error(sat_solutions(list(c(1, 2)), limit = -1), "non-negative")
  expect_error(sat_solutions(list(c(1, 2)), limit = c(1, 2)), "single")
})

test_that("solutions print with a status line", {
  sols <- sat_solutions(list(c(1, 2)))
  expect_output(print(sols), "zusat_solutions")
  expect_output(print(sols), "3 solutions")
})

test_that("a truncated enumeration says so when printed", {
  sols <- sat_solutions(list(c(1, 2)), limit = 1)
  expect_output(print(sols), "stopped at limit")
})
