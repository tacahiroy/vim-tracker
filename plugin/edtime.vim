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

let s:saved_cpo = &cpo
set cpo&vim


" Utilities " {{{
" returns current file's absolute path
function! s:curfile()
  return expand('%:p')
endfunction

" returns whether {f} is ignored or not
function! s:is_ignored(f)
  if empty(a:f)
    return 1
  endif
  if expand(a:f) == s:data_file
    return 1
  endif
  if !empty(&l:buftype)
    return 1
  endif

  return 0
endfunction

function! s:divide(t)
  let MIN = 60
  let HOUR = 60 * 60
  let DAY = 60 * 60 * 24

  let time = {}
  let time.day = a:t / DAY
  let time.hour = a:t / HOUR
  let time.min = a:t / MIN

  return time
endfunction

function! s:format_time(t)
  let ans = s:divide(a:t)
  let str = ''

  if 0 < ans.day
    let tpl = '%d '
    let tpl .= (1 < ans.day ? 'days' : 'day') . ', '
    let str = printf(tpl , ans.day)
  endif

  let str .= printf('%02d:%02d', ans.hour, ans.min)

  return str
endfunction
" }}}

" Object " {{{
let s:edtime = {}
let s:edtime.files = {}

function! s:edtime.start(f) dict
  if s:is_ignored(a:f)
    return
  endif

  if !has_key(self.files, a:f)
    let self.files[a:f] = { 'start': [], 'end': [], 'total': 0 }
  endif
  let self.files[a:f].start = reltime()
endfunction

function! s:edtime.stop(f) dict
  if !has_key(self.files, a:f)
    return
  endif
  if empty(self.files[a:f].start)
    return
  endif

  let self.files[a:f].end = reltime()

  call self.calc(a:f)
  call self.reset(a:f)
endfunction

function! s:edtime.reset(f) dict
  let self.files[a:f].start = []
  let self.files[a:f].end = []
endfunction

function! s:edtime.calc(f) dict
  let pass = str2float(reltimestr(reltime(self.files[a:f].start, self.files[a:f].end)))
  let self.files[a:f].total += pass
  call self.save()
endfunction

function! s:edtime.save() dict
  let files = []
  for [k, v] in items(self.files)
    " call add(files, k)
    let info = {}
    let info[k] = {'total': v.total}
    call add(files, string(info))
  endfor
  call writefile(files, s:data_file)
endfunction

function! s:edtime.load() dict
  let files = readfile(s:data_file)
  for f in files
    for [k, v] in items(eval(f))
      let self.files[k] = v
      call extend(self.files[k], {'start': [], 'end': []})
    endfor
  endfor
endfunction

function! s:edtime.show() dict
  try
    call self.stop(s:curfile())
    for [k, v] in items(self.files)
      echo printf('%s: %s', k, s:format_time(float2nr(round(v.total))))
    endfor
  finally
    call self.start(s:curfile())
  endtry
endfunction
" }}}


command! EdTime call s:edtime.show()


augroup EdTime
  autocmd!

  autocmd BufEnter,FocusGained * call s:edtime.start(s:curfile())
  autocmd BufLeave,FocusLost,VimLeave * call s:edtime.stop(s:curfile())
augroup END


let s:data_dir = expand(get(g:, 'edtime_data_dir', '~/.edtime'))
if !isdirectory(s:data_dir)
  call mkdir(s:data_dir, 'p')
endif
let s:data_file = s:data_dir . '/db'

if filereadable(s:data_file)
  call s:edtime.load()
endif

let &cpo = s:saved_cpo
unlet s:saved_cpo

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:
