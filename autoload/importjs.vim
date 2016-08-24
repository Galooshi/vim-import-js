function importjs#Word()
  let word = expand("<cword>")
  if (empty(word))
    return
  endif
  call importjs#ExecCommand("word", word)
endfunction
function importjs#Goto()
  let word = expand("<cword>")
  if (empty(word))
    return
  endif
  call importjs#ExecCommand("goto", word)
endfunction
function importjs#Fix()
  call importjs#ExecCommand("fix", "")
endfunction

" Execute the command. If we get an empty response, keep trying to execute until
" we get a non-empty response or hit the max number of tries.
function importjs#TryExecPayload(payload, tryCount)
  if (a:tryCount > 3)
    echoerr "No response from `importjs` after " . a:tryCount . " tries"
    return
  endif

  let resultString = ch_evalraw(g:ImportJSChannel, json_encode(a:payload) . "\n")
  if (resultString != "")
    return resultString
  endif

  " We got no response, which probably means that importjsd hasn't had enough
  " time to start up yet. Let's wait a little and try again.
  sleep 100m
  return importjs#TryExecPayload(a:payload, a:tryCount + 1)
endfunction

function importjs#ExecCommand(command, arg)
  let fileContent = join(getline(1, '$'), "\n")
  let payload = {
    \'command': a:command,
    \'commandArg': a:arg,
    \'pathToFile': expand("%"),
    \'fileContent': fileContent,
  \}

  try
    let resultString = importjs#TryExecPayload(payload, 0)
  catch /E906:/
    " channel not open
    echoerr "importjsd process not running"
    return
  endtry

  let result = json_decode(resultString)

  if (has_key(result, 'error'))
    echoerr result.error
    return
  endif

  if (a:command == "goto" && has_key(result, 'goto'))
    execute "edit " . result.goto
    return
  endif

  if (result.fileContent != fileContent)
    call importjs#ReplaceBuffer(result.fileContent)
  endif

  if (has_key(result, 'messages') && len(result.messages))
    call importjs#Msg(join(result.messages, "\n"))
  endif
  if (has_key(result, 'unresolvedImports') && len(result.unresolvedImports))
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
    call importjs#ExecCommand("add", resolved)
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

function! importjs#JobExit(job, exitstatus)
  if (a:exitstatus == 127)
    echoerr "importjsd command not found. Run `npm install import-js` to get it."
    echoerr ""
  endif
endfun

function! importjs#Init()
   " Include the PID of the parent (this Vim process) to make `ps` output more
   " useful.
  let s:job=job_start(['importjsd', 'start', '--parent-pid', getpid()], {
    \'exit_cb': 'importjs#JobExit',
  \})

  let g:ImportJSChannel=job_getchannel(s:job)
endfunction
