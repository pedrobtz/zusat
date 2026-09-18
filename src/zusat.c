#include "zusat.h"
#include "cadical/ccadical.h"

#include <stdio.h>

/* ------------------------------------------------------------------ */
/* Solver handle                                                       */
/*                                                                     */
/* The handle carries the proof file as well as the solver, because    */
/* CaDiCaL does not take ownership of it: Solver::trace_proof wraps    */
/* the FILE* in a File constructed with close_file = 0, so closing is  */
/* ours to do. Keeping the two together is what lets the finalizer     */
/* close an abandoned proof rather than leaking the descriptor and     */
/* leaving a truncated file behind.                                    */

typedef struct {
  CCaDiCaL *solver;
  FILE *proof; /* NULL unless tracing; owned here, not by CaDiCaL */
} zusat_handle;

static zusat_handle *handle_from(SEXP xptr) {
  if (TYPEOF(xptr) != EXTPTRSXP)
    Rf_error("invalid solver handle");
  zusat_handle *h = (zusat_handle *) R_ExternalPtrAddr(xptr);
  if (h == NULL)
    Rf_error("solver handle is no longer valid");
  return h;
}

static CCaDiCaL *solver_from(SEXP xptr) {
  return handle_from(xptr)->solver;
}

static void zusat_finalize(SEXP xptr) {
  zusat_handle *h = (zusat_handle *) R_ExternalPtrAddr(xptr);
  if (h != NULL) {
    if (h->proof != NULL) {
      /* Flush CaDiCaL's side before closing ours, or the tail of the proof
         is lost. Do not report errors from a finalizer. */
      ccadical_close_proof(h->solver);
      fclose(h->proof);
      h->proof = NULL;
    }
    ccadical_release(h->solver);
    free(h);
    R_ClearExternalPtr(xptr);
  }
}

SEXP zusat_solver_new(void) {
  zusat_handle *h = (zusat_handle *) calloc(1, sizeof(zusat_handle));
  if (h == NULL)
    Rf_error("could not allocate solver handle");
  h->solver = ccadical_init();
  if (h->solver == NULL) {
    free(h);
    Rf_error("could not allocate CaDiCaL solver");
  }
  SEXP xptr = PROTECT(R_MakeExternalPtr(h, Rf_install("zusat_solver"), R_NilValue));
  R_RegisterCFinalizerEx(xptr, zusat_finalize, TRUE);
  Rf_setAttrib(xptr, R_ClassSymbol, Rf_mkString("zusat_solver"));
  UNPROTECT(1);
  return xptr;
}

/* ------------------------------------------------------------------ */
/* Proof tracing                                                       */

SEXP zusat_trace_proof(SEXP xptr, SEXP path) {
  zusat_handle *h = handle_from(xptr);
  if (TYPEOF(path) != STRSXP || XLENGTH(path) != 1)
    Rf_error("proof path must be a single string");
  if (h->proof != NULL)
    Rf_error("this solver is already tracing a proof");

  const char *file = CHAR(STRING_ELT(path, 0));
  FILE *f = fopen(file, "w");
  if (f == NULL)
    Rf_error("could not open '%s' for writing", file);

  /* CaDiCaL requires state CONFIGURING here: tracing must start before any
     clause is added, or the proof records only part of the derivation. The
     R layer enforces that; this is the last line of defence. */
  if (!ccadical_trace_proof(h->solver, f, file)) {
    fclose(f);
    Rf_error("could not start proof tracing to '%s'", file);
  }
  h->proof = f;
  return R_NilValue;
}

SEXP zusat_close_proof(SEXP xptr) {
  zusat_handle *h = handle_from(xptr);
  if (h->proof == NULL)
    Rf_error("this solver is not tracing a proof");
  ccadical_close_proof(h->solver);
  fclose(h->proof);
  h->proof = NULL;
  return R_NilValue;
}

SEXP zusat_tracing_proof(SEXP xptr) {
  return Rf_ScalarLogical(handle_from(xptr)->proof != NULL);
}

SEXP zusat_conclude(SEXP xptr) {
  ccadical_conclude(solver_from(xptr));
  return R_NilValue;
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

/* ------------------------------------------------------------------ */
/* Resource limits, constraints and root-level facts                   */

SEXP zusat_limit(SEXP xptr, SEXP name, SEXP value) {
  CCaDiCaL *s = solver_from(xptr);
  if (TYPEOF(name) != STRSXP || XLENGTH(name) != 1)
    Rf_error("limit name must be a single string");
  if (TYPEOF(value) != INTSXP || XLENGTH(value) != 1)
    Rf_error("limit value must be a single integer");
  /* ccadical_limit drops the bool that says whether the name was known, so
     an unrecognised name is silently ignored and the solve runs unbounded.
     The R layer checks the name before we get here. */
  ccadical_limit(s, CHAR(STRING_ELT(name, 0)), INTEGER(value)[0]);
  return R_NilValue;
}

SEXP zusat_constrain(SEXP xptr, SEXP lits) {
  CCaDiCaL *s = solver_from(xptr);
  if (TYPEOF(lits) != INTSXP)
    Rf_error("constraint must be an integer vector");

  R_xlen_t n = XLENGTH(lits);
  const int *p = INTEGER(lits);
  check_lits(p, n);

  for (R_xlen_t i = 0; i < n; i++)
    ccadical_constrain(s, p[i]);
  ccadical_constrain(s, 0); /* terminate the constraint clause */

  return R_NilValue;
}

SEXP zusat_constraint_failed(SEXP xptr) {
  return Rf_ScalarLogical(ccadical_constraint_failed(solver_from(xptr)) != 0);
}

SEXP zusat_fixed(SEXP xptr, SEXP lits) {
  CCaDiCaL *s = solver_from(xptr);
  if (TYPEOF(lits) != INTSXP)
    Rf_error("lits must be an integer vector");

  R_xlen_t n = XLENGTH(lits);
  const int *p = INTEGER(lits);
  SEXP out = PROTECT(Rf_allocVector(LGLSXP, n));
  int *op = LOGICAL(out);

  for (R_xlen_t i = 0; i < n; i++) {
    if (p[i] == NA_INTEGER || p[i] == 0) {
      op[i] = NA_LOGICAL;
    } else {
      /* 1 = implied true, -1 = implied false, 0 = not yet decided */
      int f = ccadical_fixed(s, p[i]);
      op[i] = (f == 0) ? NA_LOGICAL : (f > 0);
    }
  }
  UNPROTECT(1);
  return out;
}

SEXP zusat_simplify(SEXP xptr) {
  int res = ccadical_simplify(solver_from(xptr));
  const char *status;
  switch (res) {
    case 10: status = "sat";     break;
    case 20: status = "unsat";   break;
    default: status = "unknown"; break;
  }
  return Rf_mkString(status);
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
