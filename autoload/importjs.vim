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

  if exists("*ch_evalraw")
    let resultString = ch_evalraw(g:ImportJSChannel, json_encode(a:payload) . "\n")
    if (resultString != "")
      return resultString
    endif
  endif

  if exists("*jobsend")
    " Problem starting with importjsd process
    if s:job == -1
      echoerr "importjsd process not running"
      return ""
    endif

    call jobsend(s:job, json_encode(a:payload) . "\n")
    return ""
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
    \'pathToFile': expand("%:p"),
    \'fileContent': fileContent,
  \}

  try
    let resultString = importjs#TryExecPayload(payload, 0)
  catch /E906:/
    " channel not open
    echoerr "importjsd process not running"
    return
  endtry

  if (resultString != "")
    return importjs#ParseResult(resultString, a:command)
  endif
endfunction

function importjs#ParseResult(resultString, command)
  let result = json_decode(a:resultString)

  if (has_key(result, 'error'))
    echoerr result.error
    return
  endif

  if ((a:command == "goto" || a:command == "") && has_key(result, 'goto'))
    execute "edit " . result.goto
    return
  endif

  let fileContent = join(getline(1, '$'), "\n")
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
  let originalLineCount = line("$")
  " Delete all lines from the buffer
  execute "%d"
  " Write the resulting content into the buffer
  let @a = a:content
  normal! G
  execute "put a"
  " Remove lingering line at the top:
  execut ":1d"
  " Restore cursor position, attempting to compensate for the resulting
  " imports moving the original line up or down
  let newLineCount = line("$")
  let cursorPos[1] = cursorPos[1] + newLineCount - originalLineCount
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

" Neovim job handler
function! s:JobHandler(job_id, data, event) dict
  if a:event == 'stdout'
    let str = join(a:data)
    if strpart(str, 0, 1) == "{"
      call importjs#ParseResult(str, "")
    endif
  elseif a:event == 'stderr'
    echoerr "import-js error: " . join(a:data)
  endif
endfunction

function! importjs#Init()
  let s:callbacks = {
        \ 'on_stdout': function('s:JobHandler'),
        \ 'on_stderr': function('s:JobHandler'),
        \ 'on_exit': function('s:JobHandler')
        \ }

  " Include the PID of the parent (this Vim process) to make `ps` output more
  " useful.

  " neovim
  if exists("*jobstart")
    let s:job = jobstart(['importjsd', 'start', '--parent-pid', getpid()], s:callbacks)
  endif

  " vim
  if exists("*job_start")
    let s:job=job_start(['importjsd', 'start', '--parent-pid', getpid()], {
          \'exit_cb': 'importjs#JobExit',
          \})

    let g:ImportJSChannel=job_getchannel(s:job)
  endif
endfunction
