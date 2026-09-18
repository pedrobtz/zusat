# CaDiCaL accepts exactly these limit names. The C wrapper ccadical_limit()
# discards the flag saying whether a name was recognised, so an unknown one is
# silently ignored -- and a solve you believed was bounded runs to completion.
# Checking here is the only place the mistake can be caught.
sat_limits <- c("conflicts", "decisions", "preprocessing", "localsearch",
                "ticks", "terminate")

#' Bound how hard a solve may work
#'
#' SAT is NP-complete, so an innocuous-looking formula can take longer than
#' the remaining age of the universe. A limit makes a solve give up instead,
#' returning `"unknown"` rather than an answer.
#'
#' This is what you want before calling [sat_solve()] anywhere a hang is
#' unacceptable: inside a loop, a Shiny app, or a scheduled job.
#'
#' @section Limits last one solve:
#'
#' Like assumptions, limits are consumed by the next [sat_solve()] and are not
#' retained afterwards. Set them again before each call.
#'
#' @param solver A `zusat_solver`.
#' @param name One of `"conflicts"`, `"decisions"`, `"preprocessing"`,
#'   `"localsearch"`, `"ticks"` or `"terminate"`. `"conflicts"` is the usual
#'   choice: it bounds search effort in the unit solver authors reason about,
#'   and is roughly proportional to work done.
#' @param value Maximum for that measure. A negative value means no limit.
#' @return `solver`, invisibly.
#' @seealso [sat_solve()], [sat_status()]
#' @export
#' @examples
#' s <- sat_solver(list(c(1, 2), c(-1, 2)))
#' sat_limit(s, "conflicts", 1000)
#' sat_solve(s)
sat_limit <- function(solver, name, value) {
  name <- as.character(name)
  if (length(name) != 1L || is.na(name)) {
    stop("`name` must be a single limit name", call. = FALSE)
  }
  if (!name %in% sat_limits) {
    stop(sprintf("unknown limit '%s'; must be one of %s", name,
                 paste(sprintf("'%s'", sat_limits), collapse = ", ")),
         call. = FALSE)
  }
  if (!is.numeric(value) || length(value) != 1L || is.na(value)) {
    stop("`value` must be a single number", call. = FALSE)
  }
  .Call(zusat_limit, solver, name, as.integer(value))
  invisible(solver)
}

#' Add a clause that holds for one solve only
#'
#' Assumptions can only fix individual literals. A constraint is a whole
#' clause -- "at least one of these" -- that applies to the next
#' [sat_solve()] and is then discarded.
#'
#' Without this, asking "is the formula satisfiable with at least one of
#' x1, x2, x3 true?" means permanently adding that clause and then having no
#' way to take it back.
#'
#' A solver holds at most one constraint at a time; setting a new one replaces
#' the last.
#'
#' @param solver A `zusat_solver`.
#' @param literals Numeric vector of non-zero literals. An empty vector sets
#'   the empty constraint, which makes the next solve unsatisfiable.
#' @return `solver`, invisibly.
#' @seealso [sat_constraint_failed()] to learn whether it caused
#'   unsatisfiability.
#' @export
#' @examples
#' s <- sat_solver(list(c(1, 2)))
#'
#' # require at least one of x1, x2 to be false, just this once
#' sat_constrain(s, c(-1, -2))
#' sat_solve(s)
#'
#' # gone again
#' sat_solve(s)
sat_constrain <- function(solver, literals) {
  .Call(zusat_constrain, solver, as_literals(literals, "literals"))
  invisible(solver)
}

#' Did the constraint cause unsatisfiability?
#'
#' After [sat_solve()] returns `"unsat"` for a call made with
#' [sat_constrain()], this reports whether the constraint was responsible --
#' the constraint-level counterpart of [sat_failed()].
#'
#' @param solver A `zusat_solver`.
#' @return A single logical.
#' @export
#' @examples
#' s <- sat_solver(list(1))
#' sat_constrain(s, -1)
#' sat_solve(s)
#' sat_constraint_failed(s)
sat_constraint_failed <- function(solver) {
  .Call(zusat_constraint_failed, solver)
}

#' Literals the solver has proved outright
#'
#' Reports which literals are fixed at the root of the search: true in every
#' model, or false in every model. This is the formula's *backbone* as far as
#' the solver has discovered it, and unlike [sat_value()] it does not depend
#' on a particular model.
#'
#' Useful for reading off what is already forced before deciding what to ask
#' next, and for simplifying a problem between rounds.
#'
#' The answer grows as the solver learns: a literal reported `NA` now may be
#' fixed after another [sat_solve()] or [sat_simplify()]. It is what has been
#' proved so far, not everything that is true.
#'
#' @param solver A `zusat_solver`.
#' @param literals Numeric vector of literals to ask about.
#' @return A logical vector: `TRUE` where the literal is implied, `FALSE`
#'   where its negation is implied, `NA` where neither has been established.
#' @export
#' @examples
#' s <- sat_solver(list(1, c(-1, 2)))
#' sat_solve(s)
#' sat_fixed(s, c(1, 2, -1))
sat_fixed <- function(solver, literals) {
  .Call(zusat_fixed, solver, as_literals(literals, "literals"))
}

#' Simplify a formula without solving it
#'
#' Runs CaDiCaL's inprocessing -- elimination, subsumption, probing and the
#' rest -- without the search that [sat_solve()] would do. Occasionally this
#' settles the formula on its own, which is why it returns a status.
#'
#' Worth doing before a long incremental session, or between rounds when many
#' clauses have been added.
#'
#' Like [sat_solve()], this consumes any assumptions and limits currently set.
#'
#' @param solver A `zusat_solver`.
#' @return One of `"sat"`, `"unsat"` or `"unknown"`; `"unknown"` is the usual
#'   outcome and simply means simplification alone did not decide it.
#' @export
#' @examples
#' s <- sat_solver(list(c(1, 2), c(-1, 2), c(1, -2)))
#' sat_simplify(s)
#' sat_solve(s)
sat_simplify <- function(solver) {
  .Call(zusat_simplify, solver)
}
