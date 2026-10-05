// Option metadata the C API does not expose.
//
// ccadical_set_option() discards whether the name was known, and both it and
// ccadical_get_option() treat an unknown name as a silent no-op returning 0,
// so a misspelled option was indistinguishable from a valid one set to zero.
// CaDiCaL also clamps an out-of-range value to the option's bounds without
// saying so. Its option table holds both facts, but only C++ can read it.

#include "internal.hpp"

extern "C" int zusat_option_range (const char *name, int *lo, int *hi) {
  const CaDiCaL::Option *o = CaDiCaL::Options::has (name);
  if (!o)
    return 0;
  *lo = o->lo;
  *hi = o->hi;
  return 1;
}
