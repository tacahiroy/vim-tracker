" autoload/bestfriend.vim
" Author: Takahiro Yoshihara <tacahiroy\AT/gmail.com>
" License: MIT License

let s:saved_cpo = &cpo
set cpo&vim


let s:STOP  = 0
let s:START = 1

" Utilities " {{{
" returns current file's absolute path
function! s:debug(msg)
  if s:is_debug
    echomsg a:msg
  endif
endfunction

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

function! s:dirname(path)
  return fnamemodify(a:path, ':p:h:t')
endfunction

function! s:basename(path)
  return fnamemodify(a:path, ':p:t')
endfunction

function! s:buildpath(...)
  return join(a:000, '/')
endfunction

function! s:numberwidth()
  if &number || (703 <= v:version && &relativenumber)
    return &numberwidth
  else
    return 0
  endif
endfunction
" }}}

" public " {{{
function! bestfriend#complete(A, L, P)
endfunction

function! bestfriend#new(f)
  let obj = deepcopy(s:BestFriend)
  call obj.set_db(a:f)
  call obj.load()
  return obj
endfunction

" args: k: int: 0 => today's, 1 => full
function! bestfriend#dbname(k)
  return a:k ? 'full.db' : strftime('%Y%m%d.db')
endfunction
" }}}

" Object: BestFriend " {{{
let s:BestFriend = {}

function! s:BestFriend.set_db(name) dict
  let self.db = self.data_dir . '/' . a:name
endfunction

function! s:BestFriend.start(f) dict
  if self.is_ignored(a:f)
    return
  endif

  if !self.has_file(a:f)
    call self.add_file(a:f)
  endif

  if self.files[a:f].status == s:START
    return
  endif

  " date might be changed when the file is being edited
  call self.set_db(bestfriend#dbname(0))
  let self.files[a:f].start = reltime()
  let self.files[a:f].status = s:START
  let self.files[a:f].cursor_position = getpos('.')
endfunction

function! s:BestFriend.stop(f) dict
  if !self.has_file(a:f)
    return
  endif

  if self.files[a:f].status == s:STOP
    return
  endif

  let self.files[a:f].end = reltime()

  call self.calc(a:f)
  call self.reset(a:f)
endfunction

function! s:BestFriend.detect_cursor_move(f) dict
  if !self.observe_cursor_position
    return
  endif

  if !self.has_file(a:f)
    return
  endif

  let cur_pos = getpos('.')

  if self.files[a:f].cursor_position == cur_pos
    call self.stop(a:f)
  else
    if self.files[a:f].status == s:STOP
      call self.start(a:f)
    else
      let self.files[a:f].cursor_position = cur_pos
    endif
  endif
endfunction

function! s:BestFriend.has_file(f) dict
  return has_key(self.files, a:f)
endfunction

function! s:BestFriend.add_file(f) dict
  let self.files[a:f] = { 'start': [], 'end': [], 'total': 0, 'status': s:STOP }
endfunction

function! s:BestFriend.reset(f) dict
  let self.files[a:f].start = []
  let self.files[a:f].end = []
  let self.files[a:f].status = s:STOP
endfunction

function! s:BestFriend.get_total(k) dict
  return self.has_file(a:k) ? self.files[a:k].total : 0
endfunction

function! s:BestFriend.remove(f) dict
  call remove(self.files, a:f)
endfunction

function! s:BestFriend.calc(f) dict
  let pass = str2float(reltimestr(reltime(self.files[a:f].start, self.files[a:f].end)))
  let self.files[a:f].total += pass

  if !self.summary.has_file(a:f)
    call self.summary.add_file(a:f)
  endif
  let self.summary.files[a:f].total += pass

  call self.save()
  call self.summary.save()
endfunction

function! s:BestFriend.save() dict
  let files = []
  for [k, v] in items(self.files)
    " call add(files, k)
    let info = {}
    let info[k] = {'total': v.total}
    call add(files, string(info))
  endfor
  call writefile(files, self.db)
endfunction

function! s:BestFriend.load() dict
  if !filereadable(self.db)
    return
  endif

  let files = readfile(self.db)
  for f in files
    for [k, v] in items(eval(f))
      let self.files[k] = v
      call extend(self.files[k], {'start': [], 'end': [], 'status': s:STOP})
    endfor
  endfor
endfunction

" TODO: display into a buffer
" TODO: omit file name if it's better
function! s:BestFriend.show(...) dict
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
        let files[k] = {'total': self.is_sort_base_today ?
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
    let sortedlist = sortedlist[0:self.display_limit - 1]

    let fmt = '%3d: '
    let fmt .= printf('%%-%ds ', s:longest_path_length(sortedlist))
    let fmt .= '%s (%s)'

    let i = 1
    for [k, v] in sortedlist
      let sum = s:format_time(self.summary.files[k].total)
      let today = s:format_time(self.get_total(k))
      " echo printf(fmt, i, s:shorten_path(k), today, sum)

      let i += 1
    endfor
    call self.Buffer.write(sortedlist)
  finally
    call self.start(s:curfile())
  endtry
endfunction

function! s:BestFriend.sort(files) dict
  let list = []

  for [k, v] in items(a:files)
    call add(list, [k, v])
  endfor

  if empty(self.sort_function)
    let self.sort_function = self.sort_by_bestfriend
  endif

  return sort(sort(list), self.sort_function, self)
endfunction

function! s:BestFriend.filter(list)
  let l = filter(a:list, '0.0 < v:val[1].total')
  return filter(l, 'filereadable(v:val[0])')
endfunction

function! s:BestFriend.sort_by_bestfriend(a, b) dict
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

  return r * (self.is_sort_order_desc ? -1 : 1)
endfunction

function! s:BestFriend.sort_by_name(a, b) dict
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

  return r * (self.is_sort_order_desc ? -1 : 1)
endfunction

" returns whether {f} is ignored or not
function! s:BestFriend.is_ignored(f) dict
  if empty(a:f)
    return 1
  endif

  if !getftype(a:f) == 'file'
    return 1
  endif

  if expand(a:f) == self.db
    return 1
  endif

  if !empty(&l:buftype)
    return 1
  endif

  if !empty(self.accept_path_pattern)
    if a:f !~# self.accept_path_pattern
      return 1
    endif
  endif

  if !empty(self.ignore_path_pattern)
    if a:f =~# self.ignore_path_pattern
      return 1
    endif
  endif

  return 0
endfunction
" }}}

" Object BestFriend.Buffer {{{
let s:BestFriend.Buffer = {
      \ 'NAME': '[BestFriend]',
      \ 'sp': 'split',
      \ 'number': -1
\ }

function! s:BestFriend.Buffer.write(data) dict
  let cur_bufnr = bufnr('%')

  call self.open(1)
  call self.focus()

  let width = {'name': 30, 'bar': winwidth(0) }
  let longest = { 'path': a:data[0][0],
                \ 'time': float2nr(floor((a:data[0][1].total / 60)))
  \ }
  let fmt = '%-' . width.name . 's%s'
  " '() ' is time's parenthesis and a whitespace
  let extra_space = s:numberwidth() + &foldcolumn + len('() ')
  let bg = s:BestFriend.Buffer.colours.bar
  let fg = s:BestFriend.Buffer.colours.path

  for [k, v] in a:data
    let min = float2nr(floor(v.total) / 60)
    let rate = (1.0 * min / longest.time)
    let time = s:format_time(v.total)
    let cnt = float2nr((width.bar - len(time) - extra_space) * rate)
    " For syntax highlight, a variable fmt doesn't include time section '(00:00)'
    let line = printf(fmt, k, repeat(nr2char(9), cnt - len(k) - extra_space))

    silent $ put = printf('(%s) ', time) . line
    execute printf('syntax match BFBar%d "%s\ze%s"', cnt, strpart(line, 0, cnt-1), strpart(line, cnt-1))
    execute printf('highlight BFBar%d ctermbg=%s ctermfg=%s guibg=%s guifg=%s', cnt, bg, fg, bg, fg)
  endfor
  execute '0delete'

  call self.syntax()
  call cursor(1, 1)
  execute bufwinnr(cur_bufnr) . 'wincmd w'

  redraw!
endfunction

function! s:BestFriend.Buffer.exist() dict
  return bufexists(self.number)
endfunction

function! s:BestFriend.Buffer.is_open() dict
  return bufwinnr(self.number) != -1
endfunction

function! s:BestFriend.Buffer.open(clear) dict
  if !self.is_open()
    silent execute self.sp
    silent edit `=self.NAME`

    let self.number = bufnr('%')

    setlocal buftype=nofile syntax=bestfriend bufhidden=hide
    setlocal filetype=bestfriend tabstop=1
    setlocal noswapfile nobuflisted
  endif

  if a:clear
    call self.clear()
  endif
endfunction

function! s:BestFriend.Buffer.clear() dict
  let cur_bufwinnr = bufwinnr('%')

  call self.focus()
  execute '%delete _'
  execute cur_bufwinnr . 'wincmd w'
endfunction

function! s:BestFriend.Buffer.focus() dict
  if self.is_open()
    let mybufwinnr = bufwinnr(self.number)
    if mybufwinnr != bufwinnr('%')
      execute mybufwinnr . 'wincmd w'
    endif
  endif
endfunction

function! s:BestFriend.Buffer.syntax()
  let fg = s:BestFriend.Buffer.colours.time
  syntax match BFTime '^(\(\d days\? \)\?\d\{2}:\d\{2})'
  execute printf('highlight BFTime ctermfg=%s cterm=Bold guifg=%s gui=Bold', fg, fg)
endf
" }}}


let s:is_debug = get(g:, 'bestfriend_is_debug', 0)

""
" Initialization etc ...
"
let s:BestFriend.files = {}
let s:BestFriend.db = ''
let s:BestFriend.summary = {}

let s:data_dir = expand(get(g:, 'bestfriend_data_dir', '~/.bestfriend'))
if !isdirectory(s:data_dir)
  call mkdir(s:data_dir, 'p')
endif
let s:BestFriend.data_dir = s:data_dir

" NOTE: files that `accept_path_pattern` - `ignore_path_pattern` are managed
" if both pattern are specified
let s:BestFriend.accept_path_pattern = s:expand_path(get(g:, 'bestfriend_accept_path_pattern', ''))
let s:BestFriend.ignore_path_pattern = s:expand_path(get(g:, 'bestfriend_ignore_path_pattern', ''))

let s:BestFriend.is_display_zero = get(g:, 'bestfriend_is_display_zero', 0)
let s:BestFriend.display_limit = get(g:, 'bestfriend_display_limit', 10)

" sort
let s:sort_functions = filter(keys(s:BestFriend),
      \ 'v:val =~ "^sort_by_" && type(s:BestFriend[v:val]) == type(function("tr"))')

let s:DEFAULT_SORT_METHOD = 'sort_by_bestfriend'
let s:sort_method = get(g:, 'bestfriend_sort_method', s:DEFAULT_SORT_METHOD)
if index(s:sort_functions, s:sort_method) == -1
  let s:sort_method = s:DEFAULT_SORT_METHOD
endif
let s:BestFriend.sort_function = s:BestFriend[s:sort_method]

let s:BestFriend.is_sort_base_today = get(g:, 'bestfriend_is_sort_base_today', 1)
let s:BestFriend.is_sort_order_desc = get(g:, 'bestfriend_is_sort_order_desc', 1)

let s:BestFriend.observe_cursor_position = get(g:, 'bestfriend_observe_cursor_position',
                                                   \ has('gui_running') ? 0 : 1)

let s:BestFriend.Buffer.colours = get(g:, 'bestfriend_highlight_colours',
      \ { 'bar': 'Green', 'path': 'Black', 'time': 'DarkRed' })

let &cpo = s:saved_cpo
unlet s:saved_cpo

"__END__ " {{{
" vim: fen fdm=marker ts=2 sw=2 sts=2

