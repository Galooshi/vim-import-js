if !hasmapto(':ImportJSWord<CR>') && maparg('<Leader>j', 'n') == ''
  silent! nnoremap <buffer> <unique> <silent> <Leader>j :ImportJSWord<CR>
endif

if !hasmapto(':ImportJSFix<CR>') && maparg('<Leader>i', 'n') == ''
  silent! nnoremap <buffer> <unique> <silent> <Leader>i :ImportJSFix<CR>
endif

if !hasmapto(':ImportJSGoto<CR>') && maparg('<Leader>g', 'n') == ''
  silent! nnoremap <buffer> <unique> <silent> <Leader>g :ImportJSGoto<CR>
endif
