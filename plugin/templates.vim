""" Very Simple Templates
"
" Read a template file and replace tags in it.
" Templates tag can be specified in the following dictionaries:
"  - s:default_tags
"  - g:vstpl_tags
"  - b:vstpl_tags
"
" Keys are tag names, values are replacement expressions.
" 
" Example:
"   let g:vstpl_tags = { 'tpl:file': 'expand("%")' }
"   will replace $tpl:file$ with current filename.
"
" g:default_tags is filled width default values, set
" g:vstpl_default to 0 if you don't want to use them.
" if not defined previously (e.g. in .vimrc).
"
" TODO how to include in ftplugin
" TODO change/complete default tags


if exists('g:loaded_vstpl')
  finish
endif
let g:loaded_vstpl=1

if !exists('g:vstpl_default')
  let g:vstpl_default=1
endif


let s:save_cpo = &cpo
set cpo&vim

" Default template tags
let s:default_tags = {
      \ 'template:filename': 'expand("%:t")',
      \ 'template:name': 'expand("%:t:r")',
      \}

"Because not all systems support strftime
if exists("*strftime")
  let s:template_var["template:date"] = 'strftime("%d\/%m\/%Y")'
endif


" Replace template tags found
fun! Templates_Replace()
  tags = {}
  if !exists(g:vstpl_tags) || g:vstpl_tags!=0
    call extend(tags, s:default_tags)
  if exists(g:vstpl_tags)
    call extend(tags, g:vstpl_tags)
  endif
  if exists(b:vstpl_tags)
    call extend(tags, b:vstpl_tags)
  endif

  let reg_bak = @/
  for [k,v] in items(tags)
    silent exe '%s/\$'.k.'\$/\='.v.'/g'
  endfor
  let @/ = reg_bak
endfun


" Use a given template if current file is not readable (new file)
fun! Template_ifnew(ftpl)
  if filereadable(expand("%")) | return | endif
  exe "0r ".a:ftpl
  call Template_Replace_Special()
endif


let &cpo = s:save_cpo

