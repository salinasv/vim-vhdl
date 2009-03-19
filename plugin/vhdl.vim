" Vim plugin for VHDL language
"
" Author: Benoît Ryder (benoit@ryder.fr)
"
" Usage:
"  - call VHDL_init() to init stuff
"  - some features need tags, keep them up to date
"
" Features:
"  - easy component creation (insert entity ports)
"    after typing 'component', throws a name prompt (entities names
"    completion), then build basic component code
"  - insert maps for component instanciation:
"       sample use:  type 'map' after instanciated component name
"  - reindent and do some realignments
"       sample use:  %call VHDL_nice_align()
"
" Todo:
"  - fix buggy indent behaviour


"For tests/debug purposes
if !exists('g:vhdl_plugin_debug')
  if exists('g:vhdl_plugin')
    finish
  endif
endif



""" Right align delimiter, surround it with spaces
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


""" Reindent and do some realignements
fun! VHDL_nice_align() range

  " Reindent
  let equalprg_bak = &l:equalprg
  setlocal equalprg=
  silent exe 'norm '.(a:lastline-a:firstline+1).'=='
  let &l:equalprg = equalprg_bak

  " declarations: ':'
  call cursor(a:firstline,0)
  while search('^\s*\%(\%(signal\|variable\|constant\)\+\)\?\w\+\s*:', 'cW', a:lastline)
    let l1 = line('.')
    if search('^\%(\s*\%(\%(signal\|variable\|constant\)\+\)\?\w\+\s*:\)\@!', 'W', a:lastline)
      exe l1.','.line(".").'call VHDL_align(":")'
    endif
    call cursor(line('.')+1,0)
  endwhile

  " map: '=>'
  call cursor(a:firstline,0)
  while search('\<\%(port\|generic\)\_s\+map\>\_s*(', 'ceW', a:lastline)
    let l1 = line(".")
    if searchpair('(','',')', 'W', '', a:lastline)
      exe l1.','.line('.').'call VHDL_align("=>")'
    endif
    call cursor(line('.')+1,0)
  endwhile

endfun



""" Get generic/port of a given entity or component
"
" Returns a dictionary of list of lines. Keys are flag letter associated to
" the result. The whole declaration is returned, including lines with the
" generic/port keywords.
"
" flags is a String, which can contain these character flags:
"  'e'  search for an entity (default)
"  'c'  search for a component
"  'g'  return generic
"  'p'  return port
"
" Return -1 if no tag is not found
fun! VHDL_get_genericport(name, flags)

  let kind = a:flags =~ 'c' ? 'c' : 'e'
  "TODO search for current file component first
  let l = filter(taglist('^'.a:name.'$'), 'v:val.kind==kind')
  if empty(l) | return -1 | endif
  let t = l[0]

  let view_bak = winsaveview()
  " Change buffer if tag points to another one
  if bufnr(t.filename) != bufnr("%")
    let bufhidden_bak = &bufhidden
    set bufhidden=hide
    let buf_bak = bufname("%")
    exe 'keepalt e '.t.filename
  endif

  sandbox silent! exe t.cmd
  
  let lines = {}
  let end_n = search('^\s*end\>', 'nW')
  let start_pos = getpos('.')

  for [k,v] in items({'g':'generic','p':'port'})
    if a:flags =~ k && search('\<'.v.'\_s*(', 'eW', end_n)
      let n1 = line('.')
      let n2 = searchpair('(','',')', 'nW', '', end_n)
      if n2 > 0
        let lines[k] = getline(n1,n2)
      endif
      call setpos('.', start_pos)
    endif
  endfor

  " Reload previous buffer, if needed
  if exists('buf_bak')
    exe 'keepalt b '.buf_bak
    exe 'set bufhidden='.bufhidden_bak
  endif

  call winrestview(view_bak)
  return lines

endfun


""" customlist completion function for entity names
fun! VHDL_comp_entities(lead, cmd, pos)
  let l = filter(taglist('^'.a:lead), 'v:val.kind=="e"')
  return map(l, 'v:val.name')
endfun



""" Put the generic/port map of a given component
" If component name is ommited, it is searched for in the 5 previous lines.
" (starting from cursor position).
" Return the number of put lines (may be 0), -1 if there was no map to put.
fun! VHDL_put_map(...) abort

  let cursor_bak = getpos('.')

  if exists('a:1')
    let name = a:1
  else
    if !search(':\s*\k\+','b', line('.')-5)
      return -1
    endif
    let name = matchstr(getline('.'), ':\s*\zs\k\+')
    call setpos('.', cursor_bak)
  endif

  if name == ''
    echomsg "Component name not found"
    return -1
  endif

  let complines = VHDL_get_genericport(name, 'cgp')
  if type(complines) == type(0) || empty(complines)
    " No result
    call setpos('.', cursor_bak)
    if type(complines) == type(0)
      echomsg "Component '".name."' not found"
    else
      echomsg "No map for component '".name."'"
    endif
    return -1
  endif

  " Extract signals declared in generic/port
  let lines = {}
  for [k,v] in items(complines)
    let type = {'g':'generic','p':'port'}[k]
    " Strip comments before joining
    call map(v, 'substitute(v:val, "\\s*--.*$", "", "")')
    let smap = join(v, "\n")
    " Remove port/generic trailing ')', object type and declaration type
    let smap = substitute(smap, '\<'.type.'\s*(', '', '')
    let smap = substitute(smap, ')[;]\s*$', '', '')
    let smap = substitute(smap, '\<\%(signal\|variable\|constant\)\>', '', 'g')
    let smap = substitute(smap, ':[^;]*', '', 'g')
    " Extract declared objects and build mapping
    let dec = split(smap, '[[:space:],;]\+')
    let dec = map(dec, 'v:val." => ,"')
    if len(dec) == 0
      continue
    end
    " Remove final ',' of last declaration
    let dec[-1] = substitute(dec[-1], ',$', '', '')
    " Add first and last lines, but not the final ';'
    let lines[k] = [type.' map ('] + dec + [')']
  endfor

  " Put first generic, then port (if available)
  let ks = keys(lines)
  if len(ks) == 2
    let putlines = lines['g'] + lines['p']
  elseif len(ks) == 1
    let putlines = lines[ks[0]]
  else
    echomsg "Nothing to put for component '".name."'"
    return 0
  endif
  " Add the final ';', and put
  let putlines[-1] .= ';'
  put=putlines

  exe cursor_bak[1].',.call VHDL_nice_align()'
  "call setpos('.', cursor_bak)
  return len(putlines)

endfun


""" Insert code for a component.
" Ask user for a component and get its ports using tags.
" Expected to be used after typing 'component'
fun! <SID>VHDL_component_create()

  if getline('.') =~ '\%<'.col('.').'c--' | return | endif
  if getline('.') =~ '\<end\s\+component' | return | endif

  let cursor_bak = getpos('.')

  call inputsave()
  let name = input('Component name: ', '', 'customlist,VHDL_comp_entities')
  call inputrestore()
  if name == '' | return | endif

  exe "norm \"=' '.name\<CR>p"

  let gp = VHDL_get_genericport(name, 'egp')
  if has_key(gp, 'g')
    silent! pu=gp['g']
  endif
  if has_key(gp, 'p')
    silent! pu=gp['p']
  endif

  silent! pu='end component '.name.';'

  let cursor_end = getpos('.')
  exe cursor_bak[1].',.call VHDL_nice_align()'
  call setpos('.', cursor_end)
  norm o

endfun


""" Insert generic/port map code for component instantiation.
" Wraps the VHDL_put_map() function for iabbrev use.
fun! <SID>VHDL_component_instantiate()

  if getline('.') =~ '\%<'.col('.').'c--' | return | endif
  let pos_bak = getpos('.')
  if getline('.') =~ '^\s*$'
    norm k$
  endif

  if VHDL_put_map() > 0
    call setpos('.', getpos("'["))
    call search('=> ,\?', 'e')
    call getchar(0)
  else
    call setpos('.', pos_bak)
    exe "norm \"='map'\<CR>p"
  endif

endfunc


fun! VHDL_init()

  setlocal ignorecase
  setlocal omnifunc=VHDL_omnicomp


  " Simple shortcuts
  iabbrev <buffer> dt downto
  iabbrev <buffer> sig signal
  iabbrev <buffer> gen generate
  iabbrev <buffer> ot others
  iabbrev <buffer> sl std_logic
  iabbrev <buffer> slv std_logic_vector(
  iabbrev <buffer> uns unsigned
  iabbrev <buffer> toi to_integer
  iabbrev <buffer> tos to_unsigned
  iabbrev <buffer> tou to_unsigned

  inoreabbrev <buffer> <silent> component component<C-o>:call <SID>VHDL_component_create()<CR>
  inoreabbrev <buffer> <silent> map <C-o>:call <SID>VHDL_component_instantiate()<CR>

	map <F2> :call VHDL_nice_align()<CR>

endfun


