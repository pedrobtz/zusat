# Number of solutions found, and whether that is all of them

`sat_complete()` is the part worth checking.
[`sat_solutions()`](https://pedrobtz.github.io/zusat/reference/sat_solutions.md)
stops at `limit`, and a truncated enumeration looks exactly like an
exhaustive one unless you ask.

## Usage

``` r
sat_n_solutions(x)

sat_complete(x)
```

## Arguments

- x:

  A
  [zusat_solutions](https://pedrobtz.github.io/zusat/reference/zusat_solutions.md)
  object.

## Value

`sat_n_solutions()` returns a count. `sat_complete()` returns `TRUE`
when the enumeration ran out of models rather than hitting `limit`.

## Examples

``` r
sols <- sat_solutions(list(c(1, 2)), limit = 2)
sat_n_solutions(sols)
#> [1] 2
sat_complete(sols)
#> [1] FALSE
```
