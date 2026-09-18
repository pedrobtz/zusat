# Did the constraint cause unsatisfiability?

After
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
returns `"unsat"` for a call made with
[`sat_constrain()`](https://pedrobtz.github.io/zusat/reference/sat_constrain.md),
this reports whether the constraint was responsible – the
constraint-level counterpart of
[`sat_failed()`](https://pedrobtz.github.io/zusat/reference/sat_failed.md).

## Usage

``` r
sat_constraint_failed(solver)
```

## Arguments

- solver:

  A `zusat_solver`.

## Value

A single logical.

## Examples

``` r
s <- sat_solver(list(1))
sat_constrain(s, -1)
sat_solve(s)
#> <zusat_solution> unsat  (1 variable, 0 active clauses, 0.001s)
sat_constraint_failed(s)
#> [1] TRUE
```
