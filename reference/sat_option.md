# Get or set a CaDiCaL option

CaDiCaL exposes several hundred integer-valued tuning options, for
example `"elim"`, `"vivify"`, or `"restartint"`. Names are as documented
by CaDiCaL itself.

## Usage

``` r
sat_option(solver, name, value)
```

## Arguments

- solver:

  A `zusat_solver`.

- name:

  A single option name.

- value:

  An integer value to set. When missing, the current value is returned
  instead.

## Value

The option value, invisibly when setting.

## Examples

``` r
s <- sat_solver()
sat_option(s, "elim")
#> [1] 1
```
