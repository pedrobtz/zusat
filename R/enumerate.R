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
#' @param constraint Optional clause, as for [sat_constrain()], that every
#'   model must satisfy. It is applied to each solve of the enumeration and
#'   is not retained afterwards. A constraint already set on the solver with
#'   [sat_constrain()] would cover only the first solve, so enumerating while
#'   one is pending is an error.
#' @param ... Passed to methods.
#' @return A [zusat_solutions] object: a data frame with one row per variable
#'   per solution, with columns `solution`, `variable` and `value`. Use
#'   [sat_complete()] to tell an exhausted enumeration from one that stopped
#'   at `limit` or whose search gave up.
#' @seealso [sat_solve()] for a single model.
#' @export
#' @examples
#' # three ways to satisfy (x1 OR x2)
#' sols <- sat_solutions(list(c(1, 2)))
#' sat_n_solutions(sols)
#'
#' # project onto variable 1: only two distinct answers remain
#' sat_n_solutions(sat_solutions(list(c(1, 2)), vars = 1))
sat_solutions <- function(
  x,
  limit = 1000,
  vars = NULL,
  assumptions = integer(),
  constraint = NULL,
  ...
) {
  UseMethod("sat_solutions")
}

#' @rdname sat_solutions
#' @export
sat_solutions.default <- function(
  x,
  limit = 1000,
  vars = NULL,
  assumptions = integer(),
  constraint = NULL,
  ...
) {
  check_formula(x)
  sat_solutions(
    sat_solver(x),
    limit = limit,
    vars = vars,
    assumptions = assumptions,
    constraint = constraint,
    ...
  )
}

#' @rdname sat_solutions
#' @section Enumerating from a solver:
#'
#' Blocking clauses are permanent, so enumerating from a `zusat_solver`
#' modifies it: afterwards it holds the original formula plus a clause ruling
#' out every model found. That is occasionally what you want and usually not,
#' so pass the formula instead when the solver is still needed.
#' @export
sat_solutions.zusat_solver <- function(
  x,
  limit = 1000,
  vars = NULL,
  assumptions = integer(),
  constraint = NULL,
  ...
) {
  if (!is.numeric(limit) || length(limit) != 1L || is.na(limit) || limit < 0) {
    stop("`limit` must be a single non-negative number", call. = FALSE)
  }
  # CaDiCaL drops a constraint once a solve has used it, so one set with
  # sat_constrain() would bound the first model and silently not the rest.
  if (.Call(zusat_constraint_pending, x)) {
    stop(
      "a constraint set with sat_constrain() covers one solve only, and ",
      "enumeration solves once per model; pass it as `constraint` to ",
      "sat_solutions() instead",
      call. = FALSE
    )
  }
  assumptions <- as_literals(assumptions, "assumptions")
  check_not_aux(x, assumptions, "assumptions")
  if (!is.null(constraint)) {
    constraint <- as_literals(constraint, "constraint")
    check_not_aux(x, constraint, "constraint")
  }

  if (!is.null(vars)) {
    vars <- as_variables(vars, "vars")
    check_not_aux(x, vars, "vars")
    # A repeated variable would be reported once per occurrence and blocked
    # redundantly, inflating the row count without changing the answer set.
    vars <- unique(vars)
  }

  found <- list()
  # Not "unsat": with limit = 0 the loop never runs and nothing has been
  # established, so claiming unsatisfiability would be a result we never
  # computed. The first solve overwrites this with what it actually found.
  status <- "unknown"
  # Why the loop ended: "exhausted" is the only reason that makes the
  # enumeration complete. An "unknown" solve -- a resource limit, say --
  # proves nothing about the models not yet found.
  stopped <- "limit"

  while (length(found) < limit) {
    if (!is.null(constraint)) {
      .Call(zusat_constrain, x, constraint)
    }
    sol <- sat_solve(x, assumptions = assumptions)
    if (!sat_is_sat(sol)) {
      # The first solve decides the status; a later one going unsat just
      # means the models ran out.
      if (length(found) == 0L) {
        status <- sat_status(sol)
      }
      stopped <- if (identical(sat_status(sol), "unsat")) {
        "exhausted"
      } else {
        "unknown"
      }
      break
    }
    status <- "sat"

    # Default the projection on the first iteration, once the solver has seen
    # the whole formula and knows how many variables there are.
    this_vars <- if (is.null(vars)) seq_len(sat_n_vars(x)) else vars
    value <- sat_value(x, this_vars)
    # NA is a projected variable above sat_n_vars(), one the solver has never
    # seen and so is free. Fixing it to FALSE keeps each reported assignment
    # concrete; TRUE is still reachable, because the blocking clause below
    # rules out only the one combination just reported.
    value[is.na(value)] <- FALSE

    found[[length(found) + 1L]] <- value

    if (length(this_vars) == 0L) {
      # Nothing to project onto, so there is exactly one distinct answer and
      # no clause that could block it.
      stopped <- "exhausted"
      break
    }

    # Block this assignment: at least one projected variable must differ.
    # Added directly: the default projection includes auxiliary variables,
    # which sat_add() rightly refuses from a caller.
    add_clauses(x, list(ifelse(value, -this_vars, this_vars)))
  }

  # stopped stays "limit" when the loop hit the cap, including limit = 0
  # where nothing was even attempted: whether more models exist is unknown
  # without another solve.
  new_solutions(
    found,
    vars_used = if (length(found)) this_vars else integer(),
    status = status,
    stopped = stopped
  )
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
#' `status`, `n_solutions`, `complete` and `stopped`. Read them with
#' [sat_status()], [sat_n_solutions()] and [sat_complete()].
#'
#' [sat_complete()] is the one that matters: an enumeration stopped at `limit`
#' looks exactly like an exhaustive one unless you ask.
#'
#' @section Subsetting:
#' Filtering or reordering rows keeps the class, and the attributes go on
#' describing the enumeration as a whole: [sat_n_solutions()] still counts the
#' models found, not the rows kept. Selecting columns gives a plain data
#' frame, since the result no longer has the shape the class promises.
#'
#' @name zusat_solutions
#' @seealso [sat_solutions()], [sat_complete()]
#' @examples
#' sols <- sat_solutions(list(c(1, 2)))
#' class(sols)
#' sat_complete(sols)
NULL

new_solutions <- function(found, vars_used, status, stopped) {
  if (length(found) == 0L) {
    out <- data.frame(
      solution = integer(),
      variable = integer(),
      value = logical()
    )
  } else {
    n <- length(vars_used)
    out <- data.frame(
      solution = rep(seq_along(found), each = n),
      variable = rep(as.integer(vars_used), times = length(found)),
      value = unlist(found, use.names = FALSE)
    )
  }
  structure(
    out,
    class = c("zusat_solutions", "data.frame"),
    status = status,
    n_solutions = length(found),
    complete = identical(stopped, "exhausted"),
    stopped = stopped
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
#'   `TRUE` only when the enumeration proved there are no further models:
#'   `FALSE` when it stopped at `limit`, and `FALSE` when a solve returned
#'   `"unknown"`, for instance because of [sat_limit()].
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
    if (isTRUE(sat_complete(x))) {
      ""
    } else if (identical(attr(x, "stopped", exact = TRUE), "unknown")) {
      ", search stopped before exhausting the models"
    } else {
      ", stopped at limit"
    }
  )
}

#' @export
`[.zusat_solutions` <- function(x, ...) {
  restore_result(
    NextMethod(),
    x,
    c("solution", "variable", "value"),
    c("status", "n_solutions", "complete", "stopped")
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
