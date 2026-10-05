# Cardinality constraints

Require that at most, at least, or exactly `k` of a set of literals are
true. CNF has no way to say this directly, so these encode the
constraint as clauses and add them to the solver.

## Usage

``` r
sat_at_most(
  solver,
  literals,
  k,
  encoding = c("auto", "pairwise", "sequential")
)

sat_at_least(
  solver,
  literals,
  k,
  encoding = c("auto", "pairwise", "sequential")
)

sat_exactly(
  solver,
  literals,
  k,
  encoding = c("auto", "pairwise", "sequential")
)
```

## Arguments

- solver:

  A `zusat_solver`.

- literals:

  Numeric vector of non-zero literals. Negative literals are allowed, so
  "at most two of these are *false*" is expressible directly.

- k:

  The bound.

- encoding:

  One of `"auto"`, `"pairwise"` or `"sequential"`.

## Value

`solver`, invisibly.

## Details

This is what most real modelling needs and what hand-rolling gets wrong:
"each item in exactly one bucket", "no more than three shifts in a row",
"at least two reviewers".

## Why these take a solver

Every encoding except the pairwise one introduces auxiliary variables,
and those must not collide with variables already in the formula. Taking
a solver means they can be allocated above
[`sat_n_vars()`](https://pedrobtz.github.io/zusat/reference/sat_n_vars.md),
which is the one number that is always correct. A function returning
bare clauses would make that the caller's problem, and a collision does
not raise an error – it silently changes what the formula means.

## Reserve your variables first

Auxiliaries are allocated above every variable in use *so far*, so a
variable you only introduce later may land on one. The solver remembers
which variables are auxiliary and refuses them in
[`sat_add()`](https://pedrobtz.github.io/zusat/reference/sat_add.md),
[`sat_constrain()`](https://pedrobtz.github.io/zusat/reference/sat_constrain.md),
assumptions, `vars` in
[`sat_solutions()`](https://pedrobtz.github.io/zusat/reference/sat_solutions.md)
and these functions, rather than let the two silently merge. To avoid
the error, declare your whole variable range up front with
[`sat_reserve()`](https://pedrobtz.github.io/zusat/reference/sat_reserve.md):

    s <- sat_solver()
    sat_reserve(s, 24)       # variables 1..24 are ours
    sat_exactly(s, 1:12, 1)  # auxiliaries now start at 25
    sat_exactly(s, 13:24, 1)

A constraint is added whole or not at all: if it cannot be encoded, for
instance because its auxiliaries would pass the maximum variable index,
nothing is added.

## Choosing an encoding

- `"pairwise"`:

  Forbid every `k+1` subset. No auxiliary variables, but
  `choose(n, k + 1)` clauses – fine for small sets, hopeless beyond
  them.

- `"sequential"`:

  Sinz's sequential counter. `(n - 1) * k` auxiliary variables and about
  `2 * n * k` clauses, so it stays usable at sizes where pairwise has
  exploded.

- `"auto"`:

  Pairwise while its clause count is small, sequential after. The
  default, and the right choice unless you are measuring.

The difference is not marginal: at 40 literals with `k = 3`, pairwise is
91,390 clauses and sequential is about 250.

## Examples

``` r
# at most one of x1..x4
s <- sat_solver()
sat_at_most(s, 1:4, 1)
sat_solve(s)
#> <zusat_solution> sat  (4 variables, 6 active clauses, 0.000s)
#>  variable value
#>         1 FALSE
#>         2 FALSE
#>         3 FALSE
#>         4 FALSE

# exactly one -- the usual "pick one bucket" constraint
s <- sat_solver()
sat_exactly(s, 1:4, 1)
nrow(sat_solutions(s, vars = 1:4)) / 4 # four ways
#> [1] 4
```
