function importjs#Word()
  call importjs#ExecCommand("word", expand("<cword>"))
endfunction
function importjs#Goto()
  call importjs#ExecCommand("goto", expand("<cword>"))
endfunction
function importjs#Fix()
  call importjs#ExecCommand("fix", )
endfunction

function importjs#ExecCommand(...)
  let command = ['importjs'] + a:000
  let fileContent = join(getline(1, '$'), "\n")
  call add(command, expand("%"))
  let resultString = system(join(command, " "), fileContent)
  if (v:shell_error)
    echoerr resultString
    return
  endif
  let result = json_decode(resultString)

  if (a:1 == "goto" && has_key(result, 'goto'))
    execute "edit " . result.goto
    return
  endif

  if (result.fileContent != fileContent)
    call importjs#ReplaceBuffer(result.fileContent)
  endif

  if (len(result.messages))
    call importjs#Msg(join(result.messages, "\n"))
  endif
  if (len(result.unresolvedImports))
    call importjs#Resolve(result.unresolvedImports)
  endif
endfunction

function importjs#Resolve(unresolvedImports)
  let resolved = {}
  for [word, alternatives] in items(a:unresolvedImports)
    let options = ["ImportJS: Select module to import for `" . word . "`:"]
    let index = 0
    for alternative in alternatives
      let index = index + 1
      call add(options, index . ": " . alternative.displayName)
    endfor
    let selection = inputlist(options)
    if (selection > 0 && selection < len(options))
      let resolved[word] = alternatives[selection - 1].importPath
    endif
  endfor
  if (len(resolved))
    let json = json_encode(resolved)
    call importjs#ExecCommand("add", "'" . json . "'")
  endif
endfunction


function importjs#ReplaceBuffer(content)
  " Save cursor position so that we can restore it later
  let cursorPos = getpos(".")
  " Delete all lines from the buffer
  execute "%d"
  " Write the resulting content into the buffer
  let @a = a:content
  normal! G
  execute "put a"
  " Remove lingering line at the top:
  execut ":1d"
  " Restore cursor position
  call setpos(".", cursorPos)
endfunction

" Prints [long] message up to (&columns-1) length
" guaranteed without "Press Enter" prompt.
" http://vim.wikia.com/wiki/How_to_print_full_screen_width_messages
function! importjs#Msg(msg)
  let x=&ruler | let y=&showcmd
  set noruler noshowcmd
  redraw
  echo a:msg
  let &ruler=x | let &showcmd=y
endfun

function! importjs#Init()
  echomsg 'Galooshi!'
endfunction
