#' Create tables in LaTeX, HTML, Markdown and reStructuredText
#'
#' This is a very simple table generator. It is simple by design. It is not
#' intended to replace any other R packages for making tables.
#' @param x an R object (typically a matrix or data frame)
#' @param format a character string; possible values are \code{latex},
#'   \code{html}, \code{markdown}, \code{pandoc}, and \code{rst}; this will be
#'   automatically determined if the function is called within \pkg{knitr}; it
#'   can also be set in the global option \code{knitr.table.format}
#' @param digits the maximum number of digits for numeric columns (passed to
#'   \code{round()}); it can also be a vector of length \code{ncol(x)} to set
#'   the number of digits for individual columns
#' @param row.names a logical value indicating whether to include row names; by
#'   default, row names are included if \code{rownames(x)} is neither
#'   \code{NULL} nor identical to \code{1:nrow(x)}
#' @param col.names a character vector of column names to be used in the table
#' @param align the alignment of columns: a character vector consisting of
#'   \code{'l'} (left), \code{'c'} (center) and/or \code{'r'} (right); by
#'   default, numeric columns are right-aligned, and other columns are
#'   left-aligned; if \code{align = NULL}, the default alignment is used
#' @param caption the table caption
#' @param escape escape special characters when producing HTML or LaTeX tables
#' @param ... other arguments (see examples)
#' @return A character vector of the table source code.
#' @seealso Other R packages such as \pkg{xtable} and \pkg{tables} for HTML and
#'   LaTeX tables, and \pkg{ascii} and \pkg{pander} for different flavors of
#'   markdown output and some advanced features and table styles.
#' @note The tables for \code{format = 'markdown'} also work for Pandoc when the
#'   \code{pipe_tables} extension is enabled (this is the default behavior for
#'   Pandoc >= 1.10).
#'
#'   When using \code{kable()} as a \emph{top-level} expression, you do not need
#'   to explicitly \code{print()} it due to R's automatic implicit printing.
#'   When it is wrapped inside other expressions (such as a \code{\link{for}}
#'   loop), you must explicitly \code{print(kable(...))}.
#' @references See
#'   \url{https://github.com/yihui/knitr-examples/blob/master/091-knitr-table.Rnw}
#'    for some examples in LaTeX, but they also apply to other document formats.
#' @export
#' @examples  kable(head(iris), format = 'latex')
#' kable(head(iris), format = 'html')
#' kable(head(iris), format = 'latex', caption = 'Title of the table')
#' kable(head(iris), format = 'html', caption = 'Title of the table')
#' # use the booktabs package
#' kable(mtcars, format = 'latex', booktabs = TRUE)
#' # use the longtable package
#' kable(matrix(1000, ncol=5), format = 'latex', digits = 2, longtable = TRUE)
#' # add some table attributes
#' kable(head(iris), format = 'html', table.attr = 'id="mytable"')
#' # reST output
#' kable(head(mtcars), format = 'rst')
#' # no row names
#' kable(head(mtcars), format = 'rst', row.names = FALSE)
#' # R Markdown/Github Markdown tables
#' kable(head(mtcars[, 1:5]), format = 'markdown')
#' # no inner padding
#' kable(head(mtcars), format = 'markdown', padding = 0)
#' # more padding
#' kable(head(mtcars), format = 'markdown', padding = 2)
#' # Pandoc tables
#' kable(head(mtcars), format = 'pandoc', caption = 'Title of the table')
#' # save the value
#' x = kable(mtcars, format = 'html')
#' cat(x, sep = '\n')
#' # can also set options(knitr.table.format = 'html') so that the output is HTML
kable = function(
  x, format, digits = getOption('digits'), row.names = NA, col.names = colnames(x),
  align, caption = NULL, escape = TRUE, ...
) {
  if (missing(format) || is.null(format)) format = getOption('knitr.table.format')
  if (is.null(format)) format = if (is.null(pandoc_to())) switch(
    out_format() %n% 'markdown',
    latex = 'latex', listings = 'latex', sweave = 'latex',
    html = 'html', markdown = 'markdown', rst = 'rst',
    stop('table format not implemented yet!')
  ) else 'pandoc'
  col.names # evaluate it now! no lazy evaluation because colnames(x) may change
  if (!is.matrix(x)) x = as.data.frame(x)
  m = ncol(x)
  # numeric columns
  isn = if (is.matrix(x)) rep(is.numeric(x), m) else sapply(x, is.numeric)
  if (missing(align) || (format == 'latex' && is.null(align)))
    align = ifelse(isn, 'r', 'l')
  # rounding
  digits = rep(digits, length.out = m)
  for (j in seq_len(m)) {
    if (is.numeric(x[, j])) x[, j] = round(x[, j], digits[j])
  }
  if (any(isn)) {
    if (is.matrix(x)) {
      if (is.table(x) && length(dim(x)) == 2) class(x) = 'matrix'
      x = format_matrix(x)
    } else x[, isn] = format(x[, isn], trim = TRUE)
  }
  if (is.na(row.names))
    row.names = !is.null(rownames(x)) && !identical(rownames(x), as.character(seq_len(NROW(x))))
  if (!is.null(align)) align = rep(align, length.out = m)
  if (row.names) {
    x = cbind(' ' = rownames(x), x)
    if (!is.null(col.names)) col.names = c(' ', col.names)
    if (!is.null(align)) align = c('l', align)  # left align row names
  }
  n = nrow(x)
  x = format(as.matrix(x), trim = TRUE, justify = 'none')
  if (!is.matrix(x)) x = matrix(x, nrow = n)
  x = gsub('^\\s*|\\s*$', '', x)
  colnames(x) = col.names
  attr(x, 'align') = align
  res = do.call(
    paste('kable', format, sep = '_'),
    list(x = x, caption = caption, escape = escape, ...)
  )
  structure(res, format = format, class = 'knitr_kable')
}

# as.data.frame() does not allow duplicate row names (#898)
format_matrix = function(x) {
  nms = rownames(x)
  rownames(x) = NULL
  x = as.matrix(format(as.data.frame(x), trim = TRUE))
  rownames(x) = nms
  x
}

#' @export
print.knitr_kable = function(x, ...) {
  if (!(attr(x, 'format') %in% c('html', 'latex'))) cat('\n\n')
  cat(x, sep = '\n')
}

#' @export
knit_print.knitr_kable = function(x, ...) {
  x = paste(c(
    if (!(attr(x, 'format') %in% c('html', 'latex'))) c('', ''), x, '\n'
  ), collapse = '\n')
  asis_output(x)
}

kable_latex = function(
  x, booktabs = FALSE, longtable = FALSE,
  vline = getOption('knitr.table.vline', if (booktabs) '' else '|'),
  toprule = getOption('knitr.table.toprule', if (booktabs) '\\toprule' else '\\hline'),
  bottomrule = getOption('knitr.table.bottomrule', if (booktabs) '\\bottomrule' else '\\hline'),
  midrule = getOption('knitr.table.midrule', if (booktabs) '\\midrule' else '\\hline'),
  linesep = if (booktabs) c('', '', '', '', '\\addlinespace') else '\\hline',
  caption = NULL, table.envir = if (!is.null(caption)) 'table', escape = TRUE
) {
  if (!is.null(align <- attr(x, 'align', exact = TRUE))) {
    align = paste(align, collapse = vline)
    align = paste('{', align, '}', sep = '')
  }
  env1 = sprintf('\\begin{%s}\n', table.envir)
  env2 = sprintf('\n\\end{%s}',   table.envir)
  cap = if (is.null(caption)) '' else sprintf('\n\\caption{%s}', caption)

  if (nrow(x) == 0) midrule = ""

  linesep = if (nrow(x) > 1) {
    c(rep(linesep, length.out = nrow(x) - 2), linesep[[1L]], '')
  } else rep('', nrow(x))
  linesep = ifelse(linesep == "", linesep, paste('\n', linesep, sep = ''))

  if (escape) x = escape_latex(x)
  if (!is.character(toprule)) toprule = NULL
  if (!is.character(bottomrule)) bottomrule = NULL

  paste(c(
    env1,
    cap,
    sprintf('\n\\begin{%s}', if (longtable) 'longtable' else 'tabular'), align,
    sprintf('\n%s', toprule), '\n',
    if (!is.null(cn <- colnames(x))) {
      if (escape) cn = escape_latex(cn)
      paste(paste(cn, collapse = ' & '), sprintf('\\\\\n%s\n', midrule), sep = '')
    },
    paste(apply(x, 1, paste, collapse = ' & '), sprintf('\\\\%s', linesep),
          sep = '', collapse = '\n'),
    sprintf('\n%s', bottomrule),
    sprintf('\n\\end{%s}', if (longtable) 'longtable' else 'tabular'),
    env2
  ), collapse = '')
}

kable_html = function(x, table.attr = '', caption = NULL, escape = TRUE, ...) {
  table.attr = gsub('^\\s+|\\s+$', '', table.attr)
  # need a space between <table and attributes
  if (nzchar(table.attr)) table.attr = paste('', table.attr)
  align = if (is.null(align <- attr(x, 'align', exact = TRUE))) '' else {
    sprintf(' style="text-align:%s;"', c(l = 'left', c = 'center', r = 'right')[align])
  }
  cap = if (is.null(caption)) '' else sprintf('\n<caption>%s</caption>', caption)
  if (escape) x = escape_html(x)
  paste(c(
    sprintf('<table%s>%s', table.attr, cap),
    if (!is.null(cn <- colnames(x))) {
      if (escape) cn = escape_html(cn)
      c(' <thead>', '  <tr>', sprintf('   <th%s> %s </th>', align, cn), '  </tr>', ' </thead>')
    },
    '<tbody>',
    paste(
      '  <tr>',
      apply(x, 1, function(z) paste(sprintf('   <td%s> %s </td>', align, z), collapse = '\n')),
      '  </tr>', sep = '\n'
    ),
    '</tbody>',
    '</table>'
  ), sep = '', collapse = '\n')
}

#' Generate tables for Markdown and reST
#'
#' This function provides the basis for Markdown and reST tables.
#' @param x the data matrix
#' @param sep.row a chracter vector of length 3 that specifies the separators
#'   before the header, after the header and at the end of the table,
#'   respectively
#' @param sep.col the column separator
#' @param padding the number of spaces for the table cell padding
#' @param align.fun a function to process the separator under the header
#'   according to alignment
#' @return A character vector of the table content.
#' @noRd
kable_mark = function(x, sep.row = c('=', '=', '='), sep.col = '  ', padding = 0,
                      align.fun = function(s, a) s, rownames.name = '', ...) {
  # when the column separator is |, replace existing | with its HTML entity
  if (sep.col == '|') for (j in seq_len(ncol(x))) {
    x[, j] = gsub('\\|', '&#124;', x[, j])
  }
  l = if (prod(dim(x)) > 0) apply(x, 2, function(z) max(nchar(z, type = 'width'), na.rm = TRUE))
  cn = colnames(x)
  if (length(cn) > 0) {
    cn[is.na(cn)] = "NA"
    if (sep.col == '|') cn = gsub('\\|', '&#124;', cn)
    if (grepl('^\\s*$', cn[1L])) cn[1L] = rownames.name  # no empty cells for reST
    l = pmax(if (length(l) == 0) 0 else l, nchar(cn, type = 'width'))
  }
  align = attr(x, 'align', exact = TRUE)
  padding = padding * if (length(align) == 0) 2 else {
    ifelse(align == 'c', 2, 1)
  }
  l = pmax(l + padding, 3)  # at least of width 3 for Github Markdown
  s = unlist(lapply(l, function(i) paste(rep(sep.row[2], i), collapse = '')))
  res = rbind(if (!is.na(sep.row[1])) s, cn, align.fun(s, align),
              x, if (!is.na(sep.row[3])) s)
  apply(mat_pad(res, l, align), 1, paste, collapse = sep.col)
}

kable_rst = function(x, rownames.name = '\\', ...) {
  kable_mark(x, rownames.name = rownames.name)
}

# actually R Markdown
kable_markdown = function(x, padding = 1, ...) {
  if (is.null(colnames(x))) stop('the table must have a header (column names)')
  res = kable_mark(x, c(NA, '-', NA), '|', padding, align.fun = function(s, a) {
    if (is.null(a)) return(s)
    r = c(l = '^.', c = '^.|.$', r = '.$')
    for (i in seq_along(s)) {
      s[i] = gsub(r[a[i]], ':', s[i])
    }
    s
  }, ...)
  sprintf('|%s|', res)
}

kable_pandoc = function(x, caption = NULL, padding = 1, ...) {
  tab = kable_mark(x, c(NA, '-', if (is.null(colnames(x))) '-' else NA),
                   padding = padding, ...)
  if (is.null(caption)) tab else c(paste('Table:', caption), "", tab)
}

# pad a matrix
mat_pad = function(m, width, align = NULL) {
  n = nrow(m); p = ncol(m)
  res = matrix('', nrow = n, ncol = p)
  if (n * p == 0) return(res)
  stopifnot(p == length(width))
  side = rep('both', p)
  if (!is.null(align)) side = c(l = 'right', c = 'both', r = 'left')[align]
  apply(m, 2, function(x) max(nchar(x, 'width') - nchar(x, 'chars')))
  matrix(pad_width(c(m), rep(width, each = n), rep(side, each = n)), ncol = p)
}

# pad a character vector to width (instead of number of chars), considering the
# case of width > chars (e.g. CJK chars)
pad_width = function(x, width, side) {
  if (!all(side %in% c('left', 'right', 'both')))
    stop("'side' must be 'left', 'right', or 'both'")
  w = width - nchar(x, 'width')
  w1 = floor(w / 2)  # the left half of spaces when side = 'both'
  s1 = v_spaces(w * (side == 'left') + w1 * (side == 'both'))
  s2 = v_spaces(w * (side == 'right') + (w - w1) * (side == 'both'))
  paste(s1, x, s2, sep = '')
}

# vectorized over n to generate sequences of spaces
v_spaces = function(n) {
  unlist(lapply(n, highr:::spaces))
}
