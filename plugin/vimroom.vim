" Vim's full screen mode is great, but it has nothing on WriteRoom [1]. This
" plugin is a tribute to a great Mac app. See README.mkd for details.
"
" [1] http://www.hogbaysoftware.com/products/writeroom
" TODO: use this tip to set a custom font: set guifont=* -- brings up a font
" dialog in gvim! check if has('gui') first

" no point loading the plugin in the console
if has("gui_running") == 0
  "echomsg("VimRoom only runs in the gui")
  finish
endif

" The VimRoom colorscheme -- the default one is a tribute to WriteRoom
let g:VimRoom_Colorscheme = "VimRoom"

" mutually exclusive with lines -- takes precedence
let g:VimRoom_MaxLines = 0

" mutually exclusive with columns -- takes precedence
let g:VimRoom_MaxColumns = 0

let g:VimRoom_CentreCursor = 1

let g:VimRoom_HideLineNumbers = 0

" mutually exclusive with maxcolumns
let g:VimRoom_Columns = 80

" mutually exclusive with maxlines
let g:VimRoom_Lines = 60

let g:VimRoom_ShowWordCount = 1

let g:VimRoom_ShowLineCount = 1

let g:VimRoom_ShowCharCount = 1

" mutually exclusive with ZoomLevel -- takes precedence
let g:VimRoom_FullScreenFont = ""

" for each zoom level, the font size will increase or decrease by 1 point
" mutally exclusive with FullScreenFont
let g:VimRoom_ZoomLevel = -1

let g:VimRoom_HighlightCursorLine = 0

let g:VimRoom_BlinkCursor = 1

let g:VimRoom_ShowStatusLine = 1

" settings (overriding not recommended) {{{
" Wrap the page
let g:VimRoom_Wrap = 1

" Show the bottom scrollbar
let g:VimRoom_HideBottomScrollbar = 1

" Show the left scrollbar
let g:VimRoom_HideLeftScrollbar = 1

" Show the below right scrollbar
let g:VimRoom_HideRightScrollbar = 1

" Close all open tabs. Don't worry, your buffers will remain (in hidden mode).
let g:VimRoom_CloseTabs = 1

" Close all windows. Don't worry, your buffers will remain (in hidden mode).
let g:VimRoom_CloseWindows = 1
" }}}

" menus {{{
amenu <silent> Plugin.VimRoom.Toggle\ Full\ Screen\ Mode<Tab> :call VimRoomToggle()<cr>
" }}}

" mappings {{{
if has("gui_macvim")
  " TODO: figure out why the key can't be changed. until then, just disable it.
  "macmenu Window.Toggle\ Full\ Screen\ Mode key=<D-e>
  menu disable Window.Toggle\ Full\ Screen\ Mode
  macmenu Plugin.VimRoom.Toggle\ Full\ Screen\ Mode key=<D-S-f>
  nnoremap <silent> <D-C-f> :call VimRoomStatusToggle()<cr>
else
  nnoremap <leader>r :call VimRoomToggle()<cr>
  nnoremap <silent> <leader>R :call VimRoomStatusToggle()<cr>
endif
" }}}

" functions! {{{
function! VimRoomToggle()
  if !exists("s:VimRoom_Enabled")
    call s:ShowFullScreen()
  else
    call s:HideFullScreen()
  endif
endfunction

" back up all the previous settings wholesale (for simplicity)
function! s:BackupOldSettings()
  let s:OldSettings = {
    \  "colorscheme": s:GetCommandOutput("colorscheme"),
    \  "guifont": "\"" . &guifont . "\"",
    \  "lines": &lines,
    \  "columns": &columns,
    \  "scrolloff": &scrolloff,
    \  "number": &number,
    \  "relativenumber": &relativenumber,
    \  "wrap": &wrap,
    \  "statusline": "\"" . &statusline . "\"",
    \  "guioptions": "\"" . &guioptions . "\"",
    \  "hidden": &hidden,
    \  "fuoptions": "\"" . &fuoptions . "\"",
    \  "cursorline": &cursorline,
    \  "guicursor": "\"" . &guicursor . "\"",
    \  "cmdheight": "\"" . &cmdheight . "\"",
    \  "updatetime": "\"" . &updatetime . "\""
  \}
endfunction

function! s:RestoreOldSettings()
  for [key, value] in items(s:OldSettings)
    if match(key, "colorscheme") > -1
      "echomsg("-" . value . "!!!!" . "-")
      " TODO: fix this hack. for some reason, a null byte (^@) is prepended to
      " the colorscheme string -- skip it.
      execute "colorscheme " . strpart(value, 1, len(value)-1)
    else
      execute "let &" . key . " = " . value
    endif
  endfor
  unlet s:OldSettings
endfunction

" TODO: clean up this code
function! s:ShowFullScreen()
  if !exists("s:VimRoom_Enabled")
    let s:VimRoom_Enabled = 1

    call s:BackupOldSettings()

    " get the initial file stats
    call s:UpdateFileStats()

    " the rate at which to update the statusline, and how long to keep it open
    set updatetime=1000

    if g:VimRoom_CloseTabs == 1
      if &hidden != 1
        set hidden
      endif
      silent tabonly
    endif

    if g:VimRoom_CloseWindows == 1
      if &hidden != 1
        set hidden
      endif
      silent only
    endif

    if g:VimRoom_Wrap == 1
      set wrap
    endif

    if g:VimRoom_CentreCursor
      "set s:old_scrolloff = &scrolloff
      set scrolloff=999
    endif

    " TODO: test (all other options too)
    if g:VimRoom_HideLineNumbers == 0
      if &number == 1
        set nonumber
      elseif v:version > 702 && &relativenumber == 1
        set norelativenumber
      endif
    endif

    if g:VimRoom_ShowStatusLine == 1
      call s:ShowStatus()
    else
      set statusline=\ 
    endif

    if g:VimRoom_BlinkCursor == 1
      " enable with default values in case it's disabled by the user
      set guicursor-=a:blinkon0
      set guicursor+=sm:blinkwait700-blinkon400-blinkoff250
    else
      set guicursor+=a:blinkon0
    endif

    if g:VimRoom_HideLeftScrollbar == 1
      set guioptions-=L
    endif

    if g:VimRoom_HideRightScrollbar == 1
      set guioptions-=r
    endif

    if g:VimRoom_HideBottomScrollbar == 1
      set guioptions-=b
    endif

    if g:VimRoom_HighlightCursorLine == 1 && &cursorline != 1
      let s:old_cursor = &cursorline
      set cursorline
    else
      set nocursorline
    endif

    " set the full screen colorscheme
    exec "colorscheme " . g:VimRoom_Colorscheme

    if g:VimRoom_FullScreenFont != ""
      let &guifont = g:VimRoom_FullScreenFont
    else
      call s:Zoom(g:VimRoom_ZoomLevel)
    endif

    " now configure full screen options

    " copy the selected colorscheme's background (the 'Normal' highlight group)
    set fuoptions=background:Normal

    if g:VimRoom_MaxLines == 1
      set fuoptions+=maxvert
    elseif g:VimRoom_Lines > 0
      let &lines = g:VimRoom_Lines
    endif

    if g:VimRoom_MaxColumns == 1
      set fuoptions+=maxhorz
    elseif g:VimRoom_Columns > 0
      let &columns = g:VimRoom_Columns
    endif

    " use the minimum size for the command line
    set cmdheight=1

    " finally, invoke full screen mode
    set fullscreen
  endif
endfunction

function! s:HideFullScreen()
  if exists("s:VimRoom_Enabled")
    unlet s:VimRoom_Enabled
    call s:HideStatus(1)
    call s:RestoreOldSettings()
    set nofullscreen
  endif
endfunction

function! s:UpdateFileStats()
  if exists("s:VimRoom_Enabled")
    let g:VimRoom_WordCount = 0
    let g:VimRoom_CharCount = 0
    let g:VimRoom_LineCount = 0

    " if we're in insert mode, we want to go right (l) to compensate for the
    " stupid escape mode
    "normal l

    " the cursor jumps in insert mode. let's fix that.
    let l:CursorPos = getpos(".")

    " get vim's file stats
    let l:VimStats = s:GetCommandOutput("normal g\<C-g>")

    " now go back to the previous column
    call setpos(".", [0, line("."), l:CursorPos[2], 0])

    try
      let g:VimRoom_WordCount = str2nr(split(l:VimStats)[11])
      let g:VimRoom_CharCount = str2nr(split(l:VimStats)[15])
      let g:VimRoom_LineCount = str2nr(split(l:VimStats)[7])
    catch
      " we don't care if this fails...yet
    endtry
  endif
endfunction

function! VimRoomStatusToggle()
  if !exists("s:VimRoom_StatusEnabled")
    call s:ShowStatus()
  else
    call s:HideStatus(0)
  endif
endfunction

function! s:ShowStatus()
  if !exists("s:VimRoom_StatusEnabled")
    let s:VimRoom_StatusEnabled = 1

    set statusline=♦\ %f

    if g:VimRoom_ShowCharCount == 1 || g:VimRoom_ShowWordCount == 1 || g:VimRoom_ShowLineCount == 1
      let l:StatusMeta = 1
    endif

    if exists("l:StatusMeta")
      set statusline+=\ \(
    endif

    set statusline+=%{GetFileStats()}

    if exists("l:StatusMeta")
      set statusline+=\)
    endif
  endif
endfunction

function! s:HideStatus(force)
  if exists("s:VimRoom_StatusEnabled")
    if g:VimRoom_ShowStatusLine == 0 || a:force == 1
      unlet s:VimRoom_StatusEnabled
      set statusline=\ 
    endif
  endif
endfunction

" TODO: figure out if there's a way to make this s:GetFileStats
function! GetFileStats()
  let l:FileStats = ""

  if g:VimRoom_ShowCharCount == 1
    let l:FileStats .= g:VimRoom_CharCount . "\ characters\ "
  endif

  if g:VimRoom_ShowWordCount == 1
    let l:FileStats .= g:VimRoom_WordCount . "\ words\ "
  endif

  if g:VimRoom_ShowLineCount == 1
    let l:FileStats .= g:VimRoom_LineCount . "\ lines\ "
  endif

  " trim potential left space
  let l:FileStats = substitute(l:FileStats,"\\s$", "", "g")

  return l:FileStats
endfunction

function! s:Zoom(level)
  if has("gui_running")
    let &guifont = substitute(&guifont, ":h\\zs\\d\\+", "\\=eval(submatch(0)+" . str2nr(a:level) . ")", "")
  endif
endfunction

function! s:GetCommandOutput(command)
  redir => l:Output
    silent execute a:command
  redir END

  " strip any whitespace
  return substitute(l:Output, "^\s*\(.\{-}\)\s*$", "\1", "")
endfunction
" }}}

" autocmds {{{
augroup FileStatCounter
  autocmd! CursorHold * call s:UpdateFileStats() | call s:HideStatus(0)
  autocmd! CursorHoldI * call s:UpdateFileStats() | call s:HideStatus(0)
augroup END
" }}}

