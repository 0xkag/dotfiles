" Vim syntax file
" Language: Terraform template (.tftpl)

if exists('b:current_syntax')
  finish
endif

" Interpolation: ${ ... }
syn region tftplInterp matchgroup=tftplInterpDelim start=/\${/ end=/}/ contains=tftplExpr

" Directive: %{ ... } and %{ ... ~}
syn region tftplDirective matchgroup=tftplDirectiveDelim start=/%{\s*\~\=/ end=/\~\=\s*}/ contains=tftplKeyword,tftplExpr

" Strip markers
syn match tftplStrip /\~/ contained containedin=tftplDirective,tftplInterp

" Keywords inside directives
syn keyword tftplKeyword contained for in if else endif endfor

" Expressions inside interpolations and directives
syn match tftplExpr /[^}]\+/ contained contains=tftplOperator,tftplFunction,tftplNumber,tftplString,tftplBool,tftplNull,tftplDot
syn match tftplOperator /[!=<>]=\|&&\|||\|[+\-*/%<>!]/ contained
syn match tftplFunction /[a-z_][a-z0-9_]*\ze\s*(/ contained
syn match tftplNumber /\<[0-9]\+\(\.[0-9]\+\)\=\>/ contained
syn match tftplDot /\./ contained
syn keyword tftplBool contained true false
syn keyword tftplNull contained null

" Strings inside expressions
syn region tftplString start=/"/ skip=/\\\\\|\\"/ end=/"/ contained

hi def link tftplInterpDelim Special
hi def link tftplDirectiveDelim PreProc
hi def link tftplStrip Special
hi def link tftplKeyword Keyword
hi def link tftplOperator Operator
hi def link tftplFunction Function
hi def link tftplNumber Number
hi def link tftplString String
hi def link tftplBool Boolean
hi def link tftplNull Constant
hi def link tftplDot Operator

let b:current_syntax = 'tftpl'
