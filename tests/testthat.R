# This file is part of the standard setup for testthat.
# It is recommended that you do not modify it.
#
# Where should you do additional test configuration?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html

# testthat is a suggested package, and CRAN runs a check flavour with
# suggested packages unavailable. Writing R Extensions requires them to be
# used conditionally, so an unguarded library(testthat) here is an ERROR on
# that flavour -- the runner dies before a single test executes.
#
# Running no tests when testthat is absent is the accepted outcome: the
# flavour checks that the package stands up without its suggested packages,
# not that the suite does.
if (requireNamespace("testthat", quietly = TRUE)) {
  library(testthat)
  library(zusat)

  test_check("zusat")
}
