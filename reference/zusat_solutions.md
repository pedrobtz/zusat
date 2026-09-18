# The result of an enumeration

[`sat_solutions()`](https://pedrobtz.github.io/zusat/reference/sat_solutions.md)
returns an object of class `zusat_solutions`. It is a data frame in long
form, one row per variable per solution:

## Details

- solution:

  integer, which solution the row belongs to

- variable:

  integer, the variable number

- value:

  logical, its value in that solution

Long form rather than one row per solution because the variables
enumerated over are chosen at call time via `vars`, so a wide frame
would have a shape that changes with the arguments. Long form also
groups and joins directly; use `split(x, x$solution)` to iterate
solution by solution.

## Attributes

`status`, `n_solutions` and `complete`. Read them with
[`sat_status()`](https://pedrobtz.github.io/zusat/reference/sat_status.md),
[`sat_n_solutions()`](https://pedrobtz.github.io/zusat/reference/sat_n_solutions.md)
and
[`sat_complete()`](https://pedrobtz.github.io/zusat/reference/sat_n_solutions.md).

[`sat_complete()`](https://pedrobtz.github.io/zusat/reference/sat_n_solutions.md)
is the one that matters: an enumeration stopped at `limit` looks exactly
like an exhaustive one unless you ask.

## See also

[`sat_solutions()`](https://pedrobtz.github.io/zusat/reference/sat_solutions.md),
[`sat_complete()`](https://pedrobtz.github.io/zusat/reference/sat_n_solutions.md)

## Examples

``` r
sols <- sat_solutions(list(c(1, 2)))
class(sols)
#> [1] "zusat_solutions" "data.frame"     
sat_complete(sols)
#> [1] TRUE
```
