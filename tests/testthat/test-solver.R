test_that("trivially satisfiable formulas are solved", {
  s <- sat_solver()
  sat_add(s, c(1L, 2L))
  expect_equal(sat_solve(s), "sat")

  m <- sat_model(s, 1:2)
  expect_type(m, "logical")
  expect_true(any(m))  # the clause must be satisfied
})

test_that("contradictions are reported unsat", {
  s <- sat_solver()
  sat_add(s, 1L)
  sat_add(s, -1L)
  expect_equal(sat_solve(s), "unsat")
})

test_that("the empty clause makes a formula unsat", {
  s <- sat_solver()
  sat_add(s, integer())
  expect_equal(sat_solve(s), "unsat")
})

test_that("the returned model actually satisfies every clause", {
  clauses <- list(c(1L, 2L, -3L), c(-1L, 3L), c(-2L, 3L), c(1L, -2L, 3L))
  s <- sat_solver()
  sat_add_all(s, clauses)
  expect_equal(sat_solve(s), "sat")

  m <- sat_model(s, 1:3)
  m[is.na(m)] <- TRUE  # unassigned variables may take either polarity
  satisfied <- vapply(clauses, function(cl) {
    any(ifelse(cl > 0, m[abs(cl)], !m[abs(cl)]))
  }, logical(1))
  expect_true(all(satisfied))
})

test_that("solving is incremental across calls", {
  s <- sat_solver()
  sat_add(s, c(1L, 2L))
  expect_equal(sat_solve(s), "sat")

  sat_add(s, -1L)
  sat_add(s, -2L)
  expect_equal(sat_solve(s), "unsat")
})

test_that("assumptions apply to one call only", {
  s <- sat_solver()
  sat_add(s, c(1L, 2L))

  expect_equal(sat_solve(s, assumptions = c(-1L, -2L)), "unsat")
  # the formula itself is still satisfiable
  expect_equal(sat_solve(s), "sat")
})

test_that("failed assumptions identify the conflicting subset", {
  s <- sat_solver()
  sat_add(s, c(1L, 2L))

  assumptions <- c(-1L, -2L)
  expect_equal(sat_solve(s, assumptions = assumptions), "unsat")

  failed <- sat_failed(s, assumptions)
  expect_type(failed, "logical")
  expect_length(failed, 2L)
  expect_true(any(failed))
})

test_that("pigeonhole instances are unsatisfiable", {
  # 5 pigeons into 4 holes: unsat, and small enough to stay fast
  holes <- 4L
  pigeons <- 5L
  v <- function(i, j) (i - 1L) * holes + j

  s <- sat_solver()
  for (i in seq_len(pigeons)) {
    sat_add(s, vapply(seq_len(holes), function(j) v(i, j), integer(1)))
  }
  for (j in seq_len(holes)) {
    for (pair in utils::combn(pigeons, 2L, simplify = FALSE)) {
      sat_add(s, c(-v(pair[1], j), -v(pair[2], j)))
    }
  }
  expect_equal(sat_solve(s), "unsat")
})

test_that("invalid literals are rejected", {
  s <- sat_solver()
  expect_error(sat_add(s, c(1L, 0L)), "not a valid literal")
  expect_error(sat_add(s, c(1L, NA_integer_)), "must not be NA")
})

test_that("variable count tracks the clauses added", {
  s <- sat_solver()
  expect_equal(sat_n_vars(s), 0L)
  sat_add(s, c(1L, 5L))
  expect_equal(sat_n_vars(s), 5L)
})

test_that("options can be read and written", {
  s <- sat_solver()
  original <- sat_option(s, "elim")
  expect_type(original, "integer")

  sat_option(s, "elim", 0L)
  expect_equal(sat_option(s, "elim"), 0L)
})

test_that("the vendored solver reports its version", {
  expect_match(sat_signature(), "^cadical-")
})

test_that("solver handles print", {
  s <- sat_solver()
  expect_output(print(s), "zusat_solver")
})
