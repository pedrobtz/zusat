# Coerce to DIMACS literals, rejecting what as.integer() would otherwise
# accept silently: "1" becomes 1L and 1.7 becomes 1L, so a typo in a formula
# turns into a different formula rather than an error.
as_literals <- function(x, arg = "literals") {
  if (is.null(x)) {
    return(integer())
  }
  if (!is.numeric(x) || is.factor(x)) {
    stop(sprintf("`%s` must be numeric, not %s", arg, class(x)[1]), call. = FALSE)
  }
  if (is.double(x) && any(x != trunc(x), na.rm = TRUE)) {
    stop(sprintf("`%s` must be whole numbers", arg), call. = FALSE)
  }
  if (anyNA(x)) {
    stop(sprintf("`%s` must not be NA", arg), call. = FALSE)
  }
  x <- as.integer(x)
  if (any(x == 0L)) {
    stop(sprintf("`%s` must not contain 0; clauses are terminated automatically", arg),
         call. = FALSE)
  }
  x
}

#' Create a CaDiCaL solver
#'
#' Creates an incremental SAT solver backed by a vendored copy of CaDiCaL.
#' The returned handle keeps state across calls, so clauses added earlier
#' remain in effect: this is what makes incremental solving possible.
#'
#' The underlying solver is released automatically when the handle is
#' garbage collected.
#'
#' @return An object of class `zusat_solver`.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_add(s, c(1L, 2L))
#' sat_solve(s)
sat_solver <- function() {
  .Call(zusat_solver_new)
}

#' @export
print.zusat_solver <- function(x, ...) {
  cat("<zusat_solver>", sat_signature(), "\n")
  cat("  variables:", .Call(zusat_n_vars, x), "\n")
  invisible(x)
}

#' Add a clause to a solver
#'
#' Clauses use DIMACS conventions: a positive integer `i` is the literal
#' "variable i is true", a negative integer `-i` is its negation. Do not
#' include a terminating zero; that is added internally.
#'
#' @param solver A `zusat_solver` from [sat_solver()].
#' @param literals Integer vector of non-zero literals. An empty vector adds
#'   the empty clause, which makes the formula unsatisfiable.
#' @return `solver`, invisibly, so calls can be chained.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_add(s, c(1L, -2L))
sat_add <- function(solver, literals) {
  .Call(zusat_add_clause, solver, as_literals(literals))
  invisible(solver)
}

#' Add several clauses at once
#'
#' @param solver A `zusat_solver`.
#' @param clauses A list of integer vectors, each one a clause.
#' @return `solver`, invisibly.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_add_all(s, list(c(1L, 2L), c(-1L, 2L)))
sat_add_all <- function(solver, clauses) {
  if (!is.list(clauses)) {
    stop("`clauses` must be a list of integer vectors", call. = FALSE)
  }
  for (cl in clauses) {
    .Call(zusat_add_clause, solver, as_literals(cl, "clauses"))
  }
  invisible(solver)
}

#' Solve the current formula
#'
#' Long solves can be interrupted with Ctrl-C; the solver stops at its next
#' safe point and the handle stays usable.
#'
#' @param solver A `zusat_solver`.
#' @param assumptions Integer vector of literals assumed true for this call
#'   only. Assumptions are not retained across calls.
#' @return One of `"sat"`, `"unsat"`, or `"unknown"`.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_add(s, c(1L, 2L))
#' sat_solve(s)
#' sat_solve(s, assumptions = -1L)
sat_solve <- function(solver, assumptions = integer()) {
  .Call(zusat_solve, solver, as_literals(assumptions, "assumptions"))
}

#' Read variable assignments from a satisfying model
#'
#' Only meaningful directly after [sat_solve()] returned `"sat"`.
#'
#' @param solver A `zusat_solver`.
#' @param vars Integer vector of variable indices. Defaults to all variables
#'   known to the solver.
#' @return A logical vector the same length as `vars`. `NA` marks a variable
#'   the solver left unassigned because either polarity extends the model.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_add(s, c(1L, 2L))
#' if (sat_solve(s) == "sat") sat_model(s)
sat_model <- function(solver, vars = seq_len(sat_n_vars(solver))) {
  .Call(zusat_value, solver, as.integer(vars))
}

#' Identify which assumptions caused unsatisfiability
#'
#' After [sat_solve()] returns `"unsat"` for a call made with assumptions,
#' this reports the subset of those assumptions the solver actually used.
#' It is a small unsatisfiable core over the assumptions, not over clauses.
#'
#' @param solver A `zusat_solver`.
#' @param assumptions The same integer vector passed to [sat_solve()].
#' @return A logical vector marking the assumptions that were used.
#' @export
sat_failed <- function(solver, assumptions) {
  .Call(zusat_failed, solver, as_literals(assumptions, "assumptions"))
}

#' Number of variables known to the solver
#'
#' @param solver A `zusat_solver`.
#' @return An integer scalar.
#' @export
sat_n_vars <- function(solver) {
  .Call(zusat_n_vars, solver)
}

#' Get or set a CaDiCaL option
#'
#' CaDiCaL exposes several hundred integer-valued tuning options, for example
#' `"elim"`, `"vivify"`, or `"restartint"`. Names are as documented by
#' CaDiCaL itself.
#'
#' @param solver A `zusat_solver`.
#' @param name A single option name.
#' @param value An integer value to set. When missing, the current value is
#'   returned instead.
#' @return The option value, invisibly when setting.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_option(s, "elim")
sat_option <- function(solver, name, value) {
  if (missing(value)) {
    return(.Call(zusat_get_option, solver, as.character(name)))
  }
  .Call(zusat_set_option, solver, as.character(name), as.integer(value))
  invisible(value)
}

#' Version string of the vendored CaDiCaL
#'
#' @return A single string, for example `"cadical-3.0.1"`.
#' @export
#' @examples
#' sat_signature()
sat_signature <- function() {
  .Call(zusat_signature)
}
