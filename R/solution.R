# A solution is a data frame first and a status carrier second.
#
# The shape follows rpicosat: one row per variable, with the outcome kept in
# an attribute rather than a column. That keeps the object type-stable --
# unsatisfiable and unknown results are the same data frame with no rows, not
# a different type -- so calling code can index it without first branching on
# what came back. It also means a result drops straight into dplyr, ggplot2
# or a join without conversion, which is the common thing to want.
#
# The cost is that the status is not visible in the printed data frame, hence
# sat_status() and the print method below.
#' The result of a solve
#'
#' `sat_solve()` returns an object of class `zusat_solution`. It *is* a data
#' frame, with one row per variable and columns:
#'
#' \describe{
#'   \item{variable}{integer, the variable number}
#'   \item{value}{logical, its value in the model. `NA` marks a variable the
#'     solver left unassigned because either polarity extends the model.}
#' }
#'
#' The outcome is carried as an attribute rather than a column, so the object
#' stays type-stable: an unsatisfiable result is the same data frame with no
#' rows, not a different type. Calling code can therefore index a result
#' without first branching on what came back, and a result drops into dplyr,
#' ggplot2 or a join with no conversion.
#'
#' Read the outcome with [sat_status()] or [sat_is_sat()], never by checking
#' `nrow()`: a satisfiable formula with no variables also has zero rows.
#'
#' @section Attributes:
#' `status` (one of `"sat"`, `"unsat"`, `"unknown"`), `n_vars`, `n_clauses`
#' and `elapsed` seconds. Prefer the accessors over reading these directly.
#'
#' @name zusat_solution
#' @seealso [sat_solve()], [sat_status()], [sat_assignment()]
#' @examples
#' sol <- sat_solve(list(c(1, 2)))
#' class(sol)
#' sat_status(sol)
NULL

new_solution <- function(status, solver, elapsed) {
  if (identical(status, "sat")) {
    n <- sat_n_vars(solver)
    variable <- seq_len(n)
    value <- sat_value(solver, variable)
  } else {
    variable <- integer()
    value <- logical()
  }

  out <- data.frame(variable = as.integer(variable), value = value)
  structure(
    out,
    class      = c("zusat_solution", "data.frame"),
    status     = status,
    n_vars     = sat_n_vars(solver),
    n_clauses  = sat_n_clauses(solver),
    elapsed    = elapsed
  )
}

#' The outcome of a solve
#'
#' @param x A [zusat_solution] or [zusat_solutions] object.
#' @return `sat_status()` returns one of `"sat"`, `"unsat"` or `"unknown"`.
#'   `sat_is_sat()` returns `TRUE` only for `"sat"`.
#'
#'   `"unknown"` means the solver stopped before deciding, which happens when
#'   a resource limit was set. It is not a weaker `"unsat"`.
#' @export
#' @examples
#' sol <- sat_solve(list(c(1, 2)))
#' sat_status(sol)
#' sat_is_sat(sol)
sat_status <- function(x) {
  attr(x, "status", exact = TRUE)
}

#' @rdname sat_status
#' @export
sat_is_sat <- function(x) {
  identical(sat_status(x), "sat")
}

#' A solution as a named logical vector
#'
#' Convenient when a model is used to index or subset, where the data frame
#' is more structure than the task needs.
#'
#' @param x A [zusat_solution].
#' @return A logical vector named by variable number, empty when the formula
#'   was not satisfiable. `NA` marks a variable the solver left unassigned
#'   because either polarity extends the model.
#' @export
#' @examples
#' sol <- sat_solve(list(c(1, 2), c(-1, 3)))
#' sat_assignment(sol)
sat_assignment <- function(x) {
  stats::setNames(x$value, as.character(x$variable))
}

#' @export
format.zusat_solution <- function(x, ...) {
  status <- sat_status(x)
  n_vars <- attr(x, "n_vars", exact = TRUE)
  sprintf(
    "<zusat_solution> %s  (%d variable%s, %s active clause%s, %.3fs)",
    status,
    n_vars, if (n_vars == 1L) "" else "s",
    format(attr(x, "n_clauses", exact = TRUE)),
    if (isTRUE(attr(x, "n_clauses", exact = TRUE) == 1)) "" else "s",
    attr(x, "elapsed", exact = TRUE)
  )
}

#' @export
print.zusat_solution <- function(x, n = 10L, ...) {
  cat(format(x), "\n", sep = "")
  if (nrow(x) == 0L) {
    return(invisible(x))
  }
  shown <- utils::head(as.data.frame(x), n)
  print(shown, row.names = FALSE)
  if (nrow(x) > n) {
    cat(sprintf("  ... %d more variables\n", nrow(x) - n))
  }
  invisible(x)
}

#' @export
as.data.frame.zusat_solution <- function(x, ...) {
  data.frame(variable = x$variable, value = x$value)
}
