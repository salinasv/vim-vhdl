
if exists('g:vhdl_plugin')
  finish
endif
let g:vhdl_plugin=1


" Right align delimiter, surround it with spaces
" Cursor is moved at the end of the given range
fun! VHDL_align(delim) range

  call map(range(a:firstline,a:lastline), 'setline(v:val, substitute(getline(v:val), "\\(--.*\\)\\@<!\\s*".a:delim."\\s*", " ".a:delim." ", ""))')
  let pos = map(range(a:firstline,a:lastline), 'virtcol([v:val,stridx(getline(v:val),a:delim)+1])')
  let pos_max = max(pos)

  let i = a:firstline
  while i <= a:lastline
    if pos[i-a:firstline] > 0
      call setline(i, substitute(getline(i), '\ze'.a:delim, repeat(' ',pos_max-pos[i-a:firstline]), ''))
    endif
    let i+=1
  endwhile

  call cursor(a:lastline,0)

endfun


" Reindent and do some realignements
fun! VHDL_nice_align() range

  " Reindent
  let equalprg_bak = &l:equalprg
  exe 'norm '.(a:lastline-a:firstline+1).'=='
  let &l:equalprg = equalprg_bak

  " Signal declarations, :
  call cursor(a:firstline,0)
  while search('^\s*signal\>', 'cW', a:lastline)
    let l1 = line(".")
    if search('^\c\(\s*signal\>\)\@!', 'W', a:lastline)
      exe l1.','.line(".").'call VHDL_align(":")'
    endif
    call cursor(line('.')+1,0)
  endwhile

  " port ( ... ), :
  call cursor(a:firstline,0)
  while search('\<port\>\_s*(', 'ceW', a:lastline)
    let l1 = line(".")
    if searchpair('(','',')', 'W', '', a:lastline)
      exe l1.','.line('.').'call VHDL_align(":")'
    endif
    call cursor(line('.')+1,0)
  endwhile

  " port map ( ... ), =>
  call cursor(a:firstline,0)
  while search('\<port\_s\+map\>\_s*(', 'ceW', a:lastline)
    let l1 = line(".")
    if searchpair('(','',')', 'W', '', a:lastline)
      exe l1.','.line('.').'call VHDL_align("=>")'
    endif
    call cursor(line('.')+1,0)
  endwhile

endfun



" Omni-completion
fun! VHDL_omnicomp(findstart, base)

  "TODO vérifier qu'on utilise les tags

  if a:findstart
    unlet! b:vhdl_menu

    " locate the start of the word
    let line = getline('.')
    let start = col('.') - 1
    let compl_begin = col('.') - 2
    while start >= 0 && line[start - 1] =~ '[a-zA-Z_0-9]'
      let start -= 1
    endwhile
    let b:compl_context = getline('.')[0:start-1]
    return start
  endif

  if exists('b:vhdl_menu')
    return b:vhdl_menu
  endif

  "TODO revoir ça...
  if exists("b:compl_context")
    let context = b:compl_context
    unlet! b:compl_context
  endif

  " component
  if context =~ '\<component\>'

    let b:vhdl_menu = []
    for v in filter(taglist('^'.a:base), 'v:val.kind=="e"')
      call add(b:vhdl_menu, v.name)
    endfor
    return b:vhdl_menu

  endif

endfun



" Get port/generic of a given entity or component
" a:kind is a kind of tag : e, c, g (generic in entity)
" Return [] if nothing is found
fun! VHDL_portgeneric_get(name, kind)

  let type = a:kind == 'g' ? 'generic' : 'port'
  let kind = a:kind == 'g' ? 'e' : a:kind
  
  let l = filter(taglist('^'.a:name), 'v:val.kind==kind')
  if empty(l) | return [] | endif
  let t = l[0]

  let view_bak = winsaveview()

  " Already in the buffer, don't change
  if bufnr(t.filename) != bufnr("%")
    let bufhidden_bak = &bufhidden
    set bufhidden=hide
    let buf_bak = bufname("%")
    exe 'keepalt e '.t.filename
  endif

  sandbox silent! exe t.cmd
  
  let lines = []
  if search(type.'\_s*(', 'eW')
    let l1 = line('.')+1

    "if getline('.') =~ type.'\s*(\s*\S'
    if getline('.') =~ '(\s*\S'
      let lines = [ getline('.')[col('.'):] ]
    endif
    if searchpair('(','',')', 'W')
      let lines += getline(l1, line('.'))
    endif
  endif

  " Reload previous buffer
  if exists('buf_bak')
    exe 'keepalt b '.buf_bak
    exe 'set bufhidden='.bufhidden_bak
  endif

  call winrestview(view_bak)
  return lines

endfun


" Put component ports
" Expected to be used after typing 'port'
" Search component name in the 5 previous lines
fun! VHDL_comp_ports_put()

  let cursor_bak = getpos('.')

  if !search('\<component\s\+\k\+','b', line('.')-5)
    return
  endif

  let name = matchstr(getline('.'), '\<component\s\+\zs\k\+')
  if name == '' | return | endif

  let ports = VHDL_portgeneric_get(name, 'e')
  call setpos('.', cursor_bak)

  if empty(ports) | return | endif
  norm a (
  silent! pu=ports
  exe '.-'.(len(ports)-1).',.call VHDL_nice_align()'

  " Eat trailing char
  call getchar(0)

endfun


" Automatically create port and/or generic map
" Expected to be used after typing 'map'
" Search component name in the 5 previous lines
fun! VHDL_map_put()

  let cursor_bak = getpos('.')
  let do_generic = getline('.') !~ '\<port\>'

  if !search(':\s*\k\+','b', line('.')-5)
    return
  endif

  let name = matchstr(getline('.'), ':\s*\zs\k\+')

  if name == '' 
    call setpos('.', cursor_bak)
    return
  endif

  call setpos('.', cursor_bak)

  " Remove the "map"
  norm Xxx

  " Generic
  if do_generic

    let lines = VHDL_portgeneric_get(name, 'g')
    call setpos('.', cursor_bak)

    if !empty(lines)

      exe "norm ageneric ma\<Esc>ap ("

      call map(lines, 'substitute(v:val, "\\(--.*\\)\\@<!:[^;]*","=> ", "g")')
      call map(lines, 'substitute(v:val, "\\(--.*\\)\\@<!=> ;","=> ,", "g")')
      if lines[-1] !~ '--'
        let lines[-1] = substitute(lines[-1], '\(,\|);\)$', ')', '') "XXX
      endif
      silent! pu=lines
      norm o
      let cursor_bak2 = getpos('.')

      exe '.-'.(len(lines)).',.call VHDL_nice_align()'

      let end_move = 1

    endif
    unlet lines

  endif


  " Port
  let lines = VHDL_portgeneric_get(name, 'c')
  call setpos('.', exists('cursor_bak2') ? cursor_bak2 : cursor_bak)

  if do_generic
    " Trailing space is needed
    exe "norm apor\<Esc>at "
  endif

  if empty(lines)
    exe "norm ama\<Esc>ap ();"
  else
    exe "norm ama\<Esc>ap ("

    call map(lines, 'substitute(v:val, "\\(--.*\\)\\@<!:[^;]*","=> ", "g")')
    call map(lines, 'substitute(v:val, "\\(--.*\\)\\@<!=> ;","=> ,", "g")')
    if lines[-1] !~ '--'
      let lines[-1] = substitute(lines[-1], '\(,\|);\)$', ')', '') "XXX
    endif
    silent! pu=lines
    exe '.-'.(len(lines)).',.call VHDL_nice_align()'

    let end_move = 1
  endif

  " Go after first =>, if something has beend added
  if exists('end_move')
    call setpos('.', cursor_bak)
    call search('=> ,', 'e')
  endif

  " Eat trailing char
  call getchar(0)

endfun



"XXX
fun! VHDL_init()

  setlocal ignorecase
  setlocal omnifunc=VHDL_omnicomp

  inoreabbrev <buffer> <silent> port port<C-o>:call VHDL_comp_ports_put()<CR>
  inoreabbrev <buffer> <silent> map map<C-o>:call VHDL_map_put()<CR>

endfun


" menu : word, abbr, menu, info, kind, icase, dup
" tags : name, filename, cmd, kind, static

