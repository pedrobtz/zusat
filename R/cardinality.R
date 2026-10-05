# Cardinality constraints: "at most k of these literals are true".
#
# CNF cannot say this directly, so it has to be encoded as clauses, and the
# choice of encoding matters more than it looks. The obvious one -- forbid
# every (k+1)-subset -- is choose(n, k+1) clauses, which is fine at n = 6 and
# hopeless at n = 40. The sequential counter is linear in n*k but introduces
# auxiliary variables.
#
# Auxiliary variables must not collide with anything already in the formula.
# These functions take a solver precisely so they can allocate above
# sat_n_vars(), which is the one number that is always right. Handing the
# caller a bare list of clauses would make that their problem, and a silent
# collision does not error -- it quietly changes what the formula means.
#
# Allocating above what exists cannot protect variables the caller has not
# used yet, though. So the solver records each auxiliary range, every user
# entry point refuses a literal inside one, and sat_reserve() lets the caller
# claim their variable range before any encoding allocates.

# Forbid every (k+1)-subset. No auxiliary variables, choose(n, k+1) clauses.
encode_pairwise <- function(literals, k) {
  n <- length(literals)
  if (k >= n) {
    return(list())
  }
  subsets <- utils::combn(n, k + 1L, simplify = FALSE)
  lapply(subsets, function(idx) -literals[idx])
}

# Sinz's sequential counter (LT_SEQ, SAT 2005). Uses (n-1)*k auxiliary
# variables and about 2*n*k clauses, so it stays usable where the pairwise
# encoding has long since exploded.
#
# s[i, j] means "at least j of the first i literals are true". The clauses
# below propagate that register forward and forbid the count reaching k+1.
encode_sequential <- function(literals, k, top) {
  n <- length(literals)
  if (k >= n) {
    return(list(clauses = list(), top = top))
  }
  if (k == 0L) {
    return(list(clauses = lapply(literals, function(l) -l), top = top))
  }

  # s[i, j] for i in 1..(n-1), j in 1..k
  s <- function(i, j) top + (i - 1L) * k + j
  new_top <- top + (n - 1L) * k

  clauses <- list()
  add <- function(...) clauses[[length(clauses) + 1L]] <<- c(...)

  add(-literals[1], s(1, 1))
  if (k > 1L) {
    for (j in 2:k) {
      add(-s(1, j))
    }
  }

  if (n > 2L) {
    for (i in 2:(n - 1L)) {
      add(-literals[i], s(i, 1))
      add(-s(i - 1L, 1), s(i, 1))
      if (k > 1L) {
        for (j in 2:k) {
          add(-literals[i], -s(i - 1L, j - 1L), s(i, j))
          add(-s(i - 1L, j), s(i, j))
        }
      }
      add(-literals[i], -s(i - 1L, k))
    }
  }

  add(-literals[n], -s(n - 1L, k))

  list(clauses = clauses, top = new_top)
}

choose_encoding <- function(encoding, n, k) {
  if (encoding != "auto") {
    return(encoding)
  }
  # choose(n, k+1) is the pairwise clause count. Prefer it while it is small,
  # because it adds no variables at all; fall back to the counter once it is
  # not. The threshold is deliberately conservative.
  if (k == 0L || k >= n) {
    return("pairwise") # degenerate, produces units or nothing
  }
  if (suppressWarnings(choose(n, k + 1L)) <= 64) "pairwise" else "sequential"
}

# "At most k of literals", as clauses plus the highest variable used. `top`
# is the highest variable in use before this encoding; auxiliaries go above.
encode_at_most <- function(literals, k, encoding, top) {
  n <- length(literals)
  if (k >= n) {
    return(list(clauses = list(), top = top)) # nothing to forbid
  }
  if (k == 0L) {
    return(list(clauses = lapply(literals, function(l) -l), top = top))
  }
  if (choose_encoding(encoding, n, k) == "pairwise") {
    return(list(clauses = encode_pairwise(literals, k), top = top))
  }
  # Checked before building anything: (n - 1) * k can be large enough to
  # overflow integer arithmetic, let alone pass the variable ceiling.
  needed <- as.numeric(top) + (n - 1) * k
  if (needed > max_var()) {
    stop(
      sprintf(
        paste0(
          "this encoding needs auxiliary variables up to %s, ",
          "but variables must be at most %d"
        ),
        format(needed, scientific = FALSE),
        max_var()
      ),
      call. = FALSE
    )
  }
  encode_sequential(literals, k, top = as.integer(top))
}

# "At least k of literals" is "at most n - k of them are false".
encode_at_least <- function(literals, k, encoding, top) {
  n <- length(literals)
  if (k == 0L) {
    return(list(clauses = list(), top = top)) # always satisfied
  }
  if (k > n) {
    # impossible: the empty clause rather than pretend otherwise
    return(list(clauses = list(integer()), top = top))
  }
  encode_at_most(-literals, n - k, encoding, top)
}

# Auxiliary variables must clear both what the solver already knows and the
# literals themselves. On a fresh solver sat_n_vars() is 0, so using it alone
# would allocate aux variables right on top of the literals being
# constrained -- which does not error, it silently encodes a different
# constraint.
aux_floor <- function(solver, literals) {
  as.integer(max(sat_n_vars(solver), abs(literals), 0L))
}

# Validate the user's literals, then commit a whole encoding at once. Every
# clause is built and checked before the first is added, so a failure leaves
# the solver as it was rather than holding half a constraint.
add_cardinality <- function(solver, literals, encode) {
  check_not_aux(solver, literals, "literals")
  floor <- aux_floor(solver, literals)
  enc <- encode(floor)
  clauses <- lapply(enc$clauses, as_literals, arg = "literals")
  add_clauses(solver, clauses)
  if (enc$top > floor) {
    record_aux(solver, floor + 1L, enc$top)
  }
  invisible(solver)
}

#' Cardinality constraints
#'
#' Require that at most, at least, or exactly `k` of a set of literals are
#' true. CNF has no way to say this directly, so these encode the constraint
#' as clauses and add them to the solver.
#'
#' This is what most real modelling needs and what hand-rolling gets wrong:
#' "each item in exactly one bucket", "no more than three shifts in a row",
#' "at least two reviewers".
#'
#' @section Why these take a solver:
#'
#' Every encoding except the pairwise one introduces auxiliary variables, and
#' those must not collide with variables already in the formula. Taking a
#' solver means they can be allocated above [sat_n_vars()], which is the one
#' number that is always correct. A function returning bare clauses would
#' make that the caller's problem, and a collision does not raise an error --
#' it silently changes what the formula means.
#'
#' @section Reserve your variables first:
#'
#' Auxiliaries are allocated above every variable in use *so far*, so a
#' variable you only introduce later may land on one. The solver remembers
#' which variables are auxiliary and refuses them in [sat_add()],
#' [sat_constrain()], assumptions, `vars` in [sat_solutions()] and these
#' functions, rather than let the two silently merge. To avoid the error,
#' declare your whole variable range up front with [sat_reserve()]:
#'
#' ```r
#' s <- sat_solver()
#' sat_reserve(s, 24)       # variables 1..24 are ours
#' sat_exactly(s, 1:12, 1)  # auxiliaries now start at 25
#' sat_exactly(s, 13:24, 1)
#' ```
#'
#' A constraint is added whole or not at all: if it cannot be encoded, for
#' instance because its auxiliaries would pass the maximum variable index,
#' nothing is added.
#'
#'
#' @section Choosing an encoding:
#'
#' \describe{
#'   \item{`"pairwise"`}{Forbid every `k+1` subset. No auxiliary variables,
#'     but `choose(n, k + 1)` clauses -- fine for small sets, hopeless beyond
#'     them.}
#'   \item{`"sequential"`}{Sinz's sequential counter. `(n - 1) * k` auxiliary
#'     variables and about `2 * n * k` clauses, so it stays usable at sizes
#'     where pairwise has exploded.}
#'   \item{`"auto"`}{Pairwise while its clause count is small, sequential
#'     after. The default, and the right choice unless you are measuring.}
#' }
#'
#' The difference is not marginal: at 40 literals with `k = 3`, pairwise is
#' 91,390 clauses and sequential is about 250.
#'
#' @param solver A `zusat_solver`.
#' @param literals Numeric vector of non-zero literals. Negative literals are
#'   allowed, so "at most two of these are *false*" is expressible directly.
#' @param k The bound.
#' @param encoding One of `"auto"`, `"pairwise"` or `"sequential"`.
#' @return `solver`, invisibly.
#' @name cardinality
#' @examples
#' # at most one of x1..x4
#' s <- sat_solver()
#' sat_at_most(s, 1:4, 1)
#' sat_solve(s)
#'
#' # exactly one -- the usual "pick one bucket" constraint
#' s <- sat_solver()
#' sat_exactly(s, 1:4, 1)
#' nrow(sat_solutions(s, vars = 1:4)) / 4 # four ways
NULL

#' @rdname cardinality
#' @export
sat_at_most <- function(
  solver,
  literals,
  k,
  encoding = c("auto", "pairwise", "sequential")
) {
  literals <- check_distinct(as_literals(literals))
  encoding <- match.arg(encoding)
  k <- check_bound(k)

  add_cardinality(solver, literals, function(top) {
    encode_at_most(literals, k, encoding, top)
  })
}

#' @rdname cardinality
#' @export
sat_at_least <- function(
  solver,
  literals,
  k,
  encoding = c("auto", "pairwise", "sequential")
) {
  literals <- check_distinct(as_literals(literals))
  encoding <- match.arg(encoding)
  k <- check_bound(k)

  add_cardinality(solver, literals, function(top) {
    encode_at_least(literals, k, encoding, top)
  })
}

#' @rdname cardinality
#' @export
sat_exactly <- function(
  solver,
  literals,
  k,
  encoding = c("auto", "pairwise", "sequential")
) {
  literals <- check_distinct(as_literals(literals))
  encoding <- match.arg(encoding)
  k <- check_bound(k)

  # Both halves are encoded before either is added, the second allocating
  # above the first, so a failure in the second cannot leave the first behind.
  add_cardinality(solver, literals, function(top) {
    lower <- encode_at_least(literals, k, encoding, top)
    upper <- encode_at_most(literals, k, encoding, lower$top)
    list(clauses = c(lower$clauses, upper$clauses), top = upper$top)
  })
}

#' Reserve variable numbers before adding cardinality constraints
#'
#' Declares variables `1` to `n` to the solver without adding any clause, so
#' that the auxiliary variables later cardinality constraints introduce are
#' allocated above them. Call it with the number of variables your model
#' uses, before the first [sat_at_most()], [sat_at_least()] or
#' [sat_exactly()].
#'
#' Without it, an encoding allocates above the variables in use so far, and
#' a variable you introduce afterwards can land on one of its auxiliaries.
#' The package refuses such a variable rather than let the two silently
#' merge, and that error is what this function avoids.
#'
#' Like adding a clause, this moves the solver out of its initial
#' configuration state, so call [sat_trace_proof()] and set options with
#' [sat_option()] first. It also invalidates the model of an earlier solve.
#'
#' @param solver A `zusat_solver`.
#' @param n The number of variables to reserve. Reserving fewer than the
#'   solver already knows does nothing; reserving into a range already used
#'   for auxiliary variables is an error.
#' @return `solver`, invisibly.
#' @seealso [cardinality]
#' @export
#' @examples
#' s <- sat_solver()
#' sat_reserve(s, 24)
#' sat_exactly(s, 1:12, 1)
#' sat_exactly(s, 13:24, 1)
#' sat_n_vars(s) # 24 of ours, then the auxiliaries
sat_reserve <- function(solver, n) {
  if (!is.numeric(n) || length(n) != 1L || is.na(n)) {
    stop("`n` must be a single number", call. = FALSE)
  }
  if (!is.finite(n) || n != trunc(n)) {
    stop("`n` must be a whole number", call. = FALSE)
  }
  if (n < 0) {
    stop("`n` must be non-negative", call. = FALSE)
  }
  if (n > max_var()) {
    stop(sprintf("`n` must be at most %d", max_var()), call. = FALSE)
  }
  ranges <- aux_ranges(solver)
  clash <- which(ranges[, 1] <= n)
  if (length(clash)) {
    stop(
      sprintf(
        paste0(
          "variables %d to %d are already auxiliary variables ",
          "of a cardinality constraint; reserve before adding ",
          "cardinality constraints"
        ),
        ranges[clash[1], 1],
        ranges[clash[1], 2]
      ),
      call. = FALSE
    )
  }
  .Call(zusat_reserve, solver, as.integer(n))
  invisible(solver)
}

# A cardinality constraint counts distinct variables. A repeated one makes
# the pairwise encoding emit a clause like (-1 | -1), a unit forcing that
# variable false, which is nobody's intent and fails silently: the formula
# simply loses solutions. c(1, -1) is the same problem by another route.
check_distinct <- function(literals, arg = "literals") {
  dup <- anyDuplicated(abs(literals))
  if (dup) {
    stop(
      sprintf(
        "`%s` must not repeat a variable; variable %d appears twice",
        arg,
        abs(literals)[dup]
      ),
      call. = FALSE
    )
  }
  literals
}

check_bound <- function(k) {
  if (!is.numeric(k) || length(k) != 1L) {
    stop("`k` must be a single number", call. = FALSE)
  }
  if (is.na(k)) {
    # is.na() is TRUE for NaN as well as NA
    stop("`k` must not be NA", call. = FALSE)
  }
  # Infinite values must be rejected here and not later. trunc(Inf) is Inf, so
  # the whole-number check below passes them, and they then reach as.integer()
  # where they become NA with a coercion warning -- surfacing as "missing
  # value where TRUE/FALSE needed" from an unrelated comparison rather than as
  # the documented validation error.
  if (!is.finite(k)) {
    stop("`k` must be finite", call. = FALSE)
  }
  if (k != trunc(k)) {
    stop("`k` must be a whole number", call. = FALSE)
  }
  if (k < 0) {
    stop("`k` must not be negative", call. = FALSE)
  }
  # Same failure, one step later: anything above the integer range coerces to
  # NA. A bound that large is meaningless anyway -- no formula has that many
  # literals -- so refuse it rather than silently mangle it.
  if (k > .Machine$integer.max) {
    stop(sprintf("`k` must be at most %d", .Machine$integer.max), call. = FALSE)
  }
  as.integer(k)
}
