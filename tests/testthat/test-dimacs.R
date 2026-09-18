write_lines_to_temp <- function(...) {
  path <- tempfile(fileext = ".cnf")
  writeLines(c(...), path)
  path
}

test_that("a plain DIMACS file round-trips", {
  clauses <- list(c(1, 2), c(-1, 3), c(-2, -3))
  path <- tempfile(fileext = ".cnf")

  write_dimacs(clauses, path)
  expect_equal(read_dimacs(path), lapply(clauses, as.integer))
})

test_that("the header records the right counts", {
  path <- tempfile(fileext = ".cnf")
  write_dimacs(list(c(1, 2), c(-1, 5)), path)

  header <- grep("^p ", readLines(path), value = TRUE)
  expect_equal(header, "p cnf 5 2")
})

test_that("comments are written and ignored on the way back", {
  path <- tempfile(fileext = ".cnf")
  write_dimacs(list(c(1, 2)), path, comment = c("first", "second"))

  lines <- readLines(path)
  expect_true(any(lines == "c first"))
  expect_true(any(lines == "c second"))
  expect_equal(read_dimacs(path), list(1:2))
})

test_that("clauses may span lines, and lines may hold several clauses", {
  spanning <- write_lines_to_temp("p cnf 3 2", "1 2", "3 0", "-1 -2 0")
  expect_equal(read_dimacs(spanning), list(c(1L, 2L, 3L), c(-1L, -2L)))

  packed <- write_lines_to_temp("p cnf 2 2", "1 2 0 -1 -2 0")
  expect_equal(read_dimacs(packed), list(c(1L, 2L), c(-1L, -2L)))
})

test_that("a missing p header is tolerated", {
  # plenty of files in the wild have none
  path <- write_lines_to_temp("1 2 0", "-1 0")
  expect_equal(read_dimacs(path), list(c(1L, 2L), -1L))
})

test_that("a header disagreeing with the body does not win", {
  # the clauses are the truth; the counts are frequently wrong
  path <- write_lines_to_temp("p cnf 99 99", "1 2 0")
  expect_equal(read_dimacs(path), list(c(1L, 2L)))
})

test_that("an unterminated final clause is still read", {
  path <- write_lines_to_temp("p cnf 2 2", "1 2 0", "-1 -2")
  expect_equal(read_dimacs(path), list(c(1L, 2L), c(-1L, -2L)))
})

test_that("a SATLIB trailer does not become an empty clause", {
  # SATLIB instances end with "%" then "0". Read naively, that 0 terminates an
  # empty clause and turns every one of them unsatisfiable.
  path <- write_lines_to_temp("p cnf 2 1", "1 2 0", "%", "0", "")

  expect_equal(read_dimacs(path), list(c(1L, 2L)))
  expect_equal(sat_status(sat_solve(read_dimacs(path))), "sat")
})

test_that("an empty file is an empty formula", {
  path <- write_lines_to_temp("c just a comment", "p cnf 0 0")
  expect_equal(read_dimacs(path), list())
})

test_that("a genuine empty clause is preserved", {
  # "0" on its own is the empty clause, which is unsatisfiable
  path <- write_lines_to_temp("p cnf 1 1", "0")
  expect_equal(read_dimacs(path), list(integer()))
  expect_equal(sat_status(sat_solve(read_dimacs(path))), "unsat")
})

test_that("malformed input is rejected with the offending token", {
  path <- write_lines_to_temp("p cnf 2 1", "1 banana 0")
  expect_error(read_dimacs(path), "banana")

  fractional <- write_lines_to_temp("p cnf 2 1", "1 2.5 0")
  expect_error(read_dimacs(fractional), "non-integer")
})

test_that("a missing file is an error, not an empty formula", {
  expect_error(read_dimacs(tempfile()), "no such file")
})

test_that("write_dimacs validates its input", {
  expect_error(write_dimacs(c(1, 2), tempfile()), "must be a list")
  expect_error(write_dimacs(list(c(1, 0)), tempfile()), "must not contain 0")
})

test_that("a formula read from disk solves the same as one built in memory", {
  clauses <- list(c(1, 2), c(-1, 2), c(1, -2))
  path <- tempfile(fileext = ".cnf")
  write_dimacs(clauses, path)

  expect_equal(
    sat_status(sat_solve(clauses)),
    sat_status(sat_solve(read_dimacs(path)))
  )
})
