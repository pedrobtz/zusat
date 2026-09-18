#ifndef ZUSAT_H
#define ZUSAT_H

/* Largest variable index the package accepts.
 *
 * CaDiCaL allocates its per-variable arrays densely up to the largest index
 * it has seen, and its own input check rejects only INT_MIN. An accidental
 * large literal -- a row id, a hash, INT_MAX -- therefore has it request
 * billions of slots, and the process is killed by the OS with no R error to
 * catch. Ten million is far above any formula built by hand and far below
 * the point where the allocation becomes fatal.
 *
 * R reads this through zusat_max_var_get() rather than repeating it, so the
 * two cannot drift apart. */
#define ZUSAT_MAX_VAR 10000000

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

SEXP zusat_solver_new(void);
SEXP zusat_add_clause(SEXP xptr, SEXP lits);
SEXP zusat_solve(SEXP xptr, SEXP assumptions);
SEXP zusat_value(SEXP xptr, SEXP vars);
SEXP zusat_failed(SEXP xptr, SEXP assumptions);
SEXP zusat_set_option(SEXP xptr, SEXP name, SEXP value);
SEXP zusat_get_option(SEXP xptr, SEXP name);
SEXP zusat_n_vars(SEXP xptr);
SEXP zusat_n_clauses(SEXP xptr);
SEXP zusat_limit(SEXP xptr, SEXP name, SEXP value);
SEXP zusat_constrain(SEXP xptr, SEXP lits);
SEXP zusat_constraint_failed(SEXP xptr);
SEXP zusat_fixed(SEXP xptr, SEXP lits);
SEXP zusat_simplify(SEXP xptr);
SEXP zusat_trace_proof(SEXP xptr, SEXP path);
SEXP zusat_close_proof(SEXP xptr);
SEXP zusat_tracing_proof(SEXP xptr);
SEXP zusat_conclude(SEXP xptr);
SEXP zusat_max_var_get(void);
SEXP zusat_configuring(SEXP xptr);
SEXP zusat_signature(void);

#endif /* ZUSAT_H */
