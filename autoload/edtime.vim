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

function! s:shorten_path(s)
  return substitute(a:s, '^'.$HOME, '~', '')
endfunction

function! s:expand_path(s)
  " error E33 would occur if you forget to escape tilde
  return substitute(a:s, '\~', $HOME, 'g')
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

" public " {{{
function! edtime#complete(A, L, P)
endfunction

function! edtime#new(f)
  let obj = deepcopy(s:EdTime)
  let obj.db = a:f
  call obj.load()
  return obj
endfunction
" }}}

" Object " {{{
let s:EdTime = {}

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

function! s:EdTime.get_total(k) dict
  return self.has_file(a:k) ? self.files[a:k].total : 0
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
" TODO: display into a buffer
" TODO: omit file name if it's better
function! s:EdTime.show(...) dict
  try
    call self.stop(s:curfile())

    if a:0 == 0 && self.is_ignored(s:curfile())
      return
    endif

    let opts = ['-a', '']
    let opt = get(a:, '1', '')

    let files = {}
    if opt == '-a'
      for [k, v] in items(self.summary.files)
        let files[k] = {'total': self.summary.get_total(k)}
      endfor
    else
      " show only current file
      let files = {s:curfile(): self.files[s:curfile()]}
    endif

    let sortedlist = self.sort(files)
    if !self.is_display_zero
      let sortedlist = self.filter(sortedlist)
    endif

    let i = 1
    for [k, v] in sortedlist
      let sum = s:format_time(self.summary.files[k].total)
      let today = s:format_time(self.get_total(k))
      echo printf('%3d: %s: %s (%s)', i, s:shorten_path(k), today, sum)
      let i += 1
    endfor
  finally
    call self.start(s:curfile())
  endtry
endfunction

function! s:EdTime.sort(files) dict
  let list = []
  for [k, v] in items(a:files)
    call add(list, [k, v])
  endfor

  if empty(self.sort_func)
    let self.sort_func = self.sort_by_edtime
  endif

  return sort(sort(list), self.sort_func, self)
endfunction

function! s:EdTime.filter(list)
  return filter(a:list, '0 < v:val[1].total')
endfunction

function! s:EdTime.sort_by_edtime(a, b) dict
  let a = a:a[1].total
  let b = a:b[1].total
  let r = 0

  if a < b
    let r = -1
  elseif b < a
    let r = 1
  else
    let r = 0
  endif

  return r * (self.sort_order_is_desc ? -1 : 1)
endfunction

function s:EdTime.sort_by_time_today(a, b)
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

let s:EdTime.files = {}
let s:EdTime.db = ''
let s:EdTime.summary = {}
let s:EdTime.sort_func = ''
let s:EdTime.sort_order_is_desc = 0

" NOTE: files that `accept_pattern` - `ignore_pattern` are managed
" if both pattern are specified
let s:EdTime.accept_pattern = s:expand_path(get(g:, 'edtime_accept_pattern', ''))
let s:EdTime.ignore_pattern = s:expand_path(get(g:, 'edtime_ignore_pattern', ''))
let s:EdTime.is_display_zero = get(g:, 'edtime_is_display_zero', 0)
let s:EdTime.sort_order_is_desc = get(g:, 'edtime_sort_order_is_desc', 1)
let s:EdTime.sort_func = s:EdTime.sort_by_edtime
" }}}


let &cpo = s:saved_cpo
unlet s:saved_cpo

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:
