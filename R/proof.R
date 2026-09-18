#' Record a proof of unsatisfiability
#'
#' When a solver reports `"unsat"` you are taking its word for it. A proof
#' makes the claim checkable: CaDiCaL writes every step of the derivation to
#' a file, and an independent checker can verify that the empty clause really
#' does follow from your formula. Nothing about zusat, CaDiCaL or this
#' binding has to be trusted for that check to be meaningful.
#'
#' A satisfiable formula needs no proof, because the model is the evidence --
#' you can check it yourself with [sat_assignment()].
#'
#' @section Tracing must start before any clause is added:
#'
#' CaDiCaL requires the solver to be freshly created. Add a clause first and
#' it refuses, because the proof would record only part of the derivation and
#' a partial proof is worse than none -- it looks checkable and is not. So
#' trace first, then build the formula:
#'
#' ```r
#' s <- sat_solver()          # no formula yet
#' sat_trace_proof(s, path)
#' sat_add(s, clauses)        # now build it
#' sat_solve(s)
#' sat_close_proof(s)
#' ```
#'
#' Passing a formula to [sat_solver()] counts as adding clauses, so create the
#' solver empty when you intend to trace.
#'
#' @section Closing the file:
#'
#' The proof is not complete until [sat_close_proof()] returns. CaDiCaL
#' buffers its output, so reading the file before then gives a truncated
#' proof that most checkers will reject. If a solver is garbage collected
#' while still tracing, the file is closed then instead.
#'
#' @section Formats:
#'
#' \describe{
#'   \item{`"drat"`}{The default, and what nearly every checker reads --
#'     `drat-trim` being the usual one. Compact, but a checker has to
#'     reconstruct the reasoning for each step, which can take longer than
#'     the original solve.}
#'   \item{`"lrat"`}{Records the antecedents of every step, so a checker
#'     verifies it by simple lookup rather than by re-deriving anything.
#'     Larger files, far faster and simpler to check, and the format used
#'     where the check itself has to be trusted.}
#' }
#'
#' Other formats CaDiCaL supports -- FRAT, VeriPB, IDRUP, LIDRUP -- are
#' reachable by setting the corresponding option with [sat_option()] before
#' calling this.
#'
#' @param solver A `zusat_solver` with no clauses added yet.
#' @param path File to write the proof to. Overwritten if it exists.
#' @param format `"drat"` or `"lrat"`.
#' @param binary Write the binary encoding of the format. Smaller, but not
#'   readable and not accepted by every checker; the default writes text.
#' @return `solver`, invisibly.
#' @seealso [sat_close_proof()], [sat_is_tracing()]
#' @export
#' @examples
#' path <- tempfile(fileext = ".drat")
#'
#' s <- sat_solver()
#' sat_trace_proof(s, path)
#' sat_add(s, list(1, -1)) # contradictory
#' sat_solve(s)
#' sat_close_proof(s)
#'
#' # the proof ends with the empty clause, written as a bare "0"
#' tail(readLines(path), 1)
sat_trace_proof <- function(solver, path, format = c("drat", "lrat"),
                            binary = FALSE) {
  format <- match.arg(format)
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    stop("`path` must be a single file path", call. = FALSE)
  }
  if (!is.logical(binary) || length(binary) != 1L || is.na(binary)) {
    stop("`binary` must be TRUE or FALSE", call. = FALSE)
  }
  if (sat_n_vars(solver) > 0L) {
    stop("start tracing before adding clauses: CaDiCaL can only trace a ",
         "complete proof from a freshly created solver", call. = FALSE)
  }

  # Format and encoding are options, and like tracing itself they have to be
  # set while the solver is still being configured.
  sat_option(solver, "binary", as.integer(binary))
  if (format == "lrat") {
    sat_option(solver, "lrat", 1L)
  }

  .Call(zusat_trace_proof, solver, path.expand(path))
  invisible(solver)
}

#' Finish writing a proof
#'
#' Flushes and closes the proof file. The proof is incomplete until this
#' returns, so do not read the file before calling it.
#'
#' @param solver A `zusat_solver` that is tracing a proof.
#' @return `solver`, invisibly.
#' @seealso [sat_trace_proof()]
#' @export
#' @examples
#' path <- tempfile(fileext = ".drat")
#' s <- sat_solver()
#' sat_trace_proof(s, path)
#' sat_add(s, list(1, -1))
#' sat_solve(s)
#' sat_close_proof(s)
sat_close_proof <- function(solver) {
  .Call(zusat_close_proof, solver)
  invisible(solver)
}

#' Is this solver recording a proof?
#'
#' @param solver A `zusat_solver`.
#' @return A single logical.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_is_tracing(s)
#' sat_trace_proof(s, tempfile())
#' sat_is_tracing(s)
sat_is_tracing <- function(solver) {
  .Call(zusat_tracing_proof, solver)
}

#' Write the concluding proof step
#'
#' Emits the conclusion of the last solve into the proof. Only meaningful for
#' the interactive formats (IDRUP and LIDRUP), where a proof records a whole
#' session of solves rather than a single refutation. For DRAT and LRAT the
#' refutation already ends the proof and this does nothing.
#'
#' @param solver A `zusat_solver`.
#' @return `solver`, invisibly.
#' @export
#' @examples
#' # a no-op for DRAT, but harmless and shown here for the call shape
#' path <- tempfile(fileext = ".drat")
#' s <- sat_solver()
#' sat_trace_proof(s, path)
#' sat_add(s, list(1, -1))
#' sat_solve(s)
#' sat_conclude(s)
#' sat_close_proof(s)
sat_conclude <- function(solver) {
  .Call(zusat_conclude, solver)
  invisible(solver)
}
