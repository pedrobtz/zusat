#ifndef ZUSAT_H
#define ZUSAT_H

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
SEXP zusat_signature(void);

#endif /* ZUSAT_H */
