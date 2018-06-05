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
    " Problem starting with importjs process
    if s:job == -1
      echoerr "importjs daemon process not running"
      return ""
    endif

    call jobsend(s:job, json_encode(a:payload) . "\n")
    return ""
  endif

  " We got no response, which probably means that importjs hasn't had enough
  " time to start up yet. Let's wait a little and try again.
  sleep 100m
  return importjs#TryExecPayload(a:payload, a:tryCount + 1)
endfunction

function importjs#ExecCommand(command, arg, ...)
  " lazy-load the background process
  call importjs#Init()

  let sendContent = (a:0 >= 1) ? a:1 : 1
  if sendContent == 1
    let fileContent = join(getline(1, '$'), "\n")
  else
    let fileContent = ''
  endif
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
    echoerr "importjs process not running"
    return
  endtry

  if (resultString != "")
    return importjs#ParseResult(resultString)
  endif
endfunction

function importjs#ParseResult(resultString)
  let result = json_decode(a:resultString)

  if (has_key(result, 'error'))
    echoerr result.error
    return
  endif

  if (has_key(result, 'goto'))
    execute "edit " . result.goto
    return
  endif

  if (has_key(result, 'modules'))
    " Simply return the list of modules returned in a search. This can be used
    " by other plugins wanting to make use of the import-js search function.
    return result.modules
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

  " Save cursor position so that we can restore it later
  let cursorPos = getpos(".")

  for [word, alternatives] in items(a:unresolvedImports)
    let wordWithBoundaries = "\\<" . word . "\\>"
    " Highlight the word in the buffer
    let match = matchadd("Search", wordWithBoundaries)
    try
      " Jump to the word
      execute ":ijump " . wordWithBoundaries
    catch /E387:/
      " we're already on that line
    endtry

    let options = ["ImportJS: Select module to import for `" . word . "`:"]
    let index = 0
    for alternative in alternatives
      let index = index + 1
      call add(options, index . ": " . alternative.displayName)
    endfor
    call inputsave()

    " Clear out previous message. This is particularly important if there are
    " multiple unresolved imports that we will be prompting for.
    call importjs#Msg("")

    let selection = inputlist(options)

    call inputrestore()

    " Remove the highlight
    call matchdelete(match)

    if (selection > 0 && selection < len(options))
      let resolved[word] = alternatives[selection - 1].data
    endif
  endfor

  call setpos(".", cursorPos)

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
    echoerr "importjs command not found. Run `npm install import-js` to get it."
    echoerr ""
  endif
endfun

" Holds job output that must be joined across multiple outputs for Neovim.
let s:neovim_job_output = ''

" Neovim sends output in 8192 byte chunks, we must join all of the chunks
" before handling them. Inspired by https://git.io/v7HcP
function! importjs#JoinNeovimOutput(last_line, data) abort
  let l:lines = a:data[:-2]

  if len(a:data) > 1
    let l:lines[0] = a:last_line . l:lines[0]
    let l:new_last_line = a:data[-1]
  else
    let l:new_last_line = a:last_line . a:data[0]
  endif

  for l:line in l:lines
    call importjs#HandleJoinedNeovimInput(l:line)
  endfor

  return l:new_last_line
endfunction

function! importjs#HandleJoinedNeovimInput(line)
  if strpart(a:line, 0, 1) == "{"
    call importjs#ParseResult(a:line)
  endif
endfunction

" Neovim job handler
function! s:JobHandler(job_id, data, event) dict
  if a:event == 'stdout'
    let s:neovim_job_output = importjs#JoinNeovimOutput(
          \   s:neovim_job_output,
          \   a:data
          \)
  elseif a:event == 'stderr'
    echoerr "import-js error: " . join(a:data)
  endif
endfunction

function! importjs#Init()
  if exists("s:job")
    return
  endif

  let s:callbacks = {
        \ 'on_stdout': function('s:JobHandler'),
        \ 'on_stderr': function('s:JobHandler'),
        \ 'on_exit': function('s:JobHandler')
        \ }

  " Include the PID of the parent (this Vim process) to make `ps` output more
  " useful.

  if has('win32') || has('win64')
    let s:job_executable='importjs.cmd'
  else
    let s:job_executable='importjs'
  endif

  if exists("*jobstart")
    " neovim
    let s:job = jobstart([s:job_executable, 'start', '--parent-pid', getpid()], s:callbacks)
  elseif exists("*job_start")
    " vim
    let s:job=job_start([s:job_executable, 'start', '--parent-pid', getpid()], {
          \'exit_cb': 'importjs#JobExit',
          \})

    let g:ImportJSChannel=job_getchannel(s:job)
    " ignore first line of output, which is something like
    " > ImportJS (v2.10.1) DAEMON active.
    call ch_readraw(g:ImportJSChannel, { "timeout": 2000 })
  endif
endfunction
