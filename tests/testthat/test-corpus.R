# CaDiCaL's own regression corpus, vendored by tools/vendor-cadical.sh.
#
# This is the strongest correctness signal available to the package: 50
# instances that upstream uses to test this solver, with outcomes declared by
# upstream rather than by us. Hand-written tests check the binding; these
# check that the binding plus the vendored solver plus our build flags still
# produce the answers CaDiCaL's authors expect.
#
# Expected outcomes come from run.sh and are vendored alongside. They are
# deliberately not inferred from whether a .sol file exists: block0,
# elimredundant and sub0 are satisfiable feature tests that ship without one,
# and inferring that way reports three false failures.

corpus_dir <- function() {
  system.file("extdata", "cadical", package = "zusat")
}

read_expectations <- function() {
  path <- file.path(corpus_dir(), "expected.tsv")
  if (!file.exists(path)) {
    return(NULL)
  }
  utils::read.delim(path, stringsAsFactors = FALSE)
}

test_that("the vendored corpus is present and self-consistent", {
  expected <- read_expectations()
  skip_if(is.null(expected), "corpus not installed")

  expect_gt(nrow(expected), 0L)
  expect_named(expected, c("name", "expected"))
  expect_true(all(expected$expected %in% c("sat", "unsat")))

  files <- file.path(corpus_dir(), paste0(expected$name, ".cnf"))
  expect_true(all(file.exists(files)))

  # every .cnf shipped should have a declared outcome, or it is dead weight
  shipped <- sub("[.]cnf$", "", basename(
    list.files(corpus_dir(), pattern = "[.]cnf$")))
  expect_setequal(shipped, expected$name)
})

test_that("zusat agrees with CaDiCaL on every corpus instance", {
  expected <- read_expectations()
  skip_if(is.null(expected), "corpus not installed")

  disagreements <- character()

  for (i in seq_len(nrow(expected))) {
    name <- expected$name[i]
    path <- file.path(corpus_dir(), paste0(name, ".cnf"))

    clauses <- read_dimacs(path)
    got <- sat_status(sat_solve(clauses))

    if (!identical(got, expected$expected[i])) {
      disagreements <- c(
        disagreements,
        sprintf("%s: expected %s, got %s", name, expected$expected[i], got)
      )
    }
  }

  expect_equal(disagreements, character())
})

test_that("every satisfiable corpus instance yields a model that checks out", {
  expected <- read_expectations()
  skip_if(is.null(expected), "corpus not installed")

  sat_names <- expected$name[expected$expected == "sat"]
  expect_gt(length(sat_names), 0L)

  for (name in sat_names) {
    clauses <- read_dimacs(file.path(corpus_dir(), paste0(name, ".cnf")))
    # the empty formula is satisfiable and has nothing to check
    if (length(clauses) == 0L) next

    sol <- sat_solve(clauses)
    expect_true(sat_is_sat(sol))

    m <- sat_assignment(sol)
    if (length(m) == 0L) next
    expect_true(satisfies_all(clauses, m),
                info = sprintf("model does not satisfy %s", name))
  }
})
