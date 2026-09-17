#include "zusat_r_compat.h"
#ifdef LOGGING

#include "internal.hpp"

namespace CaDiCaL {

void Logger::print_log_prefix (Internal *internal) {
  internal->print_prefix ();
  tout.magenta ();
  Rprintf ("%s", "LOG ");
  tout.magenta (true);
  Rprintf ("%d ", internal->level);
  tout.normal ();
}

void Logger::log_empty_line (Internal *internal) {
  internal->print_prefix ();
  tout.magenta ();
  const int len = internal->prefix.size (), max = 78 - len;
  for (int i = 0; i < max; i++)
    Rprintf ("%c", '-');
  Rprintf ("%c", '\n');
  tout.normal ();
  ((void) 0);
}

void Logger::log (Internal *internal, const char *fmt, ...) {
  print_log_prefix (internal);
  tout.magenta ();
  va_list ap;
  va_start (ap, fmt);
  vprintf (fmt, ap);
  va_end (ap);
  Rprintf ("%c", '\n');
  tout.normal ();
  ((void) 0);
}

// It is hard to factor out the common part between the two clause loggers,
// since they are also used in slightly different contexts.  Our attempt to
// do so were not more readable than the current version.  See the header
// for an explanation of the difference between the following two functions.

void Logger::log (Internal *internal, const Clause *c, const char *fmt,
                  ...) {
  print_log_prefix (internal);
  tout.magenta ();
  va_list ap;
  va_start (ap, fmt);
  vprintf (fmt, ap);
  va_end (ap);
  if (c) {
    if (c->redundant)
      Rprintf (" glue %d redundant", c->glue);
    else
      Rprintf (" irredundant");
    Rprintf (" size %d clause[%" PRId64 "]", c->size, c->id);
    if (c->moved)
      Rprintf (" ... (moved)");
    else {
      if (internal->opts.logsort) {
        vector<int> s;
        for (const auto &lit : *c)
          s.push_back (lit);
        sort (s.begin (), s.end (), clause_lit_less_than ());
        for (const auto &lit : s)
          Rprintf (" %d", lit);
      } else {
        for (const auto &lit : *c) {
          Rprintf (" %s", loglit (internal, lit).c_str ());
        }
      }
    }
  } else if (internal->level)
    Rprintf (" decision");
  else
    Rprintf (" unit");
  Rprintf ("%c", '\n');
  tout.normal ();
  ((void) 0);
}

void Logger::log (Internal *internal, const Gate *g, const char *fmt, ...) {
  print_log_prefix (internal);
  tout.magenta ();
  va_list ap;
  va_start (ap, fmt);
  vprintf (fmt, ap);
  va_end (ap);
  if (g) {
    Rprintf ("%s%s gate[%" PRIu64 "] (arity: %zu) %s := %s",
            special_gate_str (g->degenerated_gate).c_str (),
            g->garbage ? " garbage" : "", g->id, g->arity (),
            loglit (internal, g->lhs).c_str (),
            string_of_gate (g->tag).c_str ());
    for (const auto &lit : g->rhs) {
      Rprintf (" %s", loglit (internal, lit).c_str ());
    }
  } else
    Rprintf (" null gate");
  Rprintf ("%c", '\n');
  tout.normal ();
  ((void) 0);
}

// Same as above, but for the global clause 'c' (which is not a reason).

void Logger::log (Internal *internal, const vector<int> &c, const char *fmt,
                  ...) {
  print_log_prefix (internal);
  tout.magenta ();
  va_list ap;
  va_start (ap, fmt);
  vprintf (fmt, ap);
  va_end (ap);
  if (internal->opts.logsort) {
    vector<int> s;
    for (const auto &lit : c)
      s.push_back (lit);
    sort (s.begin (), s.end (), clause_lit_less_than ());
    for (const auto &lit : s)
      Rprintf (" %d", lit);
  } else {
    for (const auto &lit : c)
      Rprintf (" %d", lit);
  }
  Rprintf ("%c", '\n');
  tout.normal ();
  ((void) 0);
}

// Now for 'restore_clause' to avoid copying (without logging).

void Logger::log (Internal *internal,
                  const vector<int>::const_iterator &begin,
                  const vector<int>::const_iterator &end, const char *fmt,
                  ...) {
  print_log_prefix (internal);
  tout.magenta ();
  va_list ap;
  va_start (ap, fmt);
  vprintf (fmt, ap);
  va_end (ap);
  if (internal->opts.logsort) {
    vector<int> s;
    for (auto p = begin; p != end; p++)
      s.push_back (*p);
    sort (s.begin (), s.end (), clause_lit_less_than ());
    for (const auto &lit : s)
      Rprintf (" %d", lit);
  } else {
    for (auto p = begin; p != end; p++)
      Rprintf (" %d", *p);
  }
  Rprintf ("%c", '\n');
  tout.normal ();
  ((void) 0);
}

// for LRAT proof chains

void Logger::log (Internal *internal, const vector<int64_t> &c,
                  const char *fmt, ...) {
  print_log_prefix (internal);
  tout.magenta ();
  va_list ap;
  va_start (ap, fmt);
  vprintf (fmt, ap);
  va_end (ap);
  for (const auto &id : c)
    Rprintf (" %" PRId64, id);
  Rprintf ("%c", '\n');
  tout.normal ();
  ((void) 0);
}

// for LRAT proof clauses

void Logger::log (Internal *internal, const int *literals,
                  const unsigned size, const char *fmt, ...) {
  print_log_prefix (internal);
  tout.magenta ();
  va_list ap;
  va_start (ap, fmt);
  vprintf (fmt, ap);
  va_end (ap);
  for (unsigned i = 0; i < size; i++) {
    const int lit = literals[i];
    Rprintf (" %d", lit);
  }
  Rprintf ("%c", '\n');
  tout.normal ();
  ((void) 0);
}

string Logger::loglit (Internal *internal, int lit) {
  std::string v = std::to_string (lit);
  if (lit && -internal->max_var <= lit && internal->max_var >= lit) {
    const int va = internal->val (lit);
    if (va) {
      v = v + "@" + std::to_string (internal->var (lit).level);
      if (!internal->var (lit).reason)
        v = v + "+";
    }
    if (va > 0)
      v += "=1";
    else if (va < 0)
      v += "=-1";
  }
  return v;
}
} // namespace CaDiCaL

#endif