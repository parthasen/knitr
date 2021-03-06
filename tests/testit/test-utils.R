library(testit)

assert(
  'abs_path() recognizes absolute paths under Windows and *nix',
  !is_abs_path('abc/def'),
  is_abs_path(if (.Platform$OS.type == 'windows') {
    c('D:\\abc', '\\\\netdrive\\somewhere')
  } else '/abc/def')
)

op = options(digits = 4, scipen = 0)

assert(
  'format_sci() turns numbers into scientific notations',
  identical(format_sci(1), '1'),
  identical(format_sci(0), '0'),
  identical(format_sci(c(1.84e8, 1e5, 2.34e3)),
            c('1.84\\times 10^{8}', '10^{5}', '2340')),
  identical(format_sci(1.23456789 * 10^-5), '1.2346\\times 10^{-5}'),
  identical(format_sci(9.87654e6, 'html'), '9.8765 &times; 10<sup>6</sup>'),
  identical(format_sci(9.87654e6, 'rst'), '9.8765 |times| 10 :sup:`6`'),
  identical(format_sci(letters), letters),
  identical(format_sci(NA_real_), NA_character_)
)

assert(
  'format_sci() coerces non-numeric and non-double values to characters',
  format_sci(Sys.Date()) == as.character(Sys.Date()),
  format_sci(1000000L) == '1000000'
)

assert(
  'format_sci() for Rnw does not add \\ensuremath{} at all',
  !grepl('[\\]ensuremath', format_sci(c(1e4, 1.2345e10, 2 * pnorm(-(3:4)), -Inf)))
)

assert(
  'the inline hook for Rnw applies \\ensuremath{} correctly',
  .inline.hook.tex(1e4) == '\\ensuremath{10^{4}}',
  .inline.hook.tex(-Inf) == '\\ensuremath{-\\infty{}}',
  .inline.hook.tex(c(1.2345e10, 2 * pnorm(-(3:4)))) ==
    "\\ensuremath{1.2345\\times 10^{10}}, 0.0027, \\ensuremath{6.3342\\times 10^{-5}}"
)

assert(
  'Infinity and NaN are formatted correctly',
  identical(format_sci(-Inf), '-\\infty{}'),
  identical(format_sci(-Inf, 'html'), '-&infin;'),
  identical(format_sci(-Inf, 'rst'), '-Inf'),
  identical(format_sci(NaN), 'NaN')
)

assert(
  'sanitize_fn() warns against spaces in filenames',
  has_warning(sanitize_fn('figure/a b'))
)

options(op)

assert(
  'fig_path() sanitizes paths',
  identical(sanitize_fn('fig/foo', '.png'), 'fig/foo.png'),
  suppressWarnings(c(
    identical(sanitize_fn('figure/a b'), 'figure/a_b'),
    identical(sanitize_fn('fig space/a.b'), 'fig_space/a_b'),
    identical(sanitize_fn('../c.d'), '../c_d'),
    identical(sanitize_fn('./../c..d'), './../c__d')
  )),
  identical(sanitize_fn('C:/foo/bar'), 'C:/foo/bar')
)

assert(
  'fig_chunk() generates figure filenames for a code chunk',
  identical(fig_chunk('foo'), 'figure/foo-1'),
  identical(fig_chunk('foo', 'pdf'), 'figure/foo-1.pdf'),
  identical(fig_chunk('foo', 'png', 2), 'figure/foo-2.png'),
  identical(fig_chunk('foo', 'svg', 1:5), sprintf('figure/foo-%d.svg', 1:5)),
  identical(fig_chunk('foo', fig.path = 'my_figure/'), 'my_figure/foo-1'),
  identical(fig_chunk('foo', '.pdf'), 'figure/foo-1.pdf')
)

f = file.path(R.home('doc'), 'html', 'logo.jpg')
assert(
  'base64_encode() gets the same result as markdown:::.b64EncodeFile',
  identical(strsplit(markdown:::.b64EncodeFile(f), 'base64,')[[1]][2],
            base64_encode(readBin(f, what = 'raw', n = file.info(f)$size)))
)

assert(
  'escape_latex() escapes special LaTeX characters',
  identical(escape_latex('# $ % & ~ _ ^ \\ { }'),
            '\\# \\$ \\% \\& \\textasciitilde{} \\_ \\textasciicircum{} \\textbackslash{} \\{ \\}')
)

assert(
  'indent_block() works when the first element is empty (#790)',
  identical(indent_block(c('', 'a')), c('    ', '    a')),
  identical(indent_block(c('', '')),  c('    ', '    '))
)

assert(
  'current_input() returns NULL by default',
  is.null(current_input()), suppressWarnings(is.null(current_input(TRUE)))
)
