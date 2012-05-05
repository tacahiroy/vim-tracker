" plugin/bestfriend.vim
" Author: Takahiro YOSHIHARA <tacahiroy```AT```gmail.com>
" License: MIT License

if exists('g:loaded_bestfriend') || &cp
  finish
endif
let g:loaded_bestfriend = 1

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
let s:bf = bestfriend#new(bestfriend#dbname(0))
" total
let s:bf.summary = bestfriend#new(bestfriend#dbname(1))

" Command
command! -nargs=0 BestFriend call s:bf.show()
command! -nargs=0 BestFriends call s:bf.show('all')


augroup BestFriend
  autocmd!

  autocmd BufEnter,FocusGained * call s:bf.start(expand('%:p'))
  autocmd BufLeave,FocusLost,VimLeave * call s:bf.stop(expand('%:p'))
  autocmd CursorHold,CursorHoldI * call s:bf.detect_cursor_move(expand('%:p'))
augroup END


let &cpo = s:saved_cpo
unlet s:saved_cpo

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:

