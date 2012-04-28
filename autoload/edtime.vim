" autoload/edtime.vim
" Author: Takahiro YOSHIHARA <tacahiroy```AT```gmail.com>
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
  let time = ''

  if s:is_debug
    return string(a:t)
  endif

  if 0 < ans.day
    let tpl = '%d '
    let tpl .= (1 < ans.day ? 'days' : 'day') . ', '
    let time = printf(tpl , ans.day)
  endif

  let time .= printf('%02d:%02d', ans.hour, ans.min)

  return time 
endfunction

function! s:longest_path_length(ary2)
  let mlen = 0

  for [k, v] in a:ary2
    let l = len(s:shorten_path(k))
    if mlen < l
      let mlen = l
    endif
  endfor

  return mlen
endfunction
" }}}

" public " {{{
function! edtime#complete(A, L, P)
endfunction

function! edtime#new(f)
  let obj = deepcopy(s:EdTime)
  call obj.set_db(a:f)
  call obj.load()
  return obj
endfunction

" args: k: int: 0 => today's, 1 => full
function! edtime#dbname(k)
  return a:k ? 'full.db' : strftime('%Y%m%d.db')
endfunction
" }}}

" Object " {{{
let s:EdTime = {}

function! s:EdTime.set_db(name) dict
  let self.db = self.data_dir . '/' . a:name
endfunction

function! s:EdTime.start(f) dict
  if self.is_ignored(a:f)
    return
  endif

  if !self.has_file(a:f)
    call self.add_file(a:f)
  endif

  if has_key(self.files[a:f], 'cursor_pos')
    if getpos('.') != self.files[a:f].cursor_pos
      call self.stop(a:f)
    endif
  endif

  " date might be changed when the file is being edited
  call self.set_db(edtime#dbname(0))
  let self.files[a:f].start = reltime()
  let self.files[a:f].cursor_pos = getpos('.')
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

" TODO: display into a buffer
" TODO: omit file name if it's better
function! s:EdTime.show(...) dict
  try
    call self.stop(s:curfile())

    if a:0 == 0 && self.is_ignored(s:curfile())
      return
    endif

    let option_list = ['all', '']
    let opt = get(a:, '1', '')

    let files = {}
    if opt == 'all'
      for [k, v] in items(self.summary.files)
        let files[k] = {'total': self.sort_base_is_today ?
                               \ self.get_total(k) :
                               \ self.summary.get_total(k)}
      endfor
    else
      " show only current file
      let files = {s:curfile(): self.files[s:curfile()]}
    endif

    let sortedlist = self.sort(files)
    if !self.is_display_zero
      let sortedlist = self.filter(sortedlist)
    endif
    let sortedlist = sortedlist[0:self.max_rank - 1]

    let fmt = '%3d: '
    let fmt .= printf('%%-%ds ', s:longest_path_length(sortedlist))
    let fmt .= '%s (%s)'

    let i = 1
    for [k, v] in sortedlist
      let sum = s:format_time(self.summary.files[k].total)
      let today = s:format_time(self.get_total(k))
      echo printf(fmt, i, s:shorten_path(k), today, sum)

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

  if empty(self.sort_function)
    let self.sort_function = self.sort_by_edtime
  endif

  return sort(sort(list), self.sort_function, self)
endfunction

function! s:EdTime.filter(list)
  let l = filter(a:list, '0.0 < v:val[1].total')
  return filter(l, 'filereadable(v:val[0])')
endfunction

function! s:EdTime.sort_by_edtime(a, b) dict
  " a:a[0] => key, [1] => {'total': 999.99}
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

function! s:EdTime.sort_by_name(a, b) dict
  let a = a:a[0]
  let b = a:b[0]
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

let s:is_debug = get(g:, 'edtime_is_debug', 0)

""
" Initialization etc ...
"
let s:EdTime.files = {}
let s:EdTime.db = ''
let s:EdTime.summary = {}

let s:data_dir = expand(get(g:, 'edtime_data_dir', '~/.edtime'))
if !isdirectory(s:data_dir)
  call mkdir(s:data_dir, 'p')
endif
let s:EdTime.data_dir = s:data_dir

" NOTE: files that `accept_pattern` - `ignore_pattern` are managed
" if both pattern are specified
let s:EdTime.accept_pattern = s:expand_path(get(g:, 'edtime_accept_pattern', ''))
let s:EdTime.ignore_pattern = s:expand_path(get(g:, 'edtime_ignore_pattern', ''))

let s:EdTime.is_display_zero = get(g:, 'edtime_is_display_zero', 0)
let s:EdTime.max_rank = get(g:, 'edtime_max_rank', 10)

" sort
let s:sort_functions = filter(keys(s:EdTime),
      \ 'v:val =~ "^sort_by_" && type(s:EdTime[v:val]) == type(function("tr"))')

let s:DEFAULT_SORT_METHOD = 'sort_by_edtime'
let s:sort_method = get(g:, 'edtime_sort_method', s:DEFAULT_SORT_METHOD)
if index(s:sort_functions, s:sort_method) == -1
  let s:sort_method = s:DEFAULT_SORT_METHOD
endif
let s:EdTime.sort_function = s:EdTime[s:sort_method]

let s:EdTime.sort_base_is_today = get(g:, 'edtime_sort_base_is_today', 1)
let s:EdTime.sort_order_is_desc = get(g:, 'edtime_sort_order_is_desc', 1)
" }}}


let &cpo = s:saved_cpo
unlet s:saved_cpo

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:
