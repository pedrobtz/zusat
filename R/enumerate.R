#' Enumerate satisfying assignments
#'
#' Finds distinct models, not just one. After each model the negation of that
#' assignment is added as a clause, so the next solve is forced to differ;
#' the solver keeps everything it has learned between rounds, which is why
#' this is much cheaper than solving from scratch each time.
#'
#' @section Projecting onto the variables you care about:
#'
#' Encodings introduce auxiliary variables -- Tseitin variables for a circuit,
#' order variables for a cardinality constraint -- and a formula with 10 real
#' variables and 200 auxiliaries has models that differ only in auxiliaries.
#' Enumerating over all of them returns the same answer many times over.
#'
#' `vars` restricts both what is reported and what is blocked, so each
#' distinct assignment of those variables is returned exactly once. Neither
#' `pycosat` nor `PySAT` projects by default, and it is the difference
#' between a handful of answers and an intractable number of them.
#'
#' @param x A list of clauses, or a `zusat_solver`.
#' @param limit Maximum number of solutions. Defaults to 1000 rather than
#'   `Inf`: the count is usually exponential, and an accidental unbounded
#'   enumeration is a hang rather than an error. Pass `Inf` deliberately.
#' @param vars Variables to enumerate over. Defaults to every variable in the
#'   formula.
#' @param assumptions Literals assumed true for every solve in the
#'   enumeration.
#' @param ... Passed to methods.
#' @return A [zusat_solutions] object: a data frame with one row per variable
#'   per solution, with columns `solution`, `variable` and `value`. Use
#'   [sat_complete()] to tell an exhausted enumeration from one that stopped
#'   at `limit`.
#' @seealso [sat_solve()] for a single model.
#' @export
#' @examples
#' # three ways to satisfy (x1 OR x2)
#' sols <- sat_solutions(list(c(1, 2)))
#' sat_n_solutions(sols)
#'
#' # project onto variable 1: only two distinct answers remain
#' sat_n_solutions(sat_solutions(list(c(1, 2)), vars = 1))
sat_solutions <- function(x, limit = 1000, vars = NULL,
                          assumptions = integer(), ...) {
  UseMethod("sat_solutions")
}

#' @rdname sat_solutions
#' @export
sat_solutions.default <- function(x, limit = 1000, vars = NULL,
                                  assumptions = integer(), ...) {
  if (!is.list(x)) {
    stop("`x` must be a list of clauses or a zusat_solver", call. = FALSE)
  }
  sat_solutions(sat_solver(x), limit = limit, vars = vars,
                assumptions = assumptions, ...)
}

#' @rdname sat_solutions
#' @section Enumerating from a solver:
#'
#' Blocking clauses are permanent, so enumerating from a `zusat_solver`
#' modifies it: afterwards it holds the original formula plus a clause ruling
#' out every model found. That is occasionally what you want and usually not,
#' so pass the formula instead when the solver is still needed.
#' @export
sat_solutions.zusat_solver <- function(x, limit = 1000, vars = NULL,
                                       assumptions = integer(), ...) {
  if (!is.numeric(limit) || length(limit) != 1L || is.na(limit) || limit < 0) {
    stop("`limit` must be a single non-negative number", call. = FALSE)
  }
  assumptions <- as_literals(assumptions, "assumptions")

  if (!is.null(vars)) {
    vars <- as_literals(vars, "vars")
    if (any(vars < 0)) {
      stop("`vars` must be variable numbers, not negative literals", call. = FALSE)
    }
  }

  found <- list()
  status <- "unsat"
  complete <- TRUE

  while (length(found) < limit) {
    sol <- sat_solve(x, assumptions = assumptions)
    if (!sat_is_sat(sol)) {
      # The first solve decides the status; a later one going unsat just
      # means the models ran out.
      if (length(found) == 0L) status <- sat_status(sol)
      break
    }
    status <- "sat"

    # Default the projection on the first iteration, once the solver has seen
    # the whole formula and knows how many variables there are.
    this_vars <- if (is.null(vars)) seq_len(sat_n_vars(x)) else vars
    value <- sat_value(x, this_vars)
    # An unassigned variable means both polarities extend the model. Fixing
    # it to FALSE keeps each reported assignment concrete; the other
    # extension is still reachable, because the blocking clause below rules
    # out only the one combination just reported.
    value[is.na(value)] <- FALSE

    found[[length(found) + 1L]] <- value

    if (length(this_vars) == 0L) {
      # Nothing to project onto, so there is exactly one distinct answer and
      # no clause that could block it.
      break
    }

    # Block this assignment: at least one projected variable must differ.
    sat_add(x, ifelse(value, -this_vars, this_vars))
  }

  if (length(found) >= limit && limit > 0) {
    # Stopped at the cap; whether more exist is unknown without another solve.
    complete <- FALSE
  }

  new_solutions(found, vars_used = if (length(found)) this_vars else integer(),
                status = status, complete = complete)
}

#' The result of an enumeration
#'
#' `sat_solutions()` returns an object of class `zusat_solutions`. It is a
#' data frame in long form, one row per variable per solution:
#'
#' \describe{
#'   \item{solution}{integer, which solution the row belongs to}
#'   \item{variable}{integer, the variable number}
#'   \item{value}{logical, its value in that solution}
#' }
#'
#' Long form rather than one row per solution because the variables enumerated
#' over are chosen at call time via `vars`, so a wide frame would have a shape
#' that changes with the arguments. Long form also groups and joins directly;
#' use `split(x, x$solution)` to iterate solution by solution.
#'
#' @section Attributes:
#' `status`, `n_solutions` and `complete`. Read them with [sat_status()],
#' [sat_n_solutions()] and [sat_complete()].
#'
#' [sat_complete()] is the one that matters: an enumeration stopped at `limit`
#' looks exactly like an exhaustive one unless you ask.
#'
#' @name zusat_solutions
#' @seealso [sat_solutions()], [sat_complete()]
#' @examples
#' sols <- sat_solutions(list(c(1, 2)))
#' class(sols)
#' sat_complete(sols)
NULL

new_solutions <- function(found, vars_used, status, complete) {
  if (length(found) == 0L) {
    out <- data.frame(solution = integer(), variable = integer(),
                      value = logical())
  } else {
    n <- length(vars_used)
    out <- data.frame(
      solution = rep(seq_along(found), each = n),
      variable = rep(as.integer(vars_used), times = length(found)),
      value    = unlist(found, use.names = FALSE)
    )
  }
  structure(
    out,
    class         = c("zusat_solutions", "data.frame"),
    status        = status,
    n_solutions   = length(found),
    complete      = complete
  )
}

#' Number of solutions found, and whether that is all of them
#'
#' `sat_complete()` is the part worth checking. [sat_solutions()] stops at
#' `limit`, and a truncated enumeration looks exactly like an exhaustive one
#' unless you ask.
#'
#' @param x A [zusat_solutions] object.
#' @return `sat_n_solutions()` returns a count. `sat_complete()` returns
#'   `TRUE` when the enumeration ran out of models rather than hitting
#'   `limit`.
#' @export
#' @examples
#' sols <- sat_solutions(list(c(1, 2)), limit = 2)
#' sat_n_solutions(sols)
#' sat_complete(sols)
sat_n_solutions <- function(x) {
  attr(x, "n_solutions", exact = TRUE)
}

#' @rdname sat_n_solutions
#' @export
sat_complete <- function(x) {
  attr(x, "complete", exact = TRUE)
}

#' @export
format.zusat_solutions <- function(x, ...) {
  sprintf(
    "<zusat_solutions> %s  (%d solution%s%s)",
    sat_status(x),
    sat_n_solutions(x),
    if (sat_n_solutions(x) == 1L) "" else "s",
    if (sat_complete(x)) "" else ", stopped at limit"
  )
}

#' @export
print.zusat_solutions <- function(x, n = 10L, ...) {
  cat(format(x), "\n", sep = "")
  if (nrow(x) == 0L) {
    return(invisible(x))
  }
  shown <- utils::head(as.data.frame(x), n)
  print(shown, row.names = FALSE)
  if (nrow(x) > n) {
    cat(sprintf("  ... %d more rows\n", nrow(x) - n))
  }
  invisible(x)
}

#' @export
as.data.frame.zusat_solutions <- function(x, ...) {
  data.frame(solution = x$solution, variable = x$variable, value = x$value)
}
