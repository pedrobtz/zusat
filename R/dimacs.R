#' Read a formula from a DIMACS CNF file
#'
#' DIMACS is the format every SAT solver and benchmark set speaks, so this is
#' usually how a real problem arrives.
#'
#' The parser is deliberately lenient about the things files in the wild
#' actually do:
#'
#' * clauses may span several lines, and several clauses may share one;
#' * the `p cnf` header is not required, and its counts are not trusted --
#'   plenty of files disagree with themselves, and the clauses are the truth;
#' * a final clause missing its terminating `0` is still read;
#' * a `%` line ends the file, which is what SATLIB benchmarks use. Without
#'   this the `0` that follows it would be read as an empty clause and turn
#'   every SATLIB instance unsatisfiable.
#'
#' @param path Path to a `.cnf` file.
#' @return A list of integer vectors, one per clause, suitable for
#'   [sat_solve()] or [sat_solver()].
#' @seealso [write_dimacs()]
#' @export
#' @examples
#' f <- tempfile(fileext = ".cnf")
#' write_dimacs(list(c(1, 2), c(-1, 3)), f)
#' read_dimacs(f)
#' sat_solve(read_dimacs(f))
read_dimacs <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("no such file: %s", path), call. = FALSE)
  }
  lines <- readLines(path, warn = FALSE)

  # SATLIB instances end with a "%" line followed by a stray 0; everything
  # from there on is trailer, not formula.
  stop_at <- which(grepl("^[[:space:]]*%", lines))
  if (length(stop_at)) {
    lines <- if (stop_at[1] == 1L) character() else lines[seq_len(stop_at[1] - 1L)]
  }

  lines <- lines[!grepl("^[[:space:]]*[cp]", lines)]
  if (!length(lines)) {
    return(list())
  }

  tokens <- unlist(strsplit(paste(lines, collapse = " "), "[[:space:]]+"))
  tokens <- tokens[nzchar(tokens)]
  if (!length(tokens)) {
    return(list())
  }

  values <- suppressWarnings(as.numeric(tokens))
  if (anyNA(values)) {
    bad <- tokens[is.na(values)][1]
    stop(sprintf("%s is not a DIMACS file: unexpected token '%s'",
                 basename(path), bad), call. = FALSE)
  }
  if (any(values != trunc(values))) {
    stop(sprintf("%s contains a non-integer literal", basename(path)),
         call. = FALSE)
  }
  values <- as.integer(values)

  ends <- which(values == 0L)
  # A file whose last clause is not terminated is still readable.
  if (!length(ends) || ends[length(ends)] != length(values)) {
    ends <- c(ends, length(values) + 1L)
  }
  starts <- c(1L, utils::head(ends, -1L) + 1L)

  clauses <- Map(function(from, to) {
    if (to <= from) integer() else values[seq(from, to - 1L)]
  }, starts, ends)

  # Drop the names Map() attaches, so the result is a plain list.
  unname(clauses)
}

#' Write a formula to a DIMACS CNF file
#'
#' @param x A list of clauses, as accepted by [sat_add()].
#' @param path Path to write to.
#' @param comment Optional character vector written as `c` comment lines at
#'   the top of the file.
#' @return `path`, invisibly.
#' @seealso [read_dimacs()]
#' @export
#' @examples
#' f <- tempfile(fileext = ".cnf")
#' write_dimacs(list(c(1, 2), c(-1, 3)), f, comment = "an example")
#' cat(readLines(f), sep = "\n")
write_dimacs <- function(x, path, comment = NULL) {
  if (!is.list(x)) {
    stop("`x` must be a list of clauses", call. = FALSE)
  }
  clauses <- lapply(x, as_literals, arg = "clauses")

  n_vars <- if (length(clauses)) max(0L, vapply(clauses, function(cl) {
    if (length(cl)) max(abs(cl)) else 0L
  }, integer(1))) else 0L

  header <- c(
    if (!is.null(comment)) paste("c", comment),
    sprintf("p cnf %d %d", n_vars, length(clauses))
  )
  body <- vapply(clauses, function(cl) paste(c(cl, 0L), collapse = " "),
                 character(1))

  writeLines(c(header, body), path)
  invisible(path)
}
