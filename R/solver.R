# The largest variable index the package accepts, read from the C header so
# the two cannot drift. Cached: as_literals() runs once per clause, and a
# .Call per clause would show up on a large formula.
.zusat <- new.env(parent = emptyenv())

max_var <- function() {
  if (is.null(.zusat$max_var)) {
    .zusat$max_var <- .Call(zusat_max_var_get)
  }
  .zusat$max_var
}

# Coerce to DIMACS literals, rejecting what as.integer() would otherwise
# accept silently: "1" becomes 1L and 1.7 becomes 1L, so a typo in a formula
# turns into a different formula rather than an error.
#
# Order matters. Non-finite values have to be rejected before the whole-number
# test, because trunc(Inf) is Inf and so Inf satisfies it; left to reach
# as.integer() they become NA and surface as "missing value where TRUE/FALSE
# needed" from an unrelated comparison. The magnitude check has to come before
# as.integer() for the same reason, and matters for a second reason: CaDiCaL
# allocates variable arrays densely, so a stray large index kills the process
# rather than raising.
as_literals <- function(x, arg = "literals") {
  if (is.null(x)) {
    return(integer())
  }
  if (!is.numeric(x) || is.factor(x)) {
    stop(
      sprintf("`%s` must be numeric, not %s", arg, class(x)[1]),
      call. = FALSE
    )
  }
  if (anyNA(x)) {
    # is.na() is TRUE for NaN as well as NA
    stop(sprintf("`%s` must not be NA", arg), call. = FALSE)
  }
  if (!all(is.finite(x))) {
    stop(sprintf("`%s` must be finite", arg), call. = FALSE)
  }
  if (is.double(x) && any(x != trunc(x))) {
    stop(sprintf("`%s` must be whole numbers", arg), call. = FALSE)
  }
  if (any(abs(x) > max_var())) {
    stop(
      sprintf(
        paste0(
          "`%s` must be at most %d in absolute value: CaDiCaL ",
          "allocates one slot per variable up to the largest ",
          "index used, so a larger one exhausts memory"
        ),
        arg,
        max_var()
      ),
      call. = FALSE
    )
  }
  x <- as.integer(x)
  if (any(x == 0L)) {
    stop(
      sprintf(
        "`%s` must not contain 0; clauses are terminated automatically",
        arg
      ),
      call. = FALSE
    )
  }
  x
}

# A list of clauses, each coerced with as_literals().
#
# NULL is absence everywhere else in the package -- `assumptions = NULL`,
# `sat_solver(NULL)` -- but as a clause it used to reach C as integer(), the
# empty clause, which makes every formula unsatisfiable. A NULL in a clause
# list is nearly always `if (FALSE) ...` or a missing element, so it is an
# error here; integer() remains the explicit spelling of the empty clause.
#
# Every clause is validated before the caller adds any of them, so a bad
# clause late in a batch cannot leave the earlier ones permanently added.
as_clauses <- function(x, arg = "clauses") {
  nulls <- which(vapply(x, is.null, logical(1)))
  if (length(nulls)) {
    stop(
      sprintf(
        paste0(
          "clause %d is NULL; use integer() for the empty ",
          "clause, or drop the element"
        ),
        nulls[1]
      ),
      call. = FALSE
    )
  }
  lapply(x, as_literals, arg = arg)
}

# The formula entry points share this. is.list() is TRUE for a data frame,
# so an accidental data frame -- or a zusat_solution, which is one -- would
# otherwise be read column by column as clauses.
check_formula <- function(x, what = "a list of clauses or a zusat_solver") {
  if (is.data.frame(x) || !is.list(x)) {
    stop(sprintf("`x` must be %s", what), call. = FALSE)
  }
  invisible(x)
}

# Per-solver R state, kept alive by the external pointer: the ranges of
# auxiliary variables cardinality encodings have introduced, one row each.
solver_state <- function(solver) {
  .Call(zusat_state, solver)
}

aux_ranges <- function(solver) {
  ranges <- solver_state(solver)$aux
  if (is.null(ranges)) matrix(integer(), ncol = 2L) else ranges
}

record_aux <- function(solver, from, to) {
  state <- solver_state(solver)
  state$aux <- rbind(aux_ranges(solver), c(as.integer(from), as.integer(to)))
  invisible(solver)
}

# Refuse a user literal over an auxiliary variable. An encoding allocates its
# auxiliaries above every variable in use at the time; a caller who later
# numbers their own variables into that range silently merges the two, and
# the solver then answers a different problem without any error.
check_not_aux <- function(solver, lits, arg) {
  ranges <- aux_ranges(solver)
  if (!nrow(ranges) || !length(lits)) {
    return(invisible())
  }
  v <- abs(lits)
  i <- findInterval(v, ranges[, 1])
  hit <- i > 0L & v <= ranges[pmax(i, 1L), 2]
  if (any(hit)) {
    stop(
      sprintf(
        paste0(
          "`%s` uses variable %d, an auxiliary variable introduced by an earlier ",
          "cardinality constraint; number your own variables first with ",
          "sat_reserve(solver, n) so encodings allocate above them"
        ),
        arg,
        v[hit][1]
      ),
      call. = FALSE
    )
  }
  invisible()
}

# Add already-validated clauses. Internal: sat_solutions() blocks models over
# auxiliary variables too, which a user call must not do.
add_clauses <- function(solver, clauses) {
  for (cl in clauses) {
    .Call(zusat_add_clause, solver, cl)
  }
  invisible(solver)
}

# Variable numbers, as distinct from literals: positive, not negated.
#
# Deliberately not bounded against sat_n_vars(). Asking about a variable the
# formula never constrains is meaningful -- it is free, so both polarities
# extend every model -- and sat_solutions() relies on that to project onto
# variables an encoding has not introduced yet. The solver reports no value
# for such a variable, which sat_value() surfaces as NA.
as_variables <- function(x, arg = "vars") {
  v <- as_literals(x, arg)
  if (any(v < 0L)) {
    stop(
      sprintf("`%s` must be variable numbers, not negative literals", arg),
      call. = FALSE
    )
  }
  v
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
  solver <- .Call(zusat_solver_new, new.env(parent = emptyenv()))
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
#' Every clause is checked before any is added, so an error part-way through
#' a list leaves the solver as it was.
#'
#' @param solver A `zusat_solver` from [sat_solver()].
#' @param x Either one clause, as a numeric vector of non-zero literals, or
#'   several, as a list of such vectors. An empty vector such as `integer()`
#'   is the empty clause, which makes the formula unsatisfiable. `NULL` is
#'   not a clause and is an error, as is a variable a cardinality constraint
#'   introduced as auxiliary (see [sat_reserve()]).
#' @return `solver`, invisibly, so calls can be chained.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_add(s, c(1, -2))                    # one clause
#' sat_add(s, list(c(2, 3), c(-1, 3)))     # several
sat_add <- function(solver, x) {
  if (is.null(x)) {
    stop("`x` is NULL; use integer() for the empty clause", call. = FALSE)
  }
  if (is.list(x)) {
    check_formula(x, "a clause or a list of clauses")
    clauses <- as_clauses(x)
  } else {
    clauses <- list(as_literals(x, "x"))
  }
  check_not_aux(solver, unlist(clauses), "x")
  add_clauses(solver, clauses)
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
  check_not_aux(x, assumptions, "assumptions")
  started <- proc.time()[["elapsed"]]
  status <- .Call(zusat_solve, x, assumptions)
  elapsed <- proc.time()[["elapsed"]] - started

  new_solution(
    status = status,
    solver = x,
    elapsed = elapsed
  )
}

#' @rdname sat_solve
#' @export
sat_solve.default <- function(x, assumptions = integer(), ...) {
  check_formula(x)
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
#' The model is invalidated by anything that changes the formula or the next
#' solve -- [sat_add()], [sat_constrain()], [sat_reserve()] -- so read it
#' before making such a call, or solve again.
#'
#' @return A logical vector the same length as `vars`. Every variable up to
#'   [sat_n_vars()] has a value, including one the formula never constrains
#'   (either value would do, and the solver picks one). `NA` marks a variable
#'   above [sat_n_vars()], which the solver has never seen. To learn which
#'   variables are forced rather than merely chosen, see [sat_fixed()].
#' @export
#' @examples
#' s <- sat_solver(list(c(1, 2)))
#' sat_solve(s)
#' sat_value(s, 1:2)
sat_value <- function(solver, vars = seq_len(sat_n_vars(solver))) {
  .Call(zusat_value, solver, as_variables(vars))
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
#' `"elim"`, `"vivify"` or `"restartint"`. Names are CaDiCaL's own; an
#' unknown name is an error rather than a silent no-op.
#'
#' Each option has a range, and a value outside it is an error. CaDiCaL itself
#' would clamp it to the nearest bound without saying so.
#'
#' @param solver A `zusat_solver`.
#' @param name A single option name.
#' @param value A whole number to set, within the option's range. When
#'   missing, the current value is returned instead.
#' @return The option value as an integer; when setting, the value now
#'   stored, invisibly.
#' @export
#' @examples
#' s <- sat_solver()
#' sat_option(s, "elim")
#' sat_option(s, "elim", 0)
sat_option <- function(solver, name, value) {
  name <- as.character(name)
  if (length(name) != 1L || is.na(name)) {
    stop("`name` must be a single option name", call. = FALSE)
  }
  bounds <- .Call(zusat_option_bounds, name)
  if (is.null(bounds)) {
    stop(sprintf("unknown option '%s'", name), call. = FALSE)
  }
  if (missing(value)) {
    return(.Call(zusat_get_option, solver, name))
  }
  # Validated before as.integer(), which would turn 1.9 into 1 and NA or an
  # overflow into NA_integer_ -- each a stored value nobody asked for.
  if (!is.numeric(value) || length(value) != 1L || is.na(value)) {
    stop("`value` must be a single whole number", call. = FALSE)
  }
  if (is.finite(value) && value != trunc(value)) {
    stop("`value` must be a whole number", call. = FALSE)
  }
  if (value < bounds[1] || value > bounds[2]) {
    stop(
      sprintf(
        "option '%s' must be between %d and %d",
        name,
        bounds[1],
        bounds[2]
      ),
      call. = FALSE
    )
  }
  # CaDiCaL accepts an option change only while the solver is still being
  # configured -- everything except these four, which affect reporting only.
  # Without this the caller gets a contract violation reported against
  # CaDiCaL's own function and file names.
  if (
    !name %in% c("log", "quiet", "report", "verbose") &&
      !.Call(zusat_configuring, solver)
  ) {
    stop(
      sprintf(
        paste0(
          "option '%s' can only be set on a freshly created ",
          "solver, before any clause is added or solved"
        ),
        name
      ),
      call. = FALSE
    )
  }
  invisible(.Call(zusat_set_option, solver, name, as.integer(value)))
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
