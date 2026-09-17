#include "zusat.h"
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

static const R_CallMethodDef CallEntries[] = {
  {"zusat_solver_new", (DL_FUNC) &zusat_solver_new, 0},
  {"zusat_add_clause", (DL_FUNC) &zusat_add_clause, 2},
  {"zusat_solve",      (DL_FUNC) &zusat_solve,      2},
  {"zusat_value",      (DL_FUNC) &zusat_value,      2},
  {"zusat_failed",     (DL_FUNC) &zusat_failed,     2},
  {"zusat_set_option", (DL_FUNC) &zusat_set_option, 3},
  {"zusat_get_option", (DL_FUNC) &zusat_get_option, 2},
  {"zusat_n_vars",     (DL_FUNC) &zusat_n_vars,     1},
  {"zusat_signature",  (DL_FUNC) &zusat_signature,  0},
  {NULL, NULL, 0}
};

void attribute_visible R_init_zusat(DllInfo *dll) {
  R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
