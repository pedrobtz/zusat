# An encoding is correct when the assignments it admits are exactly the
# assignments satisfying the constraint -- no more, no fewer. For small n that
# is checkable outright rather than by sampling: enumerate every model of the
# encoding, project onto the constrained variables, and compare against the
# set computed directly.
#
# This is the test that matters. A cardinality encoding that is merely *sound*
# (admits only valid assignments) can still be badly wrong by excluding valid
# ones, and a formula that quietly lost some of its solutions is close to
# impossible to debug from the outside.

# Every assignment of n booleans whose true-count satisfies the predicate.
expected_assignments <- function(n, keep) {
  grid <- expand.grid(rep(list(c(FALSE, TRUE)), n), KEEP.OUT.ATTRS = FALSE)
  rows <- lapply(seq_len(nrow(grid)), function(i) unlist(grid[i, ], use.names = FALSE))
  Filter(function(a) keep(sum(a)), rows)
}

# Every assignment the encoded solver actually admits, projected onto 1:n.
admitted_assignments <- function(build, n) {
  s <- sat_solver()
  build(s)
  sols <- sat_solutions(s, vars = seq_len(n), limit = Inf)
  if (sat_n_solutions(sols) == 0L) {
    return(list())
  }
  lapply(split(sols, sols$solution), function(one) one$value)
}

as_key <- function(assignments) {
  # unname: split() names its groups, and those names would otherwise be
  # compared against the unnamed expected set and fail for the wrong reason
  sort(unname(vapply(assignments, function(a) {
    paste(as.integer(a), collapse = "")
  }, character(1))))
}

expect_encodes_exactly <- function(n, k, kind, encoding) {
  keep <- switch(kind,
    at_most  = function(count) count <= k,
    at_least = function(count) count >= k,
    exactly  = function(count) count == k
  )
  build <- switch(kind,
    at_most  = function(s) sat_at_most(s, seq_len(n), k, encoding = encoding),
    at_least = function(s) sat_at_least(s, seq_len(n), k, encoding = encoding),
    exactly  = function(s) sat_exactly(s, seq_len(n), k, encoding = encoding)
  )

  testthat::expect_equal(
    as_key(admitted_assignments(build, n)),
    as_key(expected_assignments(n, keep)),
    info = sprintf("%s %d of %d, encoding %s", kind, k, n, encoding)
  )
}

test_that("at_most admits exactly the right assignments, both encodings", {
  for (encoding in c("pairwise", "sequential")) {
    for (n in 1:5) {
      for (k in 0:n) {
        expect_encodes_exactly(n, k, "at_most", encoding)
      }
    }
  }
})

test_that("at_least admits exactly the right assignments, both encodings", {
  for (encoding in c("pairwise", "sequential")) {
    for (n in 1:5) {
      for (k in 0:n) {
        expect_encodes_exactly(n, k, "at_least", encoding)
      }
    }
  }
})

test_that("exactly admits exactly the right assignments, both encodings", {
  for (encoding in c("pairwise", "sequential")) {
    for (n in 1:5) {
      for (k in 0:n) {
        expect_encodes_exactly(n, k, "exactly", encoding)
      }
    }
  }
})

test_that("the auto encoding agrees with both explicit ones", {
  for (n in 1:5) {
    for (k in 0:n) {
      expect_encodes_exactly(n, k, "at_most", "auto")
      expect_encodes_exactly(n, k, "exactly", "auto")
    }
  }
})

test_that("auxiliary variables do not collide with the literals", {
  # On a fresh solver sat_n_vars() is 0. Allocating auxiliaries from there
  # would put them straight on top of the literals being constrained, which
  # does not error -- it silently encodes a different constraint.
  s <- sat_solver()
  sat_at_most(s, 1:6, 2, encoding = "sequential")

  expect_gt(sat_n_vars(s), 6L) # auxiliaries live above the literals

  sols <- sat_solutions(s, vars = 1:6, limit = Inf)
  counts <- vapply(split(sols, sols$solution), function(one) sum(one$value),
                   numeric(1))
  expect_true(all(counts <= 2))
  expect_equal(sat_n_solutions(sols), length(expected_assignments(6, function(c) c <= 2)))
})

test_that("auxiliary variables clear existing formula variables too", {
  s <- sat_solver(list(c(20, 21))) # solver already knows 21 variables
  sat_at_most(s, 1:6, 2, encoding = "sequential")

  sols <- sat_solutions(s, vars = 1:6, limit = Inf)
  counts <- vapply(split(sols, sols$solution), function(one) sum(one$value),
                   numeric(1))
  expect_true(all(counts <= 2))
})

test_that("negative literals are constrained, not their variables", {
  # "at most one of x1, x2 is FALSE" -- three of the four assignments qualify
  s <- sat_solver()
  sat_at_most(s, c(-1, -2), 1)

  sols <- sat_solutions(s, vars = 1:2, limit = Inf)
  false_counts <- vapply(split(sols, sols$solution),
                         function(one) sum(!one$value), numeric(1))
  expect_true(all(false_counts <= 1))
  expect_equal(sat_n_solutions(sols), 3L)
})

test_that("degenerate bounds behave", {
  # at_most k >= n constrains nothing
  s <- sat_solver()
  sat_add(s, list(c(1, 2), c(-1, 2)))
  before <- sat_n_clauses(s)
  sat_at_most(s, 1:2, 5)
  expect_equal(sat_n_clauses(s), before)

  # at_least 0 constrains nothing
  s2 <- sat_solver(list(c(1, 2)))
  before2 <- sat_n_clauses(s2)
  sat_at_least(s2, 1:2, 0)
  expect_equal(sat_n_clauses(s2), before2)

  # at_most 0 forces everything false
  s3 <- sat_solver()
  sat_at_most(s3, 1:3, 0)
  expect_true(sat_is_sat(sat_solve(s3)))
  expect_equal(sat_value(s3, 1:3), c(FALSE, FALSE, FALSE))

  # at_least n forces everything true
  s4 <- sat_solver()
  sat_at_least(s4, 1:3, 3)
  expect_true(sat_is_sat(sat_solve(s4)))
  expect_equal(sat_value(s4, 1:3), c(TRUE, TRUE, TRUE))
})

test_that("an impossible bound is unsatisfiable, not silently ignored", {
  s <- sat_solver()
  sat_at_least(s, 1:3, 4) # cannot have 4 of 3
  expect_equal(sat_status(sat_solve(s)), "unsat")

  s2 <- sat_solver()
  sat_exactly(s2, 1:3, 4)
  expect_equal(sat_status(sat_solve(s2)), "unsat")
})

test_that("exactly one is the pick-a-bucket constraint", {
  s <- sat_solver()
  sat_exactly(s, 1:4, 1)

  sols <- sat_solutions(s, vars = 1:4, limit = Inf)
  expect_equal(sat_n_solutions(sols), 4L)
  counts <- vapply(split(sols, sols$solution), function(one) sum(one$value),
                   numeric(1))
  expect_true(all(counts == 1))
})

test_that("the sequential encoding scales where pairwise would not", {
  # choose(40, 4) is 91390 clauses pairwise; sequential is a few hundred
  s <- sat_solver()
  sat_at_most(s, 1:40, 3, encoding = "sequential")

  expect_lt(sat_n_clauses(s), 1000)
  expect_true(sat_is_sat(sat_solve(s)))

  # and the bound actually holds
  sat_at_least(s, 1:40, 3, encoding = "sequential")
  expect_true(sat_is_sat(sat_solve(s)))
  expect_equal(sum(sat_value(s, 1:40), na.rm = TRUE), 3)
})

test_that("auto picks pairwise when small and sequential when not", {
  small <- sat_solver()
  sat_at_most(small, 1:4, 1) # choose(4,2) = 6
  expect_equal(sat_n_vars(small), 4L) # no auxiliaries

  large <- sat_solver()
  sat_at_most(large, 1:40, 3) # choose(40,4) = 91390
  expect_gt(sat_n_vars(large), 40L) # auxiliaries were used
})

test_that("bounds are validated", {
  s <- sat_solver()
  expect_error(sat_at_most(s, 1:3, -1), "must not be negative")
  expect_error(sat_at_most(s, 1:3, 1.5), "whole number")
  expect_error(sat_at_most(s, 1:3, c(1, 2)), "single number")
  expect_error(sat_at_most(s, c(1, 0), 1), "must not contain 0")
  expect_error(sat_at_most(s, 1:3, 1, encoding = "magic"))
})
