# Enumerate satisfying assignments

Finds distinct models, not just one. After each model the negation of
that assignment is added as a clause, so the next solve is forced to
differ; the solver keeps everything it has learned between rounds, which
is why this is much cheaper than solving from scratch each time.

## Usage

``` r
sat_solutions(x, limit = 1000, vars = NULL, assumptions = integer(), ...)

# Default S3 method
sat_solutions(x, limit = 1000, vars = NULL, assumptions = integer(), ...)

# S3 method for class 'zusat_solver'
sat_solutions(x, limit = 1000, vars = NULL, assumptions = integer(), ...)
```

## Arguments

- x:

  A list of clauses, or a `zusat_solver`.

- limit:

  Maximum number of solutions. Defaults to 1000 rather than `Inf`: the
  count is usually exponential, and an accidental unbounded enumeration
  is a hang rather than an error. Pass `Inf` deliberately.

- vars:

  Variables to enumerate over. Defaults to every variable in the
  formula.

- assumptions:

  Literals assumed true for every solve in the enumeration.

- ...:

  Passed to methods.

## Value

A
[zusat_solutions](https://pedrobtz.github.io/zusat/reference/zusat_solutions.md)
object: a data frame with one row per variable per solution, with
columns `solution`, `variable` and `value`. Use
[`sat_complete()`](https://pedrobtz.github.io/zusat/reference/sat_n_solutions.md)
to tell an exhausted enumeration from one that stopped at `limit`.

## Projecting onto the variables you care about

Encodings introduce auxiliary variables – Tseitin variables for a
circuit, order variables for a cardinality constraint – and a formula
with 10 real variables and 200 auxiliaries has models that differ only
in auxiliaries. Enumerating over all of them returns the same answer
many times over.

`vars` restricts both what is reported and what is blocked, so each
distinct assignment of those variables is returned exactly once. Neither
`pycosat` nor `PySAT` projects by default, and it is the difference
between a handful of answers and an intractable number of them.

## Enumerating from a solver

Blocking clauses are permanent, so enumerating from a `zusat_solver`
modifies it: afterwards it holds the original formula plus a clause
ruling out every model found. That is occasionally what you want and
usually not, so pass the formula instead when the solver is still
needed.

## See also

[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
for a single model.

## Examples

``` r
# three ways to satisfy (x1 OR x2)
sols <- sat_solutions(list(c(1, 2)))
sat_n_solutions(sols)
#> [1] 3

# project onto variable 1: only two distinct answers remain
sat_n_solutions(sat_solutions(list(c(1, 2)), vars = 1))
#> [1] 2
```
