# Decode a binary DRAT proof.
#
# The point is to check the bytes really are a proof, not merely that the file
# is non-empty or contains some expected marker. A proof written through a
# text-mode stream on Windows would have every 0x0A rewritten as 0x0D 0x0A,
# and since a variable-byte literal can encode to 0x0A that corruption is
# invisible to any test that does not actually parse the encoding.
#
# Format: each step is 'a' (0x61) or 'd' (0x64), then literals, then 0x00.
# A literal l is encoded as x = 2 * abs(l) + (l < 0), emitted seven bits at a
# time, least significant first, with 0x80 set on every byte but the last.
decode_binary_drat <- function(path) {
  bytes <- readBin(path, "raw", file.size(path))
  i <- 1L
  steps <- list()

  while (i <= length(bytes)) {
    marker <- bytes[i]
    if (!marker %in% as.raw(c(0x61, 0x64))) {
      stop(sprintf("byte %d: expected a step marker, got 0x%02x", i,
                   as.integer(marker)))
    }
    kind <- if (marker == as.raw(0x61)) "a" else "d"
    i <- i + 1L

    lits <- integer()
    repeat {
      if (i > length(bytes)) stop("truncated proof: no terminator")
      if (bytes[i] == as.raw(0)) {
        i <- i + 1L
        break
      }
      x <- 0
      shift <- 0
      repeat {
        if (i > length(bytes)) stop("truncated proof: no terminator")
        b <- as.integer(bytes[i])
        i <- i + 1L
        x <- x + bitwAnd(b, 0x7f) * 2^shift
        shift <- shift + 7L
        if (bitwAnd(b, 0x80) == 0L) break
      }
      lit <- as.integer(x %/% 2)
      if (x %% 2 == 1) lit <- -lit
      lits <- c(lits, lit)
    }
    steps[[length(steps) + 1L]] <- list(kind = kind, literals = lits)
  }
  steps
}

# Parse a textual DRAT proof into the same shape, for comparison.
parse_text_drat <- function(path) {
  lines <- trimws(readLines(path))
  lines <- lines[nzchar(lines)]
  lapply(lines, function(line) {
    tokens <- strsplit(line, "[[:space:]]+")[[1]]
    kind <- if (identical(tokens[1], "d")) "d" else "a"
    if (kind == "d") tokens <- tokens[-1]
    values <- as.integer(tokens)
    list(kind = kind, literals = values[values != 0L])
  })
}

# A formula whose binary proof actually contains 0x0A bytes.
#
# This matters more than it looks. The obvious small contradictions produce
# proofs with no 0x0A in them at all, so simulated newline translation leaves
# the bytes untouched and a test built on them passes whether or not the
# stream was opened in binary mode. Pigeonhole 5-into-4 emits four of them in
# 247 bytes, which is enough for the corruption to change what decodes.
pigeonhole_formula <- function(pigeons, holes) {
  v <- function(i, j) (i - 1L) * holes + j
  clauses <- lapply(seq_len(pigeons), function(i) {
    vapply(seq_len(holes), function(j) v(i, j), numeric(1))
  })
  for (j in seq_len(holes)) {
    for (pair in utils::combn(pigeons, 2L, simplify = FALSE)) {
      clauses <- c(clauses, list(c(-v(pair[1], j), -v(pair[2], j))))
    }
  }
  clauses
}

# What a text-mode stream on Windows would do to those bytes.
simulate_crlf_translation <- function(bytes) {
  out <- raw()
  for (b in bytes) {
    out <- c(out, if (b == as.raw(0x0a)) as.raw(c(0x0d, 0x0a)) else b)
  }
  out
}
