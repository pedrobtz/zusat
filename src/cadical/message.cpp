#include "zusat_r_compat.h"
#include "internal.hpp"

namespace CaDiCaL {

/*------------------------------------------------------------------------*/
#ifndef QUIET
/*------------------------------------------------------------------------*/

void Internal::print_prefix () { Rprintf ("%s", prefix.c_str ()); }

void Internal::vmessage (const char *fmt, va_list &ap) {
#ifdef LOGGING
  if (!opts.log)
#endif
    if (opts.quiet)
      return;
  print_prefix ();
  vprintf (fmt, ap);
  Rprintf ("%c", '\n');
  ((void) 0);
}

void Internal::message (const char *fmt, ...) {
#ifdef LOGGING
  if (!opts.log)
#endif
    if (opts.quiet)
      return;

  va_list ap;
  va_start (ap, fmt);
  vmessage (fmt, ap);
  va_end (ap);
}

void Internal::message () {
#ifdef LOGGING
  if (!opts.log)
#endif
    if (opts.quiet)
      return;
  print_prefix ();
  Rprintf ("%c", '\n');
  ((void) 0);
}

/*------------------------------------------------------------------------*/

void Internal::vverbose (int level, const char *fmt, va_list &ap) {
#ifdef LOGGING
  if (!opts.log)
#endif
    if (opts.quiet || level > opts.verbose)
      return;
  print_prefix ();
  vprintf (fmt, ap);
  Rprintf ("%c", '\n');
  ((void) 0);
}

void Internal::verbose (int level, const char *fmt, ...) {
  va_list ap;
  va_start (ap, fmt);
  vverbose (level, fmt, ap);
  va_end (ap);
}

void Internal::verbose (int level) {
#ifdef LOGGING
  if (!opts.log)
#endif
    if (opts.quiet || level > opts.verbose)
      return;
  print_prefix ();
  Rprintf ("%c", '\n');
  ((void) 0);
}

/*------------------------------------------------------------------------*/

void Internal::section (const char *title) {
#ifdef LOGGING
  if (!opts.log)
#endif
    if (opts.quiet)
      return;
  if (stats.sections++)
    MSG ();
  print_prefix ();
  tout.blue ();
  Rprintf ("%s", "--- [ ");
  tout.blue (true);
  Rprintf ("%s", title);
  tout.blue ();
  Rprintf ("%s", " ] ");
  for (int i = strlen (title) + strlen (prefix.c_str ()) + 9; i < 78; i++)
    Rprintf ("%c", '-');
  tout.normal ();
  Rprintf ("%c", '\n');
  MSG ();
}

/*------------------------------------------------------------------------*/

void Internal::phase (const char *phase, const char *fmt, ...) {
#ifdef LOGGING
  if (!opts.log)
#endif
    if (opts.quiet || (!force_phase_messages && opts.verbose < 2))
      return;
  print_prefix ();
  Rprintf ("[%s] ", phase);
  va_list ap;
  va_start (ap, fmt);
  vprintf (fmt, ap);
  va_end (ap);
  Rprintf ("%c", '\n');
  ((void) 0);
}

void Internal::phase (const char *phase, int64_t count, const char *fmt,
                      ...) {
#ifdef LOGGING
  if (!opts.log)
#endif
    if (opts.quiet || (!force_phase_messages && opts.verbose < 2))
      return;
  print_prefix ();
  Rprintf ("[%s-%" PRId64 "] ", phase, count);
  va_list ap;
  va_start (ap, fmt);
  vprintf (fmt, ap);
  va_end (ap);
  Rprintf ("%c", '\n');
  ((void) 0);
}

/*------------------------------------------------------------------------*/
#endif // ifndef QUIET
/*------------------------------------------------------------------------*/

void Internal::warning (const char *fmt, ...) {
  ((void) 0);
  terr.bold ();
  REprintf ("%s", "cadical: ");
  terr.red (1);
  REprintf ("%s", "warning:");
  terr.normal ();
  REprintf ("%c", ' ');
  va_list ap;
  va_start (ap, fmt);
  REvprintf (fmt, ap);
  va_end (ap);
  REprintf ("%c", '\n');
  ((void) 0);
}

/*------------------------------------------------------------------------*/

void Internal::error_message_start () {
  ((void) 0);
  terr.bold ();
  REprintf ("%s", "cadical: ");
  terr.red (1);
  REprintf ("%s", "error:");
  terr.normal ();
  REprintf ("%c", ' ');
}

void Internal::error_message_end () {
  REprintf ("%c", '\n');
  ((void) 0);
  // TODO add possibility to use call back instead.
  ZUSAT_FATAL ("fatal error");
}

void Internal::verror (const char *fmt, va_list &ap) {
  error_message_start ();
  REvprintf (fmt, ap);
  error_message_end ();
}

void Internal::error (const char *fmt, ...) {
  va_list ap;
  va_start (ap, fmt);
  verror (fmt, ap);
  va_end (ap); // unreachable
}

/*------------------------------------------------------------------------*/

void fatal_message_start () {
  ((void) 0);
  terr.bold ();
  REprintf ("%s", "cadical: ");
  terr.red (1);
  REprintf ("%s", "fatal error:");
  terr.normal ();
  REprintf ("%c", ' ');
}

void fatal_message_end () {
  REprintf ("%c", '\n');
  ((void) 0);
  ZUSAT_FATAL ("aborted");
}

void fatal (const char *fmt, ...) {
  fatal_message_start ();
  va_list ap;
  va_start (ap, fmt);
  REvprintf (fmt, ap);
  va_end (ap);
  fatal_message_end ();
  ZUSAT_FATAL ("aborted");
}

} // namespace CaDiCaL