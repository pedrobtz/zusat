# Bound how hard a solve may work

SAT is NP-complete, so an innocuous-looking formula can take longer than
the remaining age of the universe. A limit makes a solve give up
instead, returning `"unknown"` rather than an answer.

## Usage

``` r
sat_limit(solver, name, value)
```

## Arguments

- solver:

  A `zusat_solver`.

- name:

  One of `"conflicts"`, `"decisions"`, `"preprocessing"`,
  `"localsearch"`, `"ticks"` or `"terminate"`. `"conflicts"` is the
  usual choice: it bounds search effort in the unit solver authors
  reason about, and is roughly proportional to work done.

- value:

  Maximum for that measure. A negative value means no limit.

## Value

`solver`, invisibly.

## Details

This is what you want before calling
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
anywhere a hang is unacceptable: inside a loop, a Shiny app, or a
scheduled job.

## Limits last one solve

Like assumptions, limits are consumed by the next
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
and are not retained afterwards. Set them again before each call.

## See also

[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md),
[`sat_status()`](https://pedrobtz.github.io/zusat/reference/sat_status.md)

## Examples

``` r
s <- sat_solver(list(c(1, 2), c(-1, 2)))
sat_limit(s, "conflicts", 1000)
sat_solve(s)
#> <zusat_solution> sat  (2 variables, 2 active clauses, 0.000s)
#>  variable value
#>         1  TRUE
#>         2  TRUE
```
