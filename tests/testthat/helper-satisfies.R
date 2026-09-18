# Does an assignment satisfy every clause?
#
# This is the property worth asserting about a model. Comparing against one
# expected assignment instead would pin solver behaviour: any satisfying
# assignment is a correct answer, so an exact comparison breaks on a CaDiCaL
# upgrade that happens to pick a different valid model.
#
# `m` is a named logical vector as returned by sat_assignment(), indexed by
# variable number. Unassigned variables (NA) are treated as TRUE; either
# polarity extends the model, so the caller may pick freely.
satisfies_all <- function(formula, m) {
  m[is.na(m)] <- TRUE
  satisfied <- vapply(formula, function(clause) {
    values <- m[as.character(abs(clause))]
    any(ifelse(clause > 0, values, !values))
  }, logical(1))
  all(satisfied)
}
