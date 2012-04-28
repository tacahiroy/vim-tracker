" edtime.vim
" Author: Takahiro YOSHIHARA <tacahiroy```AT```gmail.com>
" License: MIT License
" Version: 0.0.1

if exists('g:loaded_edtime') || &cp
  finish
endif
let g:loaded_edtime = 1

if !has('reltime')
  finish
endif
if !has('float')
  finish
endif

let s:saved_cpo = &cpo
set cpo&vim


" data-file is managed each day
" today
let s:edt = edtime#new(edtime#dbname(0))
" total
let s:edt.summary = edtime#new(edtime#dbname(1))

let is_detect_cursor_move = get(g:, 'edtime_is_detect_cursor_move',
                                   \ has('gui_running') ? '0' : '1')

" Command
command! -nargs=0 EdTime call s:edt.show()
command! -nargs=0 EdTimeAll call s:edt.show('all')


augroup EdTime
  autocmd!

  autocmd BufEnter,FocusGained * call s:edt.start(expand('%:p'))
  autocmd BufLeave,FocusLost,VimLeave * call s:edt.stop(expand('%:p'))

  if is_detect_cursor_move
    autocmd CursorHold,CursorHoldI * call s:edt.start(expand('%:p'))
  endif
augroup END


let &cpo = s:saved_cpo
unlet s:saved_cpo

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:
