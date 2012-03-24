" edtime.vim
" Maintainer: Takahiro YOSHIHARA <tacahiroy```AT```gmail.com>
" License: MIT License
" Version: 0.0.1

let s:saved_cpo = &cpo
set cpo&vim


" Utilities " {{{
" returns current file's absolute path
function! s:curfile()
  return expand('%:p')
endfunction

function! s:divide(t)
  let DAY = 60 * 24
  let HOUR = 60

  let min = float2nr(a:t) / 60

  let time = {}
  let time.day = min / DAY
  let time.hour = (min % DAY) / HOUR
  let time.min = (min % DAY % HOUR)

  return time
endfunction

function! s:format_time(t)
  let ans = s:divide(round(a:t))
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
let s:EdTime = {}
let s:EdTime.files = {}
let s:EdTime.db = ''
let s:EdTime.summary = {}

" NOTE: files that `accept_pattern` - `ignore_pattern` are managed
" if both pattern are specified
let s:EdTime.accept_pattern = get(g:, 'edtime_accept_pattern', '')
let s:EdTime.ignore_pattern = get(g:, 'edtime_ignore_pattern', '')
lockvar s:EdTime.accept_pattern
lockvar s:EdTime.ignore_pattern

function! edtime#new(f)
  let obj = deepcopy(s:EdTime)
  let obj.db = a:f
  call obj.load()
  return obj
endfunction

function! s:EdTime.start(f) dict
  if self.is_ignored(a:f)
    return
  endif

  if !self.has_file(a:f)
    call self.add_file(a:f)
  endif
  let self.files[a:f].start = reltime()
endfunction

function! s:EdTime.stop(f) dict
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

function! s:EdTime.has_file(f) dict
  return has_key(self.files, a:f)
endfunction

function! s:EdTime.add_file(f) dict
  let self.files[a:f] = { 'start': [], 'end': [], 'total': 0 }
endfunction

function! s:EdTime.reset(f) dict
  let self.files[a:f].start = []
  let self.files[a:f].end = []
endfunction

function! s:EdTime.remove(f) dict
  call remove(self.files, a:f)
endfunction

function! s:EdTime.calc(f) dict
  let pass = str2float(reltimestr(reltime(self.files[a:f].start, self.files[a:f].end)))
  let self.files[a:f].total += pass

  if !self.summary.has_file(a:f)
    call self.summary.add_file(a:f)
  endif
  let self.summary.files[a:f].total += pass

  call self.save()
  call self.summary.save()
endfunction

function! s:EdTime.save() dict
  let files = []
  for [k, v] in items(self.files)
    " call add(files, k)
    let info = {}
    let info[k] = {'total': v.total}
    call add(files, string(info))
  endfor
  call writefile(files, self.db)
endfunction

function! s:EdTime.load() dict
  if !filereadable(self.db)
    return
  endif

  let files = readfile(self.db)
  for f in files
    for [k, v] in items(eval(f))
      let self.files[k] = v
      call extend(self.files[k], {'start': [], 'end': []})
    endfor
  endfor
endfunction

" TODO: sorting
" TODO: display to buffer
function! s:EdTime.show(...) dict
  try
    call self.stop(s:curfile())

    if !a:0 && self.is_ignored(s:curfile())
      return
    endif

    let files = {}
    if a:0 == 0
      " show only current file
      let files = {s:curfile(): self.files[s:curfile()]}
    else
      let files = self.files
    endif

    for [k, v] in items(files)
      let sum = s:format_time(self.summary.files[k].total)
      echo printf('%s: %s (%s)', k, s:format_time(v.total), sum)
    endfor
  finally
    call self.start(s:curfile())
  endtry
endfunction

" returns whether {f} is ignored or not
function! s:EdTime.is_ignored(f) dict
  if empty(a:f)
    return 1
  endif

  if isdirectory(a:f)
    return 1
  endif

  if expand(a:f) == self.db
    return 1
  endif

  if !empty(&l:buftype)
    return 1
  endif

  if !empty(self.accept_pattern)
    if a:f !~# self.accept_pattern
      return 1
    endif
  endif

  if !empty(self.ignore_pattern)
    if a:f =~# self.ignore_pattern
      return 1
    endif
  endif

  return 0
endfunction
" }}}


let &cpo = s:saved_cpo
unlet s:saved_cpo

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:
