#include "zusat.h"
#include "cadical/ccadical.h"

#include <stdio.h>

/* ------------------------------------------------------------------ */
/* Solver handle                                                       */
/*                                                                     */
/* The handle carries three things beyond the solver itself.           */
/*                                                                     */
/* The proof file, because CaDiCaL does not take ownership of it:      */
/* Solver::trace_proof wraps the FILE* in a File constructed with      */
/* close_file = 0, so closing is ours. Keeping the two together lets   */
/* the finalizer close an abandoned proof rather than leaking the      */
/* descriptor and leaving a truncated file behind.                     */
/*                                                                     */
/* The interrupt flag, because its address is handed to CaDiCaL as a   */
/* terminator callback state. A stack slot would dangle the moment a   */
/* solve exits by longjmp -- ccadical_solve can, since a contract      */
/* violation now raises an R error -- leaving CaDiCaL holding a dead   */
/* address that later inprocessing writes through. Here it lives as    */
/* long as the handle does.                                            */
/*                                                                     */
/* And enough state to answer "is this call legal right now?" before   */
/* reaching CaDiCaL, whose own REQUIRE macros report through           */
/* __PRETTY_FUNCTION__ and internal file names.                        */

typedef struct {
  CCaDiCaL *solver;
  FILE *proof;       /* non-NULL: we own this handle and must fclose it */
  int proof_traced;  /* 1: CaDiCaL is tracing to it, close its side first */
  int interrupted;   /* address handed to ccadical_set_terminate */
  int configuring;   /* 1 until the first clause, constraint or solve */
  int last_status;   /* 0 none yet, 10 satisfied, 20 unsatisfied */
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
      /* Flush CaDiCaL's side first, or the tail of the proof is lost. Only
         if it actually started tracing: close_proof_trace requires a live
         tracer and would raise from inside a finalizer otherwise. */
      if (h->proof_traced)
        ccadical_close_proof(h->solver);
      fclose(h->proof);
      h->proof = NULL;
      h->proof_traced = 0;
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
  h->configuring = 1;
  SEXP xptr = PROTECT(R_MakeExternalPtr(h, Rf_install("zusat_solver"), R_NilValue));
  R_RegisterCFinalizerEx(xptr, zusat_finalize, TRUE);
  Rf_setAttrib(xptr, R_ClassSymbol, Rf_mkString("zusat_solver"));
  UNPROTECT(1);
  return xptr;
}

/* ------------------------------------------------------------------ */
/* Literal validation                                                  */
/*                                                                     */
/* CaDiCaL allocates its variable arrays densely up to the largest     */
/* index it has seen, and its own input check rejects only INT_MIN.    */
/* So a single stray large literal -- a row id, a hash, INT_MAX -- has */
/* CaDiCaL request billions of slots and the process dies to the OOM   */
/* killer with no R error to catch. The ceiling is enforced in R,      */
/* where the message can name the argument; this is the last line of   */
/* defence for anything reaching C by another route.                   */

SEXP zusat_max_var_get(void) {
  return Rf_ScalarInteger(ZUSAT_MAX_VAR);
}

static void check_lits(const int *lits, R_xlen_t n) {
  for (R_xlen_t i = 0; i < n; i++) {
    if (lits[i] == NA_INTEGER)
      Rf_error("literals must not be NA");
    if (lits[i] == 0)
      Rf_error("0 is not a valid literal (clauses are terminated automatically)");
    if (lits[i] > ZUSAT_MAX_VAR || lits[i] < -ZUSAT_MAX_VAR)
      Rf_error("literal %d exceeds the maximum variable index %d",
               lits[i], ZUSAT_MAX_VAR);
  }
}

/* ------------------------------------------------------------------ */
/* Proof tracing                                                       */

SEXP zusat_trace_proof(SEXP xptr, SEXP path) {
  zusat_handle *h = handle_from(xptr);
  if (TYPEOF(path) != STRSXP || XLENGTH(path) != 1)
    Rf_error("proof path must be a single string");
  if (h->proof != NULL)
    Rf_error("this solver is already tracing a proof");
  /* CaDiCaL requires state CONFIGURING: a proof begun later records only
     part of the derivation, which is worse than none because it still looks
     checkable. Checked here so the caller gets this message rather than a
     contract violation reported against an internal function name. */
  if (!h->configuring)
    Rf_error("start tracing before adding clauses or solving: CaDiCaL can "
             "only trace a complete proof from a freshly created solver");

  const char *file = CHAR(STRING_ELT(path, 0));
  /* "wb", not "w". On Windows text mode rewrites every \n as \r\n, and the
     binary proof encoding emits raw bytes -- a variable-byte literal can be
     0x0A -- so text mode silently corrupts the proof. CaDiCaL opens its own
     proof files with "wb" for the same reason (File::write_file). Binary mode
     is equally correct for the textual formats: they are written with \n
     line endings, which every checker accepts. */
  FILE *f = fopen(file, "wb");
  if (f == NULL)
    Rf_error("could not open '%s' for writing", file);

  /* Record the handle before handing it over, so ownership is unambiguous
     however this call exits: if ccadical_trace_proof raises, the finalizer
     still closes the file instead of leaking the descriptor. */
  h->proof = f;
  h->proof_traced = 0;
  if (!ccadical_trace_proof(h->solver, f, file)) {
    h->proof = NULL;
    fclose(f);
    Rf_error("could not start proof tracing to '%s'", file);
  }
  h->proof_traced = 1;
  return R_NilValue;
}

SEXP zusat_close_proof(SEXP xptr) {
  zusat_handle *h = handle_from(xptr);
  if (h->proof == NULL)
    Rf_error("this solver is not tracing a proof");
  if (h->proof_traced)
    ccadical_close_proof(h->solver);
  fclose(h->proof);
  h->proof = NULL;
  h->proof_traced = 0;
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

SEXP zusat_add_clause(SEXP xptr, SEXP lits) {
  zusat_handle *h = handle_from(xptr);
  if (TYPEOF(lits) != INTSXP)
    Rf_error("clause must be an integer vector");

  R_xlen_t n = XLENGTH(lits);
  const int *p = INTEGER(lits);
  check_lits(p, n);

  h->configuring = 0;
  for (R_xlen_t i = 0; i < n; i++)
    ccadical_add(h->solver, p[i]);
  ccadical_add(h->solver, 0); /* terminate clause */

  return R_NilValue;
}

/* ------------------------------------------------------------------ */
/* Solving                                                             */

SEXP zusat_solve(SEXP xptr, SEXP assumptions) {
  zusat_handle *h = handle_from(xptr);

  if (TYPEOF(assumptions) != INTSXP)
    Rf_error("assumptions must be an integer vector");
  R_xlen_t na = XLENGTH(assumptions);
  const int *ap = INTEGER(assumptions);
  check_lits(ap, na);

  h->configuring = 0;
  for (R_xlen_t i = 0; i < na; i++)
    ccadical_assume(h->solver, ap[i]);

  h->interrupted = 0;
  ccadical_set_terminate(h->solver, &h->interrupted, terminate_cb);
  int res = ccadical_solve(h->solver);
  ccadical_set_terminate(h->solver, NULL, NULL);

  if (h->interrupted) {
    /* CaDiCaL has unwound cleanly; now it is safe to longjmp. */
    h->last_status = 0;
    Rf_error("solve interrupted");
  }

  h->last_status = res;

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
  zusat_handle *h = handle_from(xptr);
  if (TYPEOF(vars) != INTSXP)
    Rf_error("vars must be an integer vector");
  /* val() requires state SATISFIED. Without this the caller gets CaDiCaL's
     contract violation, which names an internal function and aborts. */
  if (h->last_status != 10)
    Rf_error("no model available: call sat_solve() first and check that it "
             "returned \"sat\"");

  R_xlen_t n = XLENGTH(vars);
  const int *vp = INTEGER(vars);
  check_lits(vp, n);

  SEXP out = PROTECT(Rf_allocVector(LGLSXP, n));
  int *op = LOGICAL(out);

  /* Beyond max_var the solver holds no information, and asking anyway used
     to yield a confident FALSE. Report it the same way as an unassigned
     variable: there is no value here. */
  int known = ccadical_vars(h->solver);
  for (R_xlen_t i = 0; i < n; i++) {
    if (vp[i] > known) {
      op[i] = NA_LOGICAL;
    } else {
      int v = ccadical_val(h->solver, vp[i]);
      op[i] = (v == 0) ? NA_LOGICAL : (v > 0);
    }
  }
  UNPROTECT(1);
  return out;
}

SEXP zusat_failed(SEXP xptr, SEXP assumptions) {
  zusat_handle *h = handle_from(xptr);
  if (TYPEOF(assumptions) != INTSXP)
    Rf_error("assumptions must be an integer vector");
  /* failed() requires state UNSATISFIED. */
  if (h->last_status != 20)
    Rf_error("no failed assumptions available: sat_failed() needs a solve "
             "that returned \"unsat\"");

  R_xlen_t n = XLENGTH(assumptions);
  const int *ap = INTEGER(assumptions);
  check_lits(ap, n);

  SEXP out = PROTECT(Rf_allocVector(LGLSXP, n));
  int *op = LOGICAL(out);

  for (R_xlen_t i = 0; i < n; i++)
    op[i] = (ccadical_failed(h->solver, ap[i]) != 0);

  UNPROTECT(1);
  return out;
}

/* ------------------------------------------------------------------ */
/* Options and introspection                                           */

SEXP zusat_configuring(SEXP xptr) {
  return Rf_ScalarLogical(handle_from(xptr)->configuring != 0);
}

SEXP zusat_set_option(SEXP xptr, SEXP name, SEXP value) {
  zusat_handle *h = handle_from(xptr);
  if (TYPEOF(name) != STRSXP || XLENGTH(name) != 1)
    Rf_error("option name must be a single string");
  if (TYPEOF(value) != INTSXP || XLENGTH(value) != 1)
    Rf_error("option value must be a single integer");
  /* Solver::set requires state CONFIGURING for everything except the four
     reporting options. The R layer checks first so the message names the
     option; this is the last line of defence. */
  ccadical_set_option(h->solver, CHAR(STRING_ELT(name, 0)), INTEGER(value)[0]);
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
  zusat_handle *h = handle_from(xptr);
  if (TYPEOF(lits) != INTSXP)
    Rf_error("constraint must be an integer vector");

  R_xlen_t n = XLENGTH(lits);
  const int *p = INTEGER(lits);
  check_lits(p, n);

  h->configuring = 0;
  for (R_xlen_t i = 0; i < n; i++)
    ccadical_constrain(h->solver, p[i]);
  ccadical_constrain(h->solver, 0); /* terminate the constraint clause */

  return R_NilValue;
}

SEXP zusat_constraint_failed(SEXP xptr) {
  zusat_handle *h = handle_from(xptr);
  if (h->last_status != 20)
    Rf_error("sat_constraint_failed() needs a solve that returned \"unsat\"");
  return Rf_ScalarLogical(ccadical_constraint_failed(h->solver) != 0);
}

SEXP zusat_fixed(SEXP xptr, SEXP lits) {
  CCaDiCaL *s = solver_from(xptr);
  if (TYPEOF(lits) != INTSXP)
    Rf_error("lits must be an integer vector");

  R_xlen_t n = XLENGTH(lits);
  const int *p = INTEGER(lits);
  check_lits(p, n);

  SEXP out = PROTECT(Rf_allocVector(LGLSXP, n));
  int *op = LOGICAL(out);

  for (R_xlen_t i = 0; i < n; i++) {
    /* 1 = implied true, -1 = implied false, 0 = not yet decided */
    int f = ccadical_fixed(s, p[i]);
    op[i] = (f == 0) ? NA_LOGICAL : (f > 0);
  }
  UNPROTECT(1);
  return out;
}

SEXP zusat_simplify(SEXP xptr) {
  zusat_handle *h = handle_from(xptr);

  /* Inprocessing polls the terminator from two dozen modules, so a long
     simplify is interruptible on the same terms as a solve. */
  h->configuring = 0;
  h->interrupted = 0;
  ccadical_set_terminate(h->solver, &h->interrupted, terminate_cb);
  int res = ccadical_simplify(h->solver);
  ccadical_set_terminate(h->solver, NULL, NULL);

  if (h->interrupted) {
    h->last_status = 0;
    Rf_error("simplify interrupted");
  }

  h->last_status = res;

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
