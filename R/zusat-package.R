#' zusat: Boolean satisfiability with CaDiCaL
#'
#' Solves Boolean satisfiability (SAT) problems using a bundled copy of
#' CaDiCaL. Nothing needs installing beyond this package and a C++ compiler.
#'
#' @section Getting started:
#'
#' A formula is a list of clauses; a clause is a numeric vector of literals in
#' DIMACS convention, where `i` means "variable *i* is true" and `-i` its
#' negation. No terminating zero is needed.
#'
#' ```r
#' sat_solve(list(c(1, 2), c(-1, 2)))
#' ```
#'
#' The result is a data frame of `variable` and `value`, with the outcome in
#' an attribute that [sat_status()] reads. It keeps that shape whether or not
#' the formula was satisfiable, so you can index it without branching first.
#'
#' @section The harder part:
#'
#' The API is small. Turning a question into clauses is where the work is, and
#' where mistakes produce a confident wrong answer rather than an error. The
#' article *Modelling a problem as SAT* works an example through end to end.
#'
#' @section Map of the package:
#'
#' \describe{
#'   \item{Solving}{[sat_solve()] for a formula or a solver, [sat_solver()]
#'     and [sat_add()] to build one up incrementally, [sat_solutions()] to
#'     enumerate more than one model.}
#'   \item{Cardinality}{[sat_at_most()], [sat_at_least()] and [sat_exactly()]
#'     encode "at most k of these", which CNF cannot state directly and most
#'     real models need.}
#'   \item{Steering}{Assumptions via [sat_solve()], a one-shot clause via
#'     [sat_constrain()], resource limits via [sat_limit()], and
#'     [sat_fixed()] for what the solver has already proved.}
#'   \item{Proofs}{[sat_trace_proof()] records a DRAT or LRAT derivation, so
#'     an unsatisfiability claim can be checked by a tool that trusts neither
#'     CaDiCaL nor this package.}
#'   \item{Files}{[read_dimacs()] and [write_dimacs()], the format every
#'     solver and benchmark set speaks.}
#' }
#'
#' @section Two things that bite:
#'
#' `"unknown"` is not a weaker `"unsat"`. It means the solver stopped inside a
#' limit set by [sat_limit()] without deciding, and the question is still
#' open.
#'
#' Enumeration stops at `limit`, and a truncated result looks exactly like an
#' exhaustive one. [sat_complete()] is how you tell them apart.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom stats setNames
#' @importFrom utils head
#' @useDynLib zusat, .registration = TRUE
## usethis namespace: end
NULL
