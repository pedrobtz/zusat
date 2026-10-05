# Regression tests for two soundness reviews (#21 and #22). Each case is one a
# review reproduced: a wrong answer reported as right, a CaDiCaL contract
# violation reachable from exported functions, or a crash.

# Every model of a small formula, by brute force, as sorted strings of 0/1.
brute_force_models <- function(n_vars, admitted) {
  grid <- as.matrix(expand.grid(rep(list(c(FALSE, TRUE)), n_vars)))
  keep <- apply(grid, 1, admitted)
  sort(apply(grid[keep, , drop = FALSE], 1, function(r) {
    paste(as.integer(r), collapse = "")
  }))
}

enumerated_models <- function(sols) {
  if (sat_n_solutions(sols) == 0L) {
    return(character())
  }
  sort(vapply(
    split(sols$value, sols$solution),
    function(v) {
      paste(as.integer(v), collapse = "")
    },
    character(1),
    USE.NAMES = FALSE
  ))
}

# --- #21 (1): auxiliary variables must not collide with user variables ------

test_that("a later constraint cannot silently reuse earlier auxiliaries", {
  # choose(12, 2) = 66 clauses is past the pairwise threshold, so "auto"
  # takes the sequential counter and allocates auxiliaries 13:23. The second
  # constraint used to encode itself over them and turn a satisfiable model
  # into "unsat".
  s <- sat_solver()
  sat_exactly(s, 1:12, 1)
  expect_error(sat_exactly(s, 13:24, 1), "auxiliary")
})

test_that("every modelling entry point refuses an auxiliary variable", {
  s <- sat_solver()
  sat_at_most(s, 1:4, 1, encoding = "sequential") # auxiliaries 5:7
  expect_error(sat_add(s, c(1, 5)), "auxiliary")
  expect_error(sat_add(s, list(1, c(-6, 2))), "auxiliary")
  expect_error(sat_constrain(s, 7), "auxiliary")
  expect_error(sat_solve(s, assumptions = 5), "auxiliary")
  expect_error(sat_solutions(s, vars = 1:5), "auxiliary")
  expect_error(sat_at_least(s, c(1, 6), 1), "auxiliary")
  # what is above the auxiliaries is free again
  expect_silent(sat_add(s, c(1, 8)))
})

test_that("reserved variables keep disjoint constraints independent", {
  for (encoding in c("auto", "sequential")) {
    s <- sat_solver()
    sat_reserve(s, 24)
    expect_equal(sat_n_vars(s), 24L)
    sat_exactly(s, 1:12, 1, encoding = encoding)
    sat_exactly(s, 13:24, 1, encoding = encoding)
    expect_equal(sat_status(sat_solve(s, assumptions = c(1, 24))), "sat")

    sols <- sat_solutions(s, vars = 1:24, limit = Inf)
    expect_true(sat_complete(sols))
    expect_equal(sat_n_solutions(sols), 144L)
    per_solution <- lapply(split(sols, sols$solution), function(one) {
      c(sum(one$value[one$variable <= 12]), sum(one$value[one$variable > 12]))
    })
    expect_true(all(vapply(per_solution, identical, logical(1), c(1L, 1L))))
  }
})

test_that("sat_reserve validates and refuses a range already used as auxiliary", {
  s <- sat_solver()
  expect_error(sat_reserve(s, -1), "non-negative")
  expect_error(sat_reserve(s, 1.5), "whole")
  expect_error(sat_reserve(s, NA), "single")
  expect_silent(sat_reserve(s, 0))
  sat_at_most(s, 1:4, 1, encoding = "sequential")
  expect_error(sat_reserve(s, 6), "auxiliary")
  # reserving less than is already known is a no-op
  sat_reserve(s, 2)
  expect_equal(sat_n_vars(s), 7L)
})

# --- #21 (2): an inconclusive enumeration is not complete --------------------

test_that("a resource-limited enumeration is not reported complete", {
  cnf <- system.file("extdata", "cadical", "ph6.cnf", package = "zusat")
  s <- sat_solver(read_dimacs(cnf))
  sat_limit(s, "conflicts", 1)
  r <- sat_solutions(s)
  expect_equal(sat_status(r), "unknown")
  expect_false(sat_complete(r))
  expect_equal(sat_n_solutions(r), 0L)
  expect_false(grepl("stopped at limit", format(r)))
  expect_match(format(r), "search stopped")
})

test_that("an unknown solve after some models leaves the enumeration incomplete", {
  calls <- 0L
  real <- sat_solve
  local_mocked_bindings(sat_solve = function(x, ...) {
    calls <<- calls + 1L
    if (calls == 3L) {
      return(structure(
        data.frame(variable = integer(), value = logical()),
        class = c("zusat_solution", "data.frame"),
        status = "unknown"
      ))
    }
    real(x, ...)
  })
  r <- sat_solutions(list(c(1, 2)))
  expect_equal(sat_status(r), "sat")
  expect_equal(sat_n_solutions(r), 2L)
  expect_false(sat_complete(r))
  expect_match(format(r), "search stopped")
})

test_that("normal exhaustion and the count limit are still told apart", {
  done <- sat_solutions(list(c(1, 2)))
  expect_true(sat_complete(done))
  capped <- sat_solutions(list(c(1, 2)), limit = 1)
  expect_false(sat_complete(capped))
  expect_match(format(capped), "stopped at limit")
})

# --- #21 (3): a foreign external pointer is not a solver --------------------

test_that("a non-zusat external pointer is rejected, not dereferenced", {
  # This used to read the address as a zusat handle and segfault.
  foreign <- get("zusat_signature", asNamespace("zusat"))$address
  expect_true(typeof(foreign) == "externalptr")
  expect_error(sat_n_vars(foreign), "not a zusat solver")
  expect_error(
    sat_solve(structure(foreign, class = "zusat_solver")),
    "not a zusat solver"
  )
  expect_error(sat_n_vars(1), "invalid solver handle")
})

# --- #21 (4): resource limits are validated, not coerced --------------------

test_that("limits that do not fit an integer are rejected", {
  s <- sat_solver(list(c(1, 2)))
  expect_error(sat_limit(s, "conflicts", 2^31), "at most")
  expect_error(sat_limit(s, "conflicts", -0.5), "whole number")
  expect_error(sat_limit(s, "conflicts", 1.5), "whole number")
  expect_error(sat_limit(s, "conflicts", NA), "single number")
  # any negative whole number is "no limit", however large
  expect_silent(sat_limit(s, "conflicts", -2^31 - 1))
  expect_silent(sat_limit(s, "conflicts", .Machine$integer.max))
  expect_silent(sat_limit(s, "conflicts", 0))
})

test_that("Inf and negative values mean no limit, and say so without warnings", {
  cnf <- system.file("extdata", "cadical", "ph6.cnf", package = "zusat")
  for (v in list(Inf, -1)) {
    s <- sat_solver(read_dimacs(cnf))
    expect_silent(sat_limit(s, "conflicts", v))
    expect_equal(sat_status(sat_solve(s)), "unsat")
  }
  # 0 is a real bound: no conflicts allowed
  s <- sat_solver(read_dimacs(cnf))
  sat_limit(s, "conflicts", 0)
  expect_equal(sat_status(sat_solve(s)), "unknown")
})

test_that("round-count limits cannot be unbounded", {
  # CaDiCaL ignores a negative preprocessing or local search limit, which
  # would turn "unlimited" into "none at all"
  s <- sat_solver(list(c(1, 2)))
  expect_error(sat_limit(s, "preprocessing", Inf), "non-negative")
  expect_error(sat_limit(s, "localsearch", -1), "non-negative")
  expect_silent(sat_limit(s, "preprocessing", 2))
})

# --- #21 (5): subsetting keeps or drops the class coherently ----------------

test_that("selecting columns of a solution gives a plain data frame", {
  sol <- sat_solve(list(1))
  z <- sol["value"]
  expect_identical(class(z), "data.frame")
  expect_null(attr(z, "status"))
  expect_output(print(z))
  expect_identical(class(sol[, "value", drop = FALSE]), "data.frame")
  expect_identical(sol[, "value"], TRUE)
})

test_that("filtering rows of a solution keeps the class and its metadata", {
  sol <- sat_solve(list(c(1, 2), c(-1, 3)))
  kept <- sol[sol$value, ]
  expect_s3_class(kept, "zusat_solution")
  expect_equal(sat_status(kept), "sat")
  expect_output(print(kept), "sat")
  none <- sol[0, ]
  expect_s3_class(none, "zusat_solution")
  expect_equal(nrow(none), 0L)
  expect_output(print(none), "sat")
})

test_that("enumeration results subset the same way", {
  sols <- sat_solutions(list(c(1, 2)))
  z <- sols["value"]
  expect_identical(class(z), "data.frame")
  expect_output(print(z))
  first <- sols[sols$solution == 1L, ]
  expect_s3_class(first, "zusat_solutions")
  expect_true(sat_complete(first))
  expect_output(print(first), "zusat_solutions")
  expect_identical(class(as.data.frame(first)), "data.frame")
})

# --- #21 (6): a rejected batch leaves the solver untouched ------------------

test_that("an invalid later clause leaves the formula unchanged", {
  s <- sat_solver(list(1))
  expect_error(sat_add(s, list(-1, 0)), "must not contain 0")
  expect_equal(sat_status(sat_solve(s)), "sat")

  s <- sat_solver(list(1))
  expect_error(sat_add(s, list(-1, "a")), "numeric")
  expect_equal(sat_status(sat_solve(s)), "sat")
})

test_that("a cardinality constraint that cannot be encoded adds nothing", {
  # sat_exactly() is at_least (pairwise here, one clause) followed by
  # at_most (sequential, auxiliaries past the variable ceiling). The first
  # half used to be committed before the second failed.
  mv <- .Call(zusat_max_var_get)
  s <- sat_solver()
  expect_error(sat_exactly(s, (mv - 11):mv, 1), "at most")
  expect_equal(sat_n_clauses(s), 0)
  expect_equal(sat_n_vars(s), 0L)
})

# --- #21 (7): proof format is set deterministically -------------------------

test_that("a failed LRAT setup does not leak into a later DRAT proof", {
  s <- sat_solver()
  lrat_before <- sat_option(s, "lrat")
  binary_before <- sat_option(s, "binary")
  bad <- file.path(tempfile(), "proof.lrat")
  expect_error(
    sat_trace_proof(s, bad, format = "lrat", binary = TRUE),
    "could not open"
  )
  expect_equal(sat_option(s, "lrat"), lrat_before)
  expect_equal(sat_option(s, "binary"), binary_before)

  path <- tempfile(fileext = ".drat")
  sat_trace_proof(s, path, format = "drat")
  sat_add(s, list(1, -1))
  sat_solve(s)
  sat_close_proof(s)

  fresh_path <- tempfile(fileext = ".drat")
  fresh <- sat_solver()
  sat_trace_proof(fresh, fresh_path, format = "drat")
  sat_add(fresh, list(1, -1))
  sat_solve(fresh)
  sat_close_proof(fresh)

  expect_identical(readLines(path), readLines(fresh_path))
})

test_that("an explicit drat request overrides an earlier lrat option", {
  s <- sat_solver()
  sat_option(s, "lrat", 1)
  path <- tempfile(fileext = ".drat")
  sat_trace_proof(s, path, format = "drat")
  expect_equal(sat_option(s, "lrat"), 0L)
  sat_close_proof(s)
})

# --- #21 (8): option names and values are validated -------------------------

test_that("a misspelled option is an error, for getting and setting", {
  s <- sat_solver()
  expect_error(sat_option(s, "elmi", 0), "unknown option 'elmi'")
  expect_error(sat_option(s, "elmi"), "unknown option 'elmi'")
})

test_that("option values must be whole numbers in the option's range", {
  s <- sat_solver()
  expect_error(sat_option(s, "elim", NA_integer_), "single whole number")
  expect_error(sat_option(s, "elim", 1.9), "whole number")
  expect_error(sat_option(s, "elim", 2^31), "between")
  expect_error(sat_option(s, "elim", 5), "between 0 and 1")
  expect_equal(sat_option(s, "elim"), 1L)
})

test_that("the setter returns what the getter then reads", {
  s <- sat_solver()
  expect_identical(sat_option(s, "elim", 0), sat_option(s, "elim"))
  expect_identical(sat_option(s, "restartint", 7), 7L)
})

# --- #22 (1): enumeration and a pending constraint --------------------------

test_that("enumeration refuses to run over a one-shot constraint", {
  s <- sat_solver(list(c(1, 2)))
  sat_constrain(s, c(-1, -2))
  expect_error(sat_solutions(s), "constraint")
  # the refusal did not consume it: the next solve still honours it
  sol <- sat_solve(s)
  expect_false(all(sat_assignment(sol)))
})

test_that("a constraint passed to sat_solutions holds for every model", {
  formula <- list(c(1, 2), c(-2, 3, 4))
  sols <- sat_solutions(formula, constraint = c(-1, -2))
  expect_true(sat_complete(sols))
  expect_equal(
    enumerated_models(sols),
    brute_force_models(4, function(m) {
      (m[1] || m[2]) && (!m[2] || m[3] || m[4]) && (!m[1] || !m[2])
    })
  )

  # from a solver too, and the constraint is gone afterwards
  s <- sat_solver(list(c(1, 2)))
  sols <- sat_solutions(s, constraint = c(-1, -2))
  expect_equal(sat_n_solutions(sols), 2L)
  expect_false(.Call(zusat_constraint_pending, s))
})

test_that("a constraint that makes the first solve unsat yields no models", {
  s <- sat_solver(list(1))
  sols <- sat_solutions(s, constraint = -1)
  expect_equal(sat_status(sols), "unsat")
  expect_equal(sat_n_solutions(sols), 0L)
  expect_true(sat_complete(sols))
  expect_true(sat_is_sat(sat_solve(s)))
})

test_that("sat_solutions validates the constraint", {
  expect_error(sat_solutions(list(1), constraint = 0), "must not contain 0")
  expect_error(sat_solutions(list(1), constraint = "a"), "numeric")
})

# --- #22 (2): stale status guards -------------------------------------------

test_that("adding a clause invalidates the model", {
  s <- sat_solver(list(c(1, 2)))
  sat_solve(s)
  sat_add(s, 3)
  expect_error(sat_value(s, 1:3), "no model available")
  # and a fresh solve brings it back
  sat_solve(s)
  expect_length(sat_value(s, 1:3), 3L)
})

test_that("adding a clause invalidates failed assumptions", {
  s <- sat_solver(list(c(1, 2)))
  sat_solve(s, assumptions = c(-1, -2))
  sat_add(s, 3)
  expect_error(sat_failed(s, c(-1, -2)), "no failed assumptions")
})

test_that("a new constraint invalidates constraint_failed", {
  s <- sat_solver(list(1))
  sat_constrain(s, -1)
  sat_solve(s)
  sat_constrain(s, 2)
  expect_error(sat_constraint_failed(s), "needs a solve")
})

test_that("sat_conclude needs a completed solve", {
  expect_error(sat_conclude(sat_solver()), "no solve to conclude")

  s <- sat_solver(list(c(1, 2)))
  sat_solve(s)
  sat_add(s, 3)
  expect_error(sat_conclude(s), "no solve to conclude")
})

test_that("sat_conclude succeeds after sat, unsat and unknown solves", {
  s <- sat_solver(list(c(1, 2)))
  sat_solve(s)
  expect_identical(sat_conclude(s), s)

  s <- sat_solver(list(1, -1))
  sat_solve(s)
  expect_silent(sat_conclude(s))

  cnf <- system.file("extdata", "cadical", "ph6.cnf", package = "zusat")
  s <- sat_solver(read_dimacs(cnf))
  sat_limit(s, "conflicts", 0)
  expect_equal(sat_status(sat_solve(s)), "unknown")
  expect_silent(sat_conclude(s))
})

# --- #22 (3): NULL is not the empty clause ----------------------------------

test_that("NULL where a clause is expected is an error", {
  expect_error(sat_solve(list(c(1, 2), NULL)), "clause 2 is NULL")
  expect_error(sat_solve(list(c(1, 2), if (FALSE) 3)), "clause 2 is NULL")
  expect_error(sat_solutions(list(NULL)), "clause 1 is NULL")
  expect_error(write_dimacs(list(1, NULL), tempfile()), "clause 2 is NULL")

  s <- sat_solver(list(c(1, 2)))
  expect_error(sat_add(s, NULL), "NULL")
  expect_error(sat_constrain(s, NULL), "NULL")
  expect_equal(sat_status(sat_solve(s)), "sat")
})

test_that("integer() is still the empty clause, and NULL still means none elsewhere", {
  expect_equal(sat_status(sat_solve(list(c(1, 2), integer()))), "unsat")
  expect_equal(sat_status(sat_solve(list(c(1, 2)), assumptions = NULL)), "sat")
  expect_equal(sat_n_vars(sat_solver(NULL)), 0L)
  s <- sat_solver()
  expect_silent(sat_at_most(s, NULL, 1))
  s <- sat_solver(list(c(1, 2)))
  sat_constrain(s, integer())
  expect_equal(sat_status(sat_solve(s)), "unsat")
})

# --- #22 (4): what a proof proves --------------------------------------------

test_that("an assumption refutation checks against formula plus failed units", {
  checker <- Sys.which("drat-trim")
  skip_if(!nzchar(checker), "drat-trim not on PATH")

  f <- list(c(1, 2), c(-1, 3), c(-2, -3), c(3, 4), c(-4, 5))
  proof <- tempfile(fileext = ".drat")
  s <- sat_solver()
  sat_trace_proof(s, proof)
  sat_add(s, f)
  expect_equal(sat_status(sat_solve(s, assumptions = c(1, 2))), "unsat")
  failed <- c(1, 2)[sat_failed(s, c(1, 2))]
  sat_conclude(s)
  sat_close_proof(s)

  cnf <- tempfile(fileext = ".cnf")
  write_dimacs(c(f, as.list(failed)), cnf)
  out <- suppressWarnings(system2(
    checker,
    c(cnf, proof),
    stdout = TRUE,
    stderr = TRUE
  ))
  expect_true(any(grepl("^s VERIFIED", trimws(out))))
})

test_that("an incremental refutation checks against every clause added", {
  checker <- Sys.which("drat-trim")
  skip_if(!nzchar(checker), "drat-trim not on PATH")

  first <- list(c(1, 2), c(-1, 2))
  later <- list(c(1, -2), c(-1, -2))
  proof <- tempfile(fileext = ".drat")
  s <- sat_solver()
  sat_trace_proof(s, proof)
  sat_add(s, first)
  expect_true(sat_is_sat(sat_solve(s)))
  sat_add(s, later)
  expect_equal(sat_status(sat_solve(s)), "unsat")
  sat_close_proof(s)

  cnf <- tempfile(fileext = ".cnf")
  write_dimacs(c(first, later), cnf)
  out <- suppressWarnings(system2(
    checker,
    c(cnf, proof),
    stdout = TRUE,
    stderr = TRUE
  ))
  expect_true(any(grepl("^s VERIFIED", trimws(out))))
})

# --- #22 (5): NA in a model --------------------------------------------------

test_that("a variable the formula never mentions still gets a value up to n_vars", {
  # CaDiCaL assigns every variable up to its maximum index, so NA is reserved
  # for variables beyond it -- which is what the documentation now says
  sol <- sat_solve(list(c(1, 3)))
  expect_false(anyNA(sol$value))
  s <- sat_solver(list(c(1, 3)))
  sat_solve(s)
  expect_identical(is.na(sat_value(s, c(2, 4))), c(FALSE, TRUE))
})

# --- #22 (6): data frames are not formulas -----------------------------------

test_that("a data frame is rejected by every formula entry point", {
  df <- data.frame(a = c(1, 2), b = c(-1, 3))
  expect_error(sat_solve(df), "list of clauses")
  expect_error(sat_solutions(df), "list of clauses")
  expect_error(write_dimacs(df, tempfile()), "list of clauses")
  expect_error(sat_solutions(sat_solve(list(1))), "list of clauses")
})

# --- #22 (7): DIMACS comments and tokens -------------------------------------

test_that("a comment containing a newline cannot inject a clause", {
  p <- tempfile(fileext = ".cnf")
  write_dimacs(list(c(1, 2)), p, comment = c("injected\n5 0", "crlf\r\n6 0"))
  expect_equal(read_dimacs(p), list(c(1L, 2L)))
  expect_true(all(startsWith(head(readLines(p), -2L), "c")))
})

test_that("write_dimacs validates the comment", {
  expect_error(write_dimacs(list(1), tempfile(), comment = 1), "character")
  expect_error(
    write_dimacs(list(1), tempfile(), comment = NA_character_),
    "character"
  )
})

test_that("non-DIMACS numerals are rejected", {
  p <- tempfile(fileext = ".cnf")
  writeLines(c("p cnf 1 1", "0x10 0"), p)
  expect_error(read_dimacs(p), "unexpected token '0x10'")
  writeLines(c("p cnf 1 1", "1e3 0"), p)
  expect_error(read_dimacs(p), "unexpected token '1e3'")
  writeLines(c("p cnf 1 1", "1.0 0"), p)
  expect_error(read_dimacs(p), "unexpected token '1.0'")
  writeLines(c("p cnf 2 1", "+1 -2 0"), p)
  expect_equal(read_dimacs(p), list(c(1L, -2L)))
})

# --- #22 (8): single paths ---------------------------------------------------

test_that("DIMACS readers and writers take exactly one path", {
  expect_error(read_dimacs(c("a.cnf", "b.cnf")), "single file path")
  expect_error(read_dimacs(NA_character_), "single file path")
  p <- tempfile()
  expect_error(write_dimacs(list(1), c(p, p)), "single file path")
  expect_error(write_dimacs(list(1), 1), "single file path")
})
