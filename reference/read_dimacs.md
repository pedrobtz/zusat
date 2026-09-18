# Read a formula from a DIMACS CNF file

DIMACS is the format every SAT solver and benchmark set speaks, so this
is usually how a real problem arrives.

## Usage

``` r
read_dimacs(path)
```

## Arguments

- path:

  Path to a `.cnf` file.

## Value

A list of integer vectors, one per clause, suitable for
[`sat_solve()`](https://pedrobtz.github.io/zusat/reference/sat_solve.md)
or
[`sat_solver()`](https://pedrobtz.github.io/zusat/reference/sat_solver.md).

## Details

The parser is deliberately lenient about the things files in the wild
actually do:

- clauses may span several lines, and several clauses may share one;

- the `p cnf` header is not required, and its counts are not trusted –
  plenty of files disagree with themselves, and the clauses are the
  truth;

- a final clause missing its terminating `0` is still read;

- a `%` line ends the file, which is what SATLIB benchmarks use. Without
  this the `0` that follows it would be read as an empty clause and turn
  every SATLIB instance unsatisfiable.

## See also

[`write_dimacs()`](https://pedrobtz.github.io/zusat/reference/write_dimacs.md)

## Examples

``` r
f <- tempfile(fileext = ".cnf")
write_dimacs(list(c(1, 2), c(-1, 3)), f)
read_dimacs(f)
#> [[1]]
#> [1] 1 2
#> 
#> [[2]]
#> [1] -1  3
#> 
sat_solve(read_dimacs(f))
#> <zusat_solution> sat  (3 variables, 2 active clauses, 0.000s)
#>  variable value
#>         1  TRUE
#>         2  TRUE
#>         3  TRUE
```
