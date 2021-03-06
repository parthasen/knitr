#' Package vignette engines
#'
#' Since R 3.0.0, package vignettes can use non-Sweave engines, and \pkg{knitr}
#' has provided a few engines to compile vignettes via \code{\link{knit}()} with
#' different templates. See \url{http://yihui.name/knitr/demo/vignette/} for
#' more information.
#' @name vignette_engines
#' @note If you use the \code{knitr::rmarkdown} engine, please make sure that
#'   you put \pkg{rmarkdown} in the \samp{Suggests} field of your
#'   \file{DESCRIPTION} file. Also make sure the executables \command{pandoc}
#'   and \command{pandoc-citeproc} can be found by \pkg{rmarkdown} during
#'   \command{R CMD build}. If you build your package from RStudio, this is
#'   normally not a problem. If you build the package outside RStudio, run
#'   \command{which pandoc} and \command{which pandoc-citeproc} in the terminal
#'   (or \code{Sys.which('pandoc')} and \code{Sys.which('pandoc-citeproc')} in
#'   R) to check if \command{pandoc} and \command{pandoc-citeproc} can be found.
#'   If you use Linux, you may make symlinks to the Pandoc binaries in RStudio:
#'   \url{https://github.com/rstudio/rmarkdown/blob/master/PANDOC.md}, or
#'   install \command{pandoc} and \command{pandoc-citeproc} separately.
#'
#'   When the \pkg{rmarkdown} package is not installed or not available, or
#'   \command{pandoc} or \command{pandoc-citeproc} cannot be found, the
#'   \code{knitr::rmarkdown} engine will fall back to the \code{knitr::knitr}
#'   engine, which uses R Markdown v1 based on the \pkg{markdown} package.
#' @examples library(knitr)
#' vig_list = tools::vignetteEngine(package = 'knitr')
#' str(vig_list)
#' vig_list[['knitr::knitr']][c('weave', 'tangle')]
#' vig_list[['knitr::knitr_notangle']][c('weave', 'tangle')]
#' vig_list[['knitr::docco_classic']][c('weave', 'tangle')]
NULL

vweave = vtangle = function(file, driver, syntax, encoding = 'UTF-8', quiet = FALSE, ...) {
  opts_chunk$set(error = FALSE)  # should not hide errors
  knit_hooks$set(purl = hook_purl)  # write out code while weaving
  options(markdown.HTML.header = NULL)
  (if (grepl('\\.[Rr]md$', file)) knit2html else if (grepl('\\.[Rr]rst$', file)) knit2pdf else knit)(
    file, encoding = encoding, quiet = quiet, envir = globalenv()
  )
}

body(vtangle)[5L] = expression(purl(file, encoding = encoding, quiet = quiet))

vweave_docco_linear = vweave
body(vweave_docco_linear)[5L] = expression(knit2html(
  file, encoding = encoding, quiet = quiet, envir = globalenv(),
  template = system.file('misc', 'docco-template.html', package = 'knitr')
))

vweave_docco_classic = vweave
body(vweave_docco_classic)[5L] = expression(rocco(
  file, encoding = encoding, quiet = quiet, envir = globalenv()
))

vweave_rmarkdown = vweave
body(vweave_rmarkdown)[5L] = expression(rmarkdown::render(
  file, encoding = encoding, quiet = quiet, envir = globalenv()
))

# do not tangle R code from vignettes
untangle_weave = function(vig_list, eng) {
  weave = vig_list[[c(eng, 'weave')]]
  if (eng != 'knitr::rmarkdown')
    body(weave)[3L] = expression({})
  weave
}
vtangle_empty = function(file, ...) {
  unlink(sub_ext(file, 'R'))
  return()
}

register_vignette_engines = function(pkg) {
  # the default engine
  vig_engine('knitr', vweave, '[.]([rRsS](nw|tex)|[Rr](md|html|rst))$')
  vig_engine('docco_linear', vweave_docco_linear, '[.][Rr](md|markdown)$')
  vig_engine('docco_classic', vweave_docco_classic, '[.][Rr]mk?d$')
  vig_engine('rmarkdown', function(...) if (has_package('rmarkdown')) {
    if (pandoc_available()) {
      vweave_rmarkdown(...)
    } else {
      if (!is_R_CMD_check())
        warning('Pandoc (>= 1.12.3) and/or pandoc-citeproc is not available. Please install both.')
      vweave(...)
    }
  } else {
    warning('The vignette engine knitr::rmarkdown is not available, ',
            'because the rmarkdown package is not installed. Please install it.')
    vweave(...)
  }, '[.][Rr](md|markdown)$')
  # vignette engines that disable tangle
  vig_list = tools::vignetteEngine(package = 'knitr')
  engines  = grep('_notangle$', names(vig_list), value = TRUE, invert = TRUE)
  for (eng in engines) vig_engine(
    paste(sub('^knitr::', '', eng), 'notangle', sep = '_'),
    untangle_weave(vig_list, eng),
    tangle = vtangle_empty,
    pattern = vig_list[[c(eng, 'pattern')]]
  )
}
# all engines use the same tangle and package arguments, so factor them out
vig_engine = function(..., tangle = vtangle) {
  vig_engine0(..., tangle = tangle, package = 'knitr', aspell = list(
    filter = knit_filter
  ))
}
# R <= 3.0.2 does not have the aspell argument in vignetteEngine()
vig_engine0 = if ('aspell' %in% names(formals(tools::vignetteEngine))) {
  function(...) tools::vignetteEngine(...)
} else {
  function(..., aspell = list()) tools::vignetteEngine(...)
}

#' Spell check filter for source documents
#'
#' When performing spell checking on source documents, we may need to skip R
#' code chunks and inline R expressions, because many R functions and symbols
#' are likely to be identified as typos. This function is designed for the
#' \code{filter} argument of \code{\link{aspell}()} to filter out code chunks
#' and inline expressions.
#' @param ifile the filename of the source document
#' @param encoding the file encoding
#' @return A chracter vector of the file content, excluding code chunks and
#'   inline expressions.
#' @export
#' @examples library(knitr)
#' knitr_example = function(...) system.file('examples', ..., package = 'knitr')
#' \donttest{
#' if (Sys.which('aspell') != '') {
#' # -t means the TeX mode
#' utils::aspell(knitr_example('knitr-minimal.Rnw'), knit_filter, control = '-t')
#'
#' # -H is the HTML mode
#' utils::aspell(knitr_example('knitr-minimal.Rmd'), knit_filter, control = '-H -t')
#' }}
knit_filter = function(ifile, encoding = 'unknown') {
  x = readLines(ifile, encoding = encoding, warn = FALSE)
  n = length(x); if (n == 0) return(x)
  p = detect_pattern(x, tolower(file_ext(ifile)))
  if (is.null(p)) return(x)
  p = all_patterns[[p]]; p1 = p$chunk.begin; p2 = p$chunk.end
  i1 = grepl(p1, x)
  i2 = filter_chunk_end(i1, grepl(p2, x))
  m = numeric(n)
  m[i1] = 1; m[i2] = 2  # 1: code; 2: text
  if (m[1] == 0) m[1] = 2
  for (i in seq_len(n - 1)) if (m[i + 1] == 0) m[i + 1] = m[i]
  x[m == 1 | i2] = ''
  x[m == 2] = gsub(p$inline.code, '', x[m == 2])
  structure(x, control = '-H -t')
}

pandoc_available = function() {
  # if you have this environment variable, chances are you are good to go
  if (Sys.getenv("RSTUDIO_PANDOC") != '') return(TRUE)
  if (Sys.which('pandoc-citeproc') == '') return(FALSE)
  rmarkdown::pandoc_available('1.12.3')
}

html_vignette = function(
  ..., fig_caption = TRUE, theme = NULL, highlight = "pygments",
  css = system.file('misc', 'vignette.css', package = 'knitr'),
  includes = list(
    after_body = system.file('misc', 'vignette.html', package = 'knitr')
  )
) {
  rmarkdown::html_document(
    ..., fig_caption = fig_caption, theme = theme, highlight = highlight,
    css = css, includes = includes
  )
}
