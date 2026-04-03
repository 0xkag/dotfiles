" Cyberpunk color scheme for Vim >= 9.x
" Ported from cyberpunk-theme.el by Nicholas M. Van Horn
" https://github.com/n3mo/cyberpunk-theme.el
"
" "and he'd still see the matrix in his sleep, bright lattices of logic
" unfolding across that colorless void..."
" William Gibson, Neuromancer.

vim9script

hi clear
if exists('syntax_on')
  syntax reset
endif

g:colors_name = 'cyberpunk'
set background=dark

# Enable true color when the terminal supports it
if has('termguicolors') && ($COLORTERM == 'truecolor' || $COLORTERM == '24bit' || has('gui_running'))
  &termguicolors = true
endif

# Helper: gui=X also sets cterm=X; fg/bg set both gui and cterm variants
#   cterm256 values are closest xterm-256 approximations of the hex colors
def Hi(group: string, fg: string = '', bg: string = '', attr: string = '')
  var parts: list<string>
  if !empty(fg)
    parts->add($'guifg={fg} ctermfg={Ct(fg)}')
  endif
  if !empty(bg)
    parts->add($'guibg={bg} ctermbg={Ct(bg)}')
  endif
  if !empty(attr)
    parts->add($'gui={attr} cterm={attr}')
  endif
  if empty(parts)
    return
  endif
  exe 'hi ' .. group .. ' ' .. join(parts)
enddef

# Map hex color to nearest xterm-256 index
def Ct(hex: string): string
  if hex == 'NONE'
    return 'NONE'
  endif
  const map: dict<string> = {
    '#dcdccc': '188',
    '#000000': '16',
    '#2b2b2b': '235',
    '#383838': '237',
    '#4f4f4f': '239',
    '#5f5f5f': '59',
    '#6f6f6f': '242',
    '#dca3a3': '174',
    '#ff0000': '196',
    '#8b0000': '88',
    '#9c6363': '131',
    '#7F073F': '89',
    '#ff69b4': '205',
    '#ff1493': '199',
    '#cd1076': '162',
    '#FF6400': '202',
    '#ff8c00': '208',
    '#ffa500': '214',
    '#ffff00': '226',
    '#FBDE2D': '220',
    '#d0bf8f': '180',
    '#E9C062': '179',
    '#ffd700': '220',
    '#006400': '22',
    '#2e8b57': '29',
    '#00ff00': '46',
    '#61CE3C': '77',
    '#9fc59f': '151',
    '#afd8af': '151',
    '#bfebbf': '157',
    '#93e0e3': '116',
    '#94bff3': '111',
    '#0000ff': '21',
    '#7b68ee': '99',
    '#6a5acd': '98',
    '#add8e6': '152',
    '#b2dfee': '153',
    '#4c83ff': '69',
    '#96CBFE': '117',
    '#00ffff': '51',
    '#4F94CD': '68',
    '#dc8cc3': '176',
    '#d3d3d3': '252',
    '#8B8989': '245',
    '#919191': '246',
    '#333333': '236',
    '#1A1A1A': '234',
    '#4D4D4D': '239',
    '#262626': '235',
    '#ffffff': '231',
    '#F8F8F8': '231',
  }
  return get(map, hex, 'NONE')
enddef

# --- Core UI ---
Hi('Normal',       '#d3d3d3', '#000000')
Hi('Cursor',       '#000000', '#dcdccc')
Hi('CursorLine',   '',        '#333333', 'NONE')
Hi('CursorColumn', '',        '#333333')
Hi('ColorColumn',  '',        '#383838')
Hi('LineNr',       '#9fc59f', '#000000')
Hi('CursorLineNr', '#ffffff', '#000000', 'bold')
Hi('SignColumn',   '#dcdccc', '#2b2b2b')
Hi('FoldColumn',   '#dcdccc', '#2b2b2b')
Hi('Folded',       '#8B8989', '#2b2b2b')
Hi('VertSplit',    '#333333', '#000000')
Hi('WinSeparator', '#333333', '#000000')

# --- Status line ---
Hi('StatusLine',   '#4c83ff', '#333333', 'NONE')
Hi('StatusLineNC', '#4D4D4D', '#1A1A1A', 'NONE')
Hi('TabLine',      '#4D4D4D', '#1A1A1A')
Hi('TabLineFill',  '',        '#1A1A1A')
Hi('TabLineSel',   '#4c83ff', '#333333', 'bold')

# --- Popup menu ---
Hi('Pmenu',        '#ffff00', '#8B8989')
Hi('PmenuSel',     '#000000', '#ff1493')
Hi('PmenuSbar',    '',        '#333333')
Hi('PmenuThumb',   '',        '#000000')

# --- Search & selection ---
Hi('Visual',       '',        '#7F073F')
Hi('VisualNOS',    '',        '#7F073F')
Hi('Search',       '#000000', '#ffff00')
Hi('IncSearch',    '#000000', '#ff1493')
Hi('CurSearch',    '#000000', '#ff1493', 'bold')
Hi('Substitute',   '#000000', '#ff1493')

# --- Messages ---
Hi('ErrorMsg',     '#ff0000', '#000000', 'bold')
Hi('WarningMsg',   '#ff69b4', '#000000')
Hi('MoreMsg',      '#61CE3C', '#000000')
Hi('ModeMsg',      '#4c83ff', '',        'bold')
Hi('Question',     '#61CE3C', '#000000')
Hi('Title',        '#ff1493', '',        'bold')

# --- Diff ---
Hi('DiffAdd',      '#00ff00', 'NONE')
Hi('DiffChange',   '#ffff00', 'NONE')
Hi('DiffDelete',   '#ff0000', 'NONE')
Hi('DiffText',     '#ffff00', '#4f4f4f', 'bold')

# --- Spelling ---
hi SpellBad   guisp=#FF6400 gui=undercurl cterm=undercurl ctermfg=202
hi SpellCap   guisp=#FBDE2D gui=undercurl cterm=undercurl ctermfg=220
hi SpellRare  guisp=#7b68ee gui=undercurl cterm=undercurl ctermfg=99
hi SpellLocal guisp=#61CE3C gui=undercurl cterm=undercurl ctermfg=77

# --- Syntax ---
Hi('Comment',        '#8B8989', '',        'italic')
Hi('Constant',       '#96CBFE')
Hi('String',         '#61CE3C')
Hi('Character',      '#61CE3C')
Hi('Number',         '#96CBFE')
Hi('Boolean',        '#96CBFE')
Hi('Float',          '#96CBFE')
Hi('Identifier',     '#ff69b4', '',        'NONE')
Hi('Function',       '#ff1493')
Hi('Statement',      '#4c83ff', '',        'NONE')
Hi('Conditional',    '#4c83ff')
Hi('Repeat',         '#4c83ff')
Hi('Label',          '#4c83ff')
Hi('Operator',       '#00ffff')
Hi('Keyword',        '#4c83ff')
Hi('Exception',      '#4c83ff')
Hi('PreProc',        '#919191')
Hi('Include',        '#919191')
Hi('Define',         '#919191')
Hi('Macro',          '#919191')
Hi('PreCondit',      '#919191')
Hi('Type',           '#afd8af', '',        'NONE')
Hi('StorageClass',   '#afd8af')
Hi('Structure',      '#afd8af')
Hi('Typedef',        '#afd8af')
Hi('Special',        '#4c83ff')
Hi('SpecialChar',    '#E9C062')
Hi('Tag',            '#ff1493')
Hi('Delimiter',      '#dcdccc')
Hi('SpecialComment', '#FBDE2D')
Hi('Debug',          '#dca3a3')
Hi('Underlined',     '#ffff00', '',        'underline')
Hi('Ignore',         '#6f6f6f')
Hi('Error',          '#ff0000', '#000000', 'bold,underline')
Hi('Todo',           '#ffa500', '#000000', 'bold')

# --- Matching ---
Hi('MatchParen',   '#000000', '#ff1493')

# --- Misc UI ---
Hi('NonText',      '#4f4f4f')
Hi('SpecialKey',   '#4f4f4f')
Hi('Conceal',      '#add8e6')
Hi('Directory',    '#94bff3', '',        'bold')
Hi('WildMenu',     '#61CE3C', '#000000')

# --- Terminal colors ---
g:terminal_ansi_colors = [
  '#000000', '#8b0000', '#00ff00', '#ffa500',
  '#7b68ee', '#dc8cc3', '#93e0e3', '#dcdccc',
  '#4f4f4f', '#ff0000', '#61CE3C', '#ffff00',
  '#4c83ff', '#ff69b4', '#00ffff', '#ffffff',
]
