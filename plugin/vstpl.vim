" Very Simple Templates plugin
"
" Description: Read a template file and replace tags in it.
" Author: Benoît Ryder (benoit@ryder.fr)
"
" Usage:
"   Template tags are sought in the following (dictionary) variables:
"    - s:default_tags
"    - g:vstpl_tags
"    - b:vstpl_tags
"
"   Keys are tag names, values are replacement expressions.
"
" Example:
"   let g:vstpl_tags = { 'tpl:filename': 'expand("%:t")' }
"   will replace $tpl:file$ with buffer basename.
"
" Configuration:
"  - g:vstpl_default = 0
"      do not use g:default_tags tags
"
" Functions:
"  - VSTpl_replace() : replace tags in current buffer.
"  - VSTpl_ifnew(ftpl) : load template ftpl if current buffer is a non
"      new file (not readable) and replace tags.
"   
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
      \ 'tpl:filename': 'expand("%:t")',
      \ 'tpl:name':     'expand("%:t:r")',
      \}

"Because not all systems support strftime
if exists("*strftime")
  let s:default_tags["template:date"] = 'strftime("%d\/%m\/%Y")'
endif


" Replace template tags found
fun! VSTpl_replace()
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
fun! VSTpl_ifnew(ftpl)
  if filereadable(expand("%")) | return | endif
  exe "0r ".a:ftpl
  call VSTpl_replace()
endif


let &cpo = s:save_cpo

