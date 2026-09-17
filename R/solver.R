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
#' Creates an incremental SAT solver backed by a bundled copy of CaDiCaL. The
#' handle keeps its state across calls, so clauses added earlier stay in
#' effect. This is what makes incremental solving possible, and it is the
#' reason to reach for a solver rather than calling [sat_solve()] on a
#' formula: adding a clause and re-solving reuses everything the solver
#' already learned.
#'
#' The underlying solver is released when the handle is garbage collected.
#'
#' @param formula Optional list of clauses to seed the solver with, as in
#'   [sat_add()]. Equivalent to creating an empty solver and adding them.
#' @return An object of class `zusat_solver`.
#' @seealso [sat_add()] to add clauses, [sat_solve()] to solve.
#' @export
#' @examples
#' s <- sat_solver(list(c(1, 2), c(-1, 2)))
#' sat_solve(s)
#'
#' # incremental: the second solve reuses the first one's work
#' sat_add(s, -2)
#' sat_solve(s)
sat_solver <- function(formula = NULL) {
  solver <- .Call(zusat_solver_new)
  if (!is.null(formula)) {
    sat_add(solver, formula)
  }
  solver
}

#' @export
print.zusat_solver <- function(x, ...) {
  cat(sprintf("<zusat_solver> %s\n", sat_signature()))
  cat(sprintf("  variables:      %d\n", sat_n_vars(x)))
  cat(sprintf("  active clauses: %s\n", format(sat_n_clauses(x))))
  invisible(x)
}

#' Add clauses to a solver
#'
#' Clauses use DIMACS conventions: a positive number `i` is the literal
#' "variable i is true", a negative number `-i` is its negation. No
#' terminating zero is needed; it is added internally.
#'
#' @param solver A `zusat_solver` from [sat_solver()].
#' @param x Either one clause, as a numeric vector of non-zero literals, or
#'   several, as a list of such vectors. An empty vector is the empty clause,
#'   which makes the formula unsatisfiable.
#' @return `solver`, invisibly, so calls can be chained.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_add(s, c(1, -2))                    # one clause
#' sat_add(s, list(c(2, 3), c(-1, 3)))     # several
sat_add <- function(solver, x) {
  if (is.list(x)) {
    for (clause in x) {
      .Call(zusat_add_clause, solver, as_literals(clause, "clauses"))
    }
  } else {
    .Call(zusat_add_clause, solver, as_literals(x))
  }
  invisible(solver)
}

#' Solve a formula
#'
#' Solves either a formula given directly, or the current state of a solver.
#' Both return the same kind of object, so code that reads the result does
#' not need to know which was used.
#'
#' Long solves respond to Ctrl-C. The solver stops at its next safe point and
#' raises a catchable error; a solver handle stays usable afterwards.
#'
#' @param x A list of clauses, or a `zusat_solver`.
#' @param assumptions Numeric vector of literals assumed true for this call
#'   only. Assumptions are never retained between calls. When the result is
#'   unsatisfiable, [sat_failed()] reports which of them the solver used.
#' @param ... Passed to methods.
#' @return A [zusat_solution].
#' @seealso [sat_status()] to read the outcome, [sat_solutions()] to
#'   enumerate more than one model.
#' @export
#' @examples
#' # a formula directly
#' sat_solve(list(c(1, 2), c(-1, 2)))
#'
#' # or a solver, for incremental work
#' s <- sat_solver(list(c(1, 2)))
#' sat_solve(s, assumptions = -1)
sat_solve <- function(x, assumptions = integer(), ...) {
  UseMethod("sat_solve")
}

#' @rdname sat_solve
#' @export
sat_solve.zusat_solver <- function(x, assumptions = integer(), ...) {
  assumptions <- as_literals(assumptions, "assumptions")
  started <- proc.time()[["elapsed"]]
  status <- .Call(zusat_solve, x, assumptions)
  elapsed <- proc.time()[["elapsed"]] - started

  new_solution(
    status    = status,
    solver    = x,
    elapsed   = elapsed
  )
}

#' @rdname sat_solve
#' @export
sat_solve.default <- function(x, assumptions = integer(), ...) {
  if (!is.list(x)) {
    stop("`x` must be a list of clauses or a zusat_solver", call. = FALSE)
  }
  sat_solve(sat_solver(x), assumptions = assumptions, ...)
}

#' Which assumptions caused unsatisfiability
#'
#' After [sat_solve()] returns `"unsat"` for a call made with assumptions,
#' this reports the subset the solver actually used to derive the conflict.
#'
#' It is an unsatisfiable core over the *assumptions*, not over the clauses.
#' CaDiCaL does not expose clause-level cores, so unlike some solvers there
#' is no way to ask which of the original clauses are jointly contradictory.
#'
#' @param solver A `zusat_solver`.
#' @param assumptions The same literals passed to [sat_solve()].
#' @return A logical vector marking the assumptions that were used.
#' @export
#' @examples
#' s <- sat_solver(list(c(1, 2)))
#' sat_solve(s, assumptions = c(-1, -2))
#' sat_failed(s, c(-1, -2))
sat_failed <- function(solver, assumptions) {
  .Call(zusat_failed, solver, as_literals(assumptions, "assumptions"))
}

#' Read variable assignments directly from a solver
#'
#' A lower-level alternative to the data frame returned by [sat_solve()],
#' for when only a few variables matter or the allocation shows up in a
#' profile. Meaningful only directly after a solve returned `"sat"`.
#'
#' @param solver A `zusat_solver`.
#' @param vars Numeric vector of variable indices. Defaults to every variable
#'   the solver knows about.
#' @return A logical vector the same length as `vars`. `NA` marks a variable
#'   the solver left unassigned because either polarity extends the model.
#' @export
#' @examples
#' s <- sat_solver(list(c(1, 2)))
#' sat_solve(s)
#' sat_value(s, 1:2)
sat_value <- function(solver, vars = seq_len(sat_n_vars(solver))) {
  .Call(zusat_value, solver, as.integer(vars))
}

#' Size of the formula a solver holds
#'
#' `sat_n_clauses()` reports CaDiCaL's count of *active* original clauses,
#' which is not the same as the number passed to [sat_add()]. Clauses the
#' solver learned during search are excluded, being an artefact of search
#' rather than of the formula. So are clauses it has since disposed of: a
#' unit clause becomes a fixed assignment and stops being counted, and
#' simplification removes others. Adding `1` and `-1` and then solving
#' therefore leaves a count of zero.
#'
#' If you need the number of clauses you supplied, count them yourself --
#' the solver does not keep that figure.
#'
#' @param solver A `zusat_solver`.
#' @return A single number.
#' @export
#' @examples
#' s <- sat_solver(list(c(1, 2), c(-1, 3)))
#' sat_n_vars(s)
#' sat_n_clauses(s)
sat_n_vars <- function(solver) {
  .Call(zusat_n_vars, solver)
}

#' @rdname sat_n_vars
#' @export
sat_n_clauses <- function(solver) {
  .Call(zusat_n_clauses, solver)
}

#' Get or set a CaDiCaL option
#'
#' CaDiCaL exposes several hundred integer-valued tuning options, for example
#' `"elim"`, `"vivify"` or `"restartint"`. Names are CaDiCaL's own.
#'
#' @param solver A `zusat_solver`.
#' @param name A single option name.
#' @param value An integer to set. When missing, the current value is
#'   returned instead.
#' @return The option value; invisibly when setting.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_option(s, "elim")
#' sat_option(s, "elim", 0)
sat_option <- function(solver, name, value) {
  if (missing(value)) {
    return(.Call(zusat_get_option, solver, as.character(name)))
  }
  .Call(zusat_set_option, solver, as.character(name), as.integer(value))
  invisible(value)
}

#' Version of the bundled CaDiCaL
#'
#' @return A single string, for example `"cadical-3.0.1"`.
#' @export
#' @examples
#' sat_signature()
sat_signature <- function() {
  .Call(zusat_signature)
}
