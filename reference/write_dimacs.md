# Write a formula to a DIMACS CNF file

Write a formula to a DIMACS CNF file

## Usage

``` r
write_dimacs(x, path, comment = NULL)
```

## Arguments

- x:

  A list of clauses, as accepted by
  [`sat_add()`](https://pedrobtz.github.io/zusat/reference/sat_add.md).

- path:

  Path to write to.

- comment:

  Optional character vector written as `c` comment lines at the top of
  the file.

## Value

`path`, invisibly.

## See also

[`read_dimacs()`](https://pedrobtz.github.io/zusat/reference/read_dimacs.md)

## Examples

``` r
f <- tempfile(fileext = ".cnf")
write_dimacs(list(c(1, 2), c(-1, 3)), f, comment = "an example")
cat(readLines(f), sep = "\n")
#> c an example
#> p cnf 3 2
#> 1 2 0
#> -1 3 0
```
