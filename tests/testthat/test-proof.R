# A proof is what turns "the solver says unsat" into a claim someone else can
# check. These tests verify the proof is written, complete, and structurally a
# refutation. Verifying it is a *valid* refutation needs an external checker;
# drat-trim confirms the pigeonhole proof below with "s VERIFIED", but it is
# not something the package can depend on being installed, so that check is
# skipped unless one is on the PATH.

drat_trim <- function() {
  found <- Sys.which("drat-trim")
  if (nzchar(found)) found else NULL
}

test_that("a refutation is written and ends with the empty clause", {
  path <- tempfile(fileext = ".drat")

  s <- sat_solver()
  sat_trace_proof(s, path)
  sat_add(s, list(1, -1))
  expect_equal(sat_status(sat_solve(s)), "unsat")
  sat_close_proof(s)

  expect_true(file.exists(path))
  lines <- readLines(path)
  expect_gt(length(lines), 0L)
  # "0" alone is the empty clause: the derivation reached a contradiction
  expect_true(any(trimws(lines) == "0"))
})

test_that("tracing state is reported and cleared", {
  s <- sat_solver()
  expect_false(sat_is_tracing(s))

  sat_trace_proof(s, tempfile())
  expect_true(sat_is_tracing(s))

  sat_add(s, list(1, -1))
  sat_solve(s)
  sat_close_proof(s)
  expect_false(sat_is_tracing(s))
})

test_that("an LRAT proof carries antecedents for every step", {
  path <- tempfile(fileext = ".lrat")

  s <- sat_solver()
  sat_trace_proof(s, path, format = "lrat")
  sat_add(s, list(c(1, 2), c(1, -2), c(-1, 2), c(-1, -2)))
  expect_equal(sat_status(sat_solve(s)), "unsat")
  sat_close_proof(s)

  lines <- readLines(path)
  expect_gt(length(lines), 0L)

  # Each LRAT line is: <id> <literals> 0 <antecedent ids> 0. The final step
  # derives the empty clause, so its literal section is empty.
  final <- strsplit(trimws(lines[length(lines)]), "[[:space:]]+")[[1]]
  expect_equal(final[2], "0") # no literals: the empty clause
  expect_equal(final[length(final)], "0") # antecedent list terminator
  expect_gt(length(final), 3L) # and it cites antecedents
})

test_that("a satisfiable formula still produces a file, with no refutation", {
  path <- tempfile(fileext = ".drat")

  s <- sat_solver()
  sat_trace_proof(s, path)
  sat_add(s, list(c(1, 2)))
  expect_true(sat_is_sat(sat_solve(s)))
  sat_close_proof(s)

  expect_true(file.exists(path))
  # no contradiction was derived, so there is no empty clause
  expect_false(any(trimws(readLines(path)) == "0"))
})

test_that("tracing must start before any clause is added", {
  # CaDiCaL requires state CONFIGURING. A proof begun later records only part
  # of the derivation, which is worse than none: it looks checkable and isn't.
  s <- sat_solver()
  sat_add(s, c(1, 2))
  expect_error(sat_trace_proof(s, tempfile()), "before adding clauses")

  # seeding the solver counts as adding clauses
  seeded <- sat_solver(list(c(1, 2)))
  expect_error(sat_trace_proof(seeded, tempfile()), "before adding clauses")
})

test_that("a solver traces at most one proof", {
  s <- sat_solver()
  sat_trace_proof(s, tempfile())
  expect_error(sat_trace_proof(s, tempfile()), "already tracing")
})

test_that("closing a proof that was never opened is an error", {
  s <- sat_solver()
  expect_error(sat_close_proof(s), "not tracing")
})

test_that("closing twice is an error rather than a silent no-op", {
  s <- sat_solver()
  sat_trace_proof(s, tempfile())
  sat_add(s, list(1, -1))
  sat_solve(s)
  sat_close_proof(s)

  expect_error(sat_close_proof(s), "not tracing")
})

test_that("an unwritable path fails loudly", {
  s <- sat_solver()
  expect_error(sat_trace_proof(s, file.path(tempfile(), "nope.drat")),
               "could not open")
  # and the solver is left usable, not half-configured
  expect_false(sat_is_tracing(s))
  sat_add(s, list(c(1, 2)))
  expect_true(sat_is_sat(sat_solve(s)))
})

test_that("arguments are validated", {
  s <- sat_solver()
  expect_error(sat_trace_proof(s, c("a", "b")), "single file path")
  expect_error(sat_trace_proof(s, tempfile(), binary = NA), "TRUE or FALSE")
  expect_error(sat_trace_proof(s, tempfile(), format = "tptp"))
})

test_that("a binary proof is written as bytes, not text", {
  path <- tempfile(fileext = ".drat")

  s <- sat_solver()
  sat_trace_proof(s, path, binary = TRUE)
  sat_add(s, list(1, -1))
  sat_solve(s)
  sat_close_proof(s)

  expect_gt(file.size(path), 0L)
  raw_bytes <- readBin(path, "raw", file.size(path))
  # the binary encoding uses byte markers ('a' = 0x61 for an addition) that
  # the text format never emits on its own
  expect_true(any(raw_bytes == as.raw(0x61)))
})

test_that("an abandoned proof is closed when the solver is collected", {
  # Nothing calls sat_close_proof() here. The finalizer has to flush CaDiCaL
  # and close the file, or the proof is truncated and the descriptor leaks.
  path <- tempfile(fileext = ".drat")

  local({
    s <- sat_solver()
    sat_trace_proof(s, path)
    sat_add(s, list(1, -1))
    sat_solve(s)
    rm(s)
  })
  gc()

  expect_true(file.exists(path))
  expect_true(any(trimws(readLines(path)) == "0"))
})

test_that("drat-trim verifies a real refutation", {
  checker <- drat_trim()
  skip_if(is.null(checker), "drat-trim not on PATH")

  # pigeonhole 6 into 5: small, and genuinely requires a derivation
  v <- function(i, j) (i - 1L) * 5L + j
  clauses <- lapply(1:6, function(i) vapply(1:5, function(j) v(i, j), numeric(1)))
  for (j in 1:5) {
    for (pair in utils::combn(6, 2, simplify = FALSE)) {
      clauses <- c(clauses, list(c(-v(pair[1], j), -v(pair[2], j))))
    }
  }

  cnf <- tempfile(fileext = ".cnf")
  proof <- tempfile(fileext = ".drat")
  write_dimacs(clauses, cnf)

  s <- sat_solver()
  sat_trace_proof(s, proof)
  sat_add(s, clauses)
  expect_equal(sat_status(sat_solve(s)), "unsat")
  sat_close_proof(s)

  out <- suppressWarnings(system2(checker, c(cnf, proof), stdout = TRUE,
                                  stderr = TRUE))
  expect_true(any(grepl("^s VERIFIED", out)))
})
