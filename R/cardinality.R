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
    for (j in 2:k) add(-s(1, j))
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

add_at_most <- function(solver, literals, k, encoding) {
  n <- length(literals)

  if (k >= n) {
    return(invisible(solver)) # nothing to forbid
  }
  if (k == 0L) {
    for (l in literals) .Call(zusat_add_clause, solver, as_literals(-l))
    return(invisible(solver))
  }

  encoding <- choose_encoding(encoding, n, k)

  if (encoding == "pairwise") {
    for (cl in encode_pairwise(literals, k)) {
      .Call(zusat_add_clause, solver, as_literals(cl))
    }
  } else {
    # Auxiliary variables must clear both what the solver already knows and
    # the literals themselves. On a fresh solver sat_n_vars() is 0, so using
    # it alone would allocate aux variables right on top of the literals
    # being constrained -- which does not error, it silently encodes a
    # different constraint.
    top <- max(sat_n_vars(solver), max(abs(literals)))
    enc <- encode_sequential(literals, k, top = top)
    for (cl in enc$clauses) {
      .Call(zusat_add_clause, solver, as_literals(cl))
    }
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
sat_at_most <- function(solver, literals, k, encoding = c("auto", "pairwise",
                                                          "sequential")) {
  literals <- as_literals(literals)
  encoding <- match.arg(encoding)
  k <- check_bound(k)

  add_at_most(solver, literals, k, encoding)
}

#' @rdname cardinality
#' @export
sat_at_least <- function(solver, literals, k, encoding = c("auto", "pairwise",
                                                           "sequential")) {
  literals <- as_literals(literals)
  encoding <- match.arg(encoding)
  n <- length(literals)
  k <- check_bound(k)

  if (k == 0L) {
    return(invisible(solver)) # always satisfied
  }
  if (k > n) {
    # impossible: add the empty clause rather than pretend otherwise
    .Call(zusat_add_clause, solver, integer())
    return(invisible(solver))
  }
  # "at least k of these are true" is "at most n-k of them are false"
  add_at_most(solver, -literals, n - k, encoding)
}

#' @rdname cardinality
#' @export
sat_exactly <- function(solver, literals, k, encoding = c("auto", "pairwise",
                                                          "sequential")) {
  literals <- as_literals(literals)
  encoding <- match.arg(encoding)
  n <- length(literals)
  k <- check_bound(k)

  sat_at_least(solver, literals, k, encoding = encoding)
  sat_at_most(solver, literals, k, encoding = encoding)
  invisible(solver)
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
