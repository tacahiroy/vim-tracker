" edtime.vim
" Maintainer: Takahiro YOSHIHARA <tacahiroy```AT```gmail.com>
" License: MIT License
" Version: 0.0.1

" if exists('g:loaded_edtime') || &cp
"   finish
" endif
" let g:loaded_edtime = 1

if !has('reltime')
  finish
endif
if !has('float')
  finish
endif

let s:saved_cpo = &cpo
set cpo&vim


" Utilities " {{{
function! s:to_path(...)
  return join(a:000, '/')
endfunction
" }}}


let s:data_dir = expand(get(g:, 'edtime_data_dir', '~/.edtime'))
if !isdirectory(s:data_dir)
  call mkdir(s:data_dir, 'p')
endif

" data-file is managed each day
" today
let s:edt = edtime#new(s:to_path(s:data_dir, strftime('%Y%m%d.db')))
" total
let s:edt.summary = edtime#new(s:to_path(s:data_dir, 'full.db'))

" Command
command! -nargs=0 EdTime call s:edt.show()
command! -nargs=0 EdTimeAll call s:edt.show('-a')


augroup EdTime
  autocmd!

  autocmd BufEnter,FocusGained * call s:edt.start(expand('%:p'))
  autocmd BufLeave,FocusLost,VimLeave * call s:edt.stop(expand('%:p'))
augroup END


let &cpo = s:saved_cpo
unlet s:saved_cpo

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:
