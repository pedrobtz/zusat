#include "zusat.h"
#include "cadical/ccadical.h"

/* ------------------------------------------------------------------ */
/* Solver handle                                                       */

static void zusat_finalize(SEXP xptr) {
  CCaDiCaL *s = (CCaDiCaL *) R_ExternalPtrAddr(xptr);
  if (s != NULL) {
    ccadical_release(s);
    R_ClearExternalPtr(xptr);
  }
}

static CCaDiCaL *solver_from(SEXP xptr) {
  if (TYPEOF(xptr) != EXTPTRSXP)
    Rf_error("invalid solver handle");
  CCaDiCaL *s = (CCaDiCaL *) R_ExternalPtrAddr(xptr);
  if (s == NULL)
    Rf_error("solver handle is no longer valid");
  return s;
}

SEXP zusat_solver_new(void) {
  CCaDiCaL *s = ccadical_init();
  if (s == NULL)
    Rf_error("could not allocate CaDiCaL solver");
  SEXP xptr = PROTECT(R_MakeExternalPtr(s, Rf_install("zusat_solver"), R_NilValue));
  R_RegisterCFinalizerEx(xptr, zusat_finalize, TRUE);
  Rf_setAttrib(xptr, R_ClassSymbol, Rf_mkString("zusat_solver"));
  UNPROTECT(1);
  return xptr;
}

/* ------------------------------------------------------------------ */
/* Interrupt handling                                                  */
/*                                                                     */
/* R_CheckUserInterrupt longjmps, which would tear through CaDiCaL's   */
/* C++ frames without running destructors and leak the solver's arena. */
/* Instead we run the check under R_ToplevelExec, which catches the    */
/* jump, and report it back through a flag. CaDiCaL then unwinds       */
/* normally and we raise the R error from safe ground.                 */

static void check_interrupt_body(void *ignored) {
  (void) ignored;
  R_CheckUserInterrupt();
}

static int terminate_cb(void *state) {
  int *interrupted = (int *) state;
  if (R_ToplevelExec(check_interrupt_body, NULL) == FALSE) {
    *interrupted = 1;
    return 1; /* ask CaDiCaL to stop at its next safe point */
  }
  return 0;
}

/* ------------------------------------------------------------------ */
/* Clause input                                                        */

static void check_lits(const int *lits, R_xlen_t n) {
  for (R_xlen_t i = 0; i < n; i++) {
    if (lits[i] == NA_INTEGER)
      Rf_error("literals must not be NA");
    if (lits[i] == 0)
      Rf_error("0 is not a valid literal (clauses are terminated automatically)");
  }
}

SEXP zusat_add_clause(SEXP xptr, SEXP lits) {
  CCaDiCaL *s = solver_from(xptr);
  if (TYPEOF(lits) != INTSXP)
    Rf_error("clause must be an integer vector");

  R_xlen_t n = XLENGTH(lits);
  const int *p = INTEGER(lits);
  check_lits(p, n);

  for (R_xlen_t i = 0; i < n; i++)
    ccadical_add(s, p[i]);
  ccadical_add(s, 0); /* terminate clause */

  return R_NilValue;
}

/* ------------------------------------------------------------------ */
/* Solving                                                             */

SEXP zusat_solve(SEXP xptr, SEXP assumptions) {
  CCaDiCaL *s = solver_from(xptr);

  if (TYPEOF(assumptions) != INTSXP)
    Rf_error("assumptions must be an integer vector");
  R_xlen_t na = XLENGTH(assumptions);
  const int *ap = INTEGER(assumptions);
  check_lits(ap, na);
  for (R_xlen_t i = 0; i < na; i++)
    ccadical_assume(s, ap[i]);

  int interrupted = 0;
  ccadical_set_terminate(s, &interrupted, terminate_cb);
  int res = ccadical_solve(s);
  ccadical_set_terminate(s, NULL, NULL);

  if (interrupted) {
    /* CaDiCaL has unwound cleanly; now it is safe to longjmp. */
    Rf_error("solve interrupted");
  }

  const char *status;
  switch (res) {
    case 10: status = "sat";     break;
    case 20: status = "unsat";   break;
    default: status = "unknown"; break;
  }
  return Rf_mkString(status);
}

/* ------------------------------------------------------------------ */
/* Results                                                             */

SEXP zusat_value(SEXP xptr, SEXP vars) {
  CCaDiCaL *s = solver_from(xptr);
  if (TYPEOF(vars) != INTSXP)
    Rf_error("vars must be an integer vector");

  R_xlen_t n = XLENGTH(vars);
  const int *vp = INTEGER(vars);
  SEXP out = PROTECT(Rf_allocVector(LGLSXP, n));
  int *op = LOGICAL(out);

  for (R_xlen_t i = 0; i < n; i++) {
    if (vp[i] == NA_INTEGER || vp[i] == 0) {
      op[i] = NA_LOGICAL;
    } else {
      int v = ccadical_val(s, vp[i]);
      op[i] = (v == 0) ? NA_LOGICAL : (v > 0);
    }
  }
  UNPROTECT(1);
  return out;
}

SEXP zusat_failed(SEXP xptr, SEXP assumptions) {
  CCaDiCaL *s = solver_from(xptr);
  if (TYPEOF(assumptions) != INTSXP)
    Rf_error("assumptions must be an integer vector");

  R_xlen_t n = XLENGTH(assumptions);
  const int *ap = INTEGER(assumptions);
  SEXP out = PROTECT(Rf_allocVector(LGLSXP, n));
  int *op = LOGICAL(out);

  for (R_xlen_t i = 0; i < n; i++)
    op[i] = (ap[i] == NA_INTEGER) ? NA_LOGICAL : (ccadical_failed(s, ap[i]) != 0);

  UNPROTECT(1);
  return out;
}

/* ------------------------------------------------------------------ */
/* Options and introspection                                           */

SEXP zusat_set_option(SEXP xptr, SEXP name, SEXP value) {
  CCaDiCaL *s = solver_from(xptr);
  if (TYPEOF(name) != STRSXP || XLENGTH(name) != 1)
    Rf_error("option name must be a single string");
  if (TYPEOF(value) != INTSXP || XLENGTH(value) != 1)
    Rf_error("option value must be a single integer");
  ccadical_set_option(s, CHAR(STRING_ELT(name, 0)), INTEGER(value)[0]);
  return R_NilValue;
}

SEXP zusat_get_option(SEXP xptr, SEXP name) {
  CCaDiCaL *s = solver_from(xptr);
  if (TYPEOF(name) != STRSXP || XLENGTH(name) != 1)
    Rf_error("option name must be a single string");
  return Rf_ScalarInteger(ccadical_get_option(s, CHAR(STRING_ELT(name, 0))));
}

SEXP zusat_n_clauses(SEXP xptr) {
  /* irredundant() counts the original (non-learnt) clauses still active --
     the closest CaDiCaL offers to "how big is the formula". Learnt clauses
     are deliberately excluded: they are an artefact of search, not input. */
  double n = (double) ccadical_irredundant(solver_from(xptr));
  return Rf_ScalarReal(n);
}

SEXP zusat_n_vars(SEXP xptr) {
  return Rf_ScalarInteger(ccadical_vars(solver_from(xptr)));
}

SEXP zusat_signature(void) {
  return Rf_mkString(ccadical_signature());
}
