" TODO Use variables, not hardcoded filenames
" TODO need massive clean up

" Replace template variables
" TODO preserve @/, and ~ value
fun! Template_Replace_Special()
  for [k,v] in items(s:template_var)
    exe '%s/\$'.k.'\$/\='.v.'/g'
  endfor
endfun

"name for the template, the function Template_Replace_Special()
"replace $template:filename$ by the filname (for exemple)
let s:template_var = {
      \ 'template:filename': 'expand("%:t")',
      \ 'template:name': 'expand("%:t:r")',
      \}

"Because not all systems support strftime
if exists("*strftime")
  let s:template_var["template:date"] = 'strftime("%d\/%m\/%Y")'
endif


" TODO put it in ftplugin (not plugin)
if !filereadable(expand("%")) 
  "Template loading
  0r ~/.templates/vhdl
  "Filling template replace $template:date$ and $template:filename$

  call Template_Replace_Special()
endif


