" Has this already been loaded?
if exists("vloaded_tree_explorer") && !exists("g:treeExplDebug")
	finish
endif
let vloaded_tree_explorer=1

" TODO - set foldopen option

" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

" explorer window is created with vertical split if needed
let s:treeExplVertical = (exists("g:treeExplVertical")) ? g:treeExplVertical : 0

" explorer windows initial size
let s:treeExplWinSize = (exists("g:treeExplWinSize")) ? g:treeExplWinSize : 20

" Create commands
command! -n=? -complete=dir VTreeExplore :call s:TreeExplorer(0, '<a>')
command! -n=? -complete=dir VSTreeExplore :call s:TreeExplorer(1, '<a>')

" Start the explorer using the preferences from the global variables
function! s:TreeExplorer(split, start_dir) " <<<
	if a:start_dir != ""
		let fname=a:start_dir
	else
		let fname = expand("%:p:h")
	endif
	if fname == ""
		let fname = getcwd()
	endif

	" Create a variable to use if splitting vertically
	let splitMode = ""
	if s:treeExplVertical == 1
		let splitMode = "vertical"
	endif

	if a:split || &modified
		let cmd = splitMode . " " . s:treeExplWinSize . "new TreeExplorer"
	else
		let cmd = "e TreeExplorer"
	endif
	silent execute cmd

	" show hidden files
	let w:hidden_files = (exists("g:treeExplHidden")) ? 1 : 0

	setlocal noswapfile
	setlocal buftype=nowrite
	setlocal bufhidden=delete
	setlocal nowrap

	iabc <buffer>

	"let w:longhelp = 1
	let w:helplines = 4 " so we get long help to start

	setlocal foldmethod=marker
	setlocal foldtext=substitute(getline(v:foldstart),'.{{{.*','','')
	setlocal foldlevel=1

  " Set up syntax highlighting
  if has("syntax") && exists("g:syntax_on") && !has("syntax_items")
    syn match treeSynopsis    #^"[ -].*#
    syn match treeDirectory   #\(^[^"][-| `]*\)\@<=[^-| `].*/#
    syn match treeDirectory   "^\.\. (up a directory)$"
		syn match treeParts       #!-- #
		syn match treeParts       #`-- #
		syn match treeParts       #!   #
    syn match treeCurDir      #^/.*$# contains=treeFolds
		syn match treeFolds       "{{{"
		syn match treeFolds       "}}}"
		syn match treeClass "[*=|]$" contained
		" TODO - fix these
		syn match treeExec  #\(^[^"][-| `]*\)\@<=[^-| `].*\*$# contains=treeClass
		syn match treePipe  #\(^[^"][-| `]*\)\@<=[^-| `].*|$# contains=treeClass
		syn match treeSock  #\(^[^"][-| `]*\)\@<=[^-| `].*=$# contains=treeClass
		syn match treeLink  #[^-| `].* -> .*$# contains=treeFolds,treeParts
		"syn match treeLink  #.* -> .*$# contains=treeFolds

		hi def link treeParts       Normal

		hi def link treeFolds       Ignore
		hi def link treeClass       Ignore

    hi def link treeSynopsis    Special
    hi def link treeDirectory   Directory
    hi def link treeCurDir      Statement

		hi def link treeExec        Type
		hi def link treeLink        Title
		hi def link treePipe        String
		hi def link treesock        Identifier

  endif

	" set up mapping for this buffer
  let cpo_save = &cpo
  set cpo&vim
  nnoremap <buffer> <cr> :call <SID>Activate()<cr>
  nnoremap <buffer> o    :call <SID>Activate()<cr>
	nnoremap <buffer> E    :call <SID>RecursiveExpand()<cr>
  nnoremap <buffer> C    :call <SID>ChangeTop()<cr>
  nnoremap <buffer> H    :call <SID>InitWithDir($HOME)<cr>
	nnoremap <buffer> u    :call <SID>ChdirUp()<cr>
	nnoremap <buffer> p    :call <SID>MoveParent()<cr>
	nnoremap <buffer> r    :call <SID>RefreshDir()<cr>
  nnoremap <buffer> R    :call <SID>InitWithDir("")<cr>
	nnoremap <buffer> a    :call <SID>ToggleHiddenFiles()<cr>
	nnoremap <buffer> S    :call <SID>StartShell()<cr>
  nnoremap <buffer> ?    :call <SID>ToggleHelp()<cr>
	nnoremap <buffer> t    :call <SID>Test()<cr>
  let &cpo = cpo_save

	call s:InitWithDir(fname)
endfunction " >>>

" reload tree with dir
function! s:InitWithDir(dir) " <<<
	if a:dir != ""
		execute "lcd " . escape (a:dir, ' ')
	endif
	let cwd = getcwd ()

	setlocal modifiable

	silent normal ggdG

	"insert header
	call s:AddHeader()
	normal G

	let save_f=@f

	"insert parent dir
	if cwd != "/"
		let @f=".. (up a directory)\n"
	else
		let @f="\n"
	endif
	silent put f

	normal G

	call s:ReadDir (cwd, "")

	let @f = "\n"
	normal G
	silent put f
	let @f=save_f

	exec (":" . w:helplines)

	setlocal nomodifiable
endfunction " >>>

" read contents of dir after current line with tree pieces and foldmarkers
function! s:ReadDir(dir, prevline) " <<<
	let olddir = getcwd ()
	execute "lcd " . escape (a:dir, ' ')

	let save_f = @f

	let topdir = a:dir

	"let topdir = substitute (topdir, '/\?$', '/', "")
	"let topdir = substitute (topdir, '\\\?/\?$', '/', "")
	if has("unix") == 0 " TODO - other non unix besides dos*?
		let topdir = substitute (topdir, '\\', '/', "g")
	endif
	let topdir = substitute (topdir, '/\?$', '/', "")
	
	if w:hidden_files == 1
		let dirlines = glob ('.*') . "\n" . glob ('*')
	else
		let dirlines = glob ('*')
	endif

	if dirlines == ""
		let @f = (a:prevline == "") ? topdir : a:prevline
		silent put f
		let @f = save_f
		execute "lcd " . escape (olddir, ' ')
		return
	endif


	if a:prevline != ""
		let treeprt = substitute (a:prevline, '[^-| `].*', "", "")
		let prevdir = substitute (a:prevline, '^[-| `]*', "", "")
		let prevdir = substitute (prevdir, '[{} ]*$', "", "")
		let foldprt = substitute (a:prevline, '.*' . prevdir, "", "")

		let @f = treeprt . prevdir . ' {{{'

		let treeprt = substitute (treeprt, '`-- ', '    ', "")
		let treeprt = substitute (treeprt, '|-- ', '|   ', "")
	else
		let treeprt = ""
		let prevdir = ""
		let foldprt = ""
		let @f = topdir . ' {{{'
	endif

	let dirlines = substitute (dirlines, "\n", '|', "g")

	while dirlines =~ '|'
		let curdir = substitute (dirlines, '|.*', "", "")
		let dirlines = substitute (dirlines, '[^|]*|\?', "", "")

		if w:hidden_files == 1 && curdir =~ '^\.\.\?$'
			continue
		endif

		let linkedto = resolve (curdir)
		if linkedto != curdir
			let curdir = curdir . ' -> ' . linkedto
		endif
		if isdirectory (linkedto)
			let curdir = curdir . '/'
		"elseif executable ('./' . curdir)
			" this is really slow, wish there was a -x operator or stat()
			"let curdir = curdir . '*'
		endif

		let @f = @f . "\n" . treeprt . '|-- ' . curdir
	endwhile

	if isdirectory (dirlines)
		let dirlines = dirlines . '/'
	endif

	let @f = @f . "\n" . treeprt . '`-- ' . dirlines . foldprt . " }}}\n"

	silent put f

	let @f = save_f
	execute "lcd " . escape (olddir, ' ')
endfunction " >>>

" cd up (if possible)
function! s:ChdirUp() " <<<
	if getcwd() == "/"
		echo "already at top dir"
	else
		call s:InitWithDir("..")
	endif
endfunction " >>>

" move cursor to parent dir
function! s:MoveParent() " <<<
	let ln = line(".")
	call s:GetAbsPath2 (ln, 1)
	if w:firstdirline != 0
		exec (":" . w:firstdirline)
	else
		exec (":" . w:helplines)
	endif
endfunction " >>>

" change top dir
function! s:ChangeTop() " <<<
	let ln = line(".")
  let l = getline(ln)

	" on current top or non-tree line?
	if l =~ '^/' || l =~ '^$' || l =~ '^"'
		return
	endif

	" parent dir
	if l =~ '^\.\. '
		call s:ChdirUp()
		return
	endif

	let curfile = s:GetAbsPath2(ln, 0)
	if curfile !~ '/$'
		let curfile = substitute (curfile, '[^/]*$', "", "")
	endif
	call s:InitWithDir (curfile)

endfunction " >>>

" expand recursively
function! s:RecursiveExpand() " <<<
	setlocal modifiable

	echo "recursively expanding, this might take a while (<C-C>) to stop"

	let curfile = s:GetAbsPath2(line("."), 0)

	if w:firstdirline == 0
		let init_ln = w:helplines
		let curfile = substitute (getline (init_ln), '[ {]*', "", "")
	else
		let init_ln = w:firstdirline
	endif

	let init_ind = match (getline (init_ln), '[^-| `]') / 4

	let curfile = substitute (curfile, '[^/]*$', "", "")

	let l = getline (init_ln)

	if l =~ ' {{{$'
		if foldclosed (init_ln) != -1
			foldopen
		endif
	endif

	if l !~ ' {{{$' " dir not open
		exec (":" . init_ln)
		normal ddk
		call s:ReadDir (curfile, l)
		if getline (init_ln) !~ ' {{{$' " dir still not open (empty)
			setlocal nomodifiable
			echo "expansion done"
			return
		else
			if foldclosed (init_ln) != -1
				foldopen
			endif
		endif
	endif

	let ln = init_ln + 1

	let l = getline (ln)

	while init_ind < (match (l, '[^-| `]') / 4)
		"normal j
		let tl = l
		let tln = ln
		let ln = ln + 1
		let l = getline (ln)

		if tl =~ ' {{{$'
			if foldclosed (tln) != -1
				foldopen
			endif
			continue
		endif

		" link or non dir
		if tl =~ ' -> ' || tl !~ '/[ }]*$'
			continue
		endif

		let curfile = s:GetAbsPath2(tln, 0)

		exec (":" . tln)
		normal ddk
		call s:ReadDir (curfile, tl)
		exec (":" . tln)
		if getline(tln) =~ ' {{{$' && foldclosed (tln) != -1
			foldopen
		endif
		let l = getline (ln)
	endwhile

	setlocal nomodifiable
	exec (":" . init_ln)
	echo "expansion done"
endfunction " >>>

" open dir, file, or parent dir
function! s:Activate() " <<<
	let ln = line(".")
  let l = getline(ln)

	" parent dir, change to it
  if l =~ '^\.\. (up a directory)$'
		call s:ChdirUp()
    return
  endif

	" directory, loaded, toggle folded state
	if l =~ ' {{{$'
		if foldclosed(ln) == -1
			foldclose
		else
			foldopen
		endif
		return
	endif

	" on top, no folds
	if l =~ '^/'
		return
	endif

	" get path of line
	let curfile = s:GetAbsPath2 (ln, 0)

	if curfile =~ '/$' " dir
		setlocal modifiable
		normal ddk
	  call s:ReadDir (curfile, l)
		setlocal nomodifiable
		exec (":" . ln)

		if getline(ln) =~ ' {{{$' && foldclosed(ln) != -1
				foldopen
		endif
		return
	else " file
		let f = escape (curfile, ' ')
		let oldwin = winnr()
		wincmd p
		if oldwin == winnr() || &modified
			wincmd p
			exec ("new " . f)
		else
			exec ("edit " . f)
		endif
	endif
endfunction " >>>

function! s:Test()
	let ln = line(".")
	let curfile  = s:GetAbsPath2(ln, 0)
	let ln2 = w:firstdirline
	let curfile2 = s:GetAbsPath2(ln, 1)
	let ln3 = w:firstdirline
	"echo "0 opt: " . curfile . ", " . ln2 . "; 1 opt " . curfile2 . ", " . ln3
	echo "foldclosed " . ln . " = " . foldclosed (ln) . ", " . ln2 . " = " .  foldclosed (ln2)
endfunction

" refresh curren dir
function! s:RefreshDir()
	let curfile = s:GetAbsPath2(line("."), 0)

	let init_ln = w:firstdirline

	" not in tree, or on path line or parent is top
	if curfile == "" || init_ln == 0
		call s:InitWithDir("")
		return
	endif

	" remove file name, if any
	let curfile = substitute (curfile, '[^/]*$', "", "")

	let l = getline (init_ln)

	set modifiable

	" if there is no fold, just do normal ReadDir, and return
	if l !~ ' {{{'
		exec (":" . init_ln)
		normal ddk
		call s:ReadDir (curfile, l)
		if getline (init_ln) =~ ' {{{$' && foldclosed (init_ln) != -1
			foldopen
		endif
		set nomodifiable
		return
	endif

	" TODO factor
	if foldclosed(init_ln) == -1
		foldclose
	endif

	" remove one foldlevel from line
	let l = substitute (l, ' {{{$', "", "")

	exec (":" . init_ln)
	normal ddk
	call s:ReadDir (curfile, l)
	if getline (init_ln) =~ ' {{{$' && foldclosed (init_ln) != -1
		foldopen
	endif

	set nomodifiable
endfunction

" toggle hidden files
function! s:ToggleHiddenFiles() " <<<
	let w:hidden_files = w:hidden_files ? 0 : 1
	let hiddenStr = w:hidden_files ? "on" : "off"
	let hiddenStr = "hidden files now " . hiddenStr
	echo hiddenStr
	call s:RefreshDir()
endfunction " >>>

" start shell in dir
function! s:StartShell() " <<<
	let ln = line(".")

	let curfile = s:GetAbsPath2 (ln, 1)
	let prevdir = getcwd()

	if w:firstdirline == 0
		let dir = prevdir
	else
		let dir = substitute (curfile, '[^/]*$', "", "")
	endif

	execute "lcd " . escape (dir, ' ')
	shell
	execute "lcd " . escape (prevdir, ' ')
endfunction " >>>

" get absolute parent path of file or dir in line ln, set w:firstdirline
function! s:GetAbsPath2(ln,ignore_current) " <<<
	let lnum = a:ln
	let l = getline(lnum)

	let w:firstdirline = 0

	" in case called from outside the tree
	if l =~ '^[/".]' || l =~ '^$'
		return ""
	endif

	let wasdir = 0

	" strip file
	let curfile = substitute (l,'^[-| `]*',"","") " remove tree parts
	let curfile = substitute (curfile,'[ {}]*$',"",'') " remove fold marks
	let curfile = substitute (curfile,'[*=@|]$',"","") " remove file class

	if curfile =~ '/$' && a:ignore_current == 0
		let wasdir = 1
		let w:firstdirline = lnum
	endif

	let curfile = substitute (curfile,' -> .*',"","") " remove link to
	if wasdir == 1
		let curfile = substitute (curfile, '/\?$', '/', "")
	endif

	let indent = match(l,'[^-| `]') / 4
	let dir = ""
	while lnum > 0
		let lnum = lnum - 1
		let lp = getline(lnum)
		if lp =~ '^/'
			let sd = substitute (lp, '[ {]*$', "", "")
			let dir = sd . dir
			break
		endif
		if lp =~ ' {{{$'
			let lpindent = match(lp,'[^-| `]') / 4
			if lpindent < indent
				if w:firstdirline == 0
					let w:firstdirline = lnum
				endif
				let indent = indent - 1
				let sd = substitute (lp, '^[-| `]*',"","") " rm tree parts
				let sd = substitute (sd, '[ {}]*$', "", "") " rm foldmarks
				let sd = substitute (sd, ' -> .*','/',"") " replace link to with /
				let dir = sd . dir
				continue
			endif
		endif
	endwhile
	let curfile = dir . curfile
	return curfile
endfunction " >>>

" toggle between long and short help
function! s:ToggleHelp() " <<<
	if exists ("w:helplines") && w:helplines <= 4
		let w:helplines = 15
	else
		let w:helplines = 4
	endif
	setlocal modifiable
	call s:UpdateHeader ()
	setlocal nomodifiable
endfunction " >>>

" Update the header
function! s:UpdateHeader() " <<<
	let oldRep=&report
	set report=10000
	" Save position
	normal! mt
  " Remove old header
  0
  1,/^" ?/ d _
  " Add new header
  call s:AddHeader()
  " Go back where we came from if possible
  0
  if line("'t") != 0
    normal! `t
  endif

  let &report=oldRep
  setlocal nomodified
endfunction " >>>

" Add the header with help information
function! s:AddHeader() " <<<
    let save_f=@f
    1
		let ln = 3
		if w:helplines > 4
      let ln=ln+1 | let @f=     "\" <enter> : same as 'o' below\n"
      let ln=ln+1 | let @f=@f . "\" o : (file) open in previous or new window\n"
      let ln=ln+1 | let @f=@f . "\" o : (dir) toggle dir fold or load dir\n"
			let ln=ln+1 | let @f=@f . "\" E : expand (recursive) dirs below cursor dir\n"
			let ln=ln+1 | let @f=@f . "\" C : chdir - make cursor dir top of the tree\n"
			let ln=ln+1 | let @f=@f . "\" H : chdir to home dir\n"
			let ln=ln+1 | let @f=@f . "\" u : chdir to parent dir\n"
			let ln=ln+1 | let @f=@f . "\" p : move cursor to parent dir\n"
			let ln=ln+1 | let @f=@f . "\" r : refresh cursor dir\n"
			let ln=ln+1 | let @f=@f . "\" R : refresh top dir\n"
			let ln=ln+1 | let @f=@f . "\" a : toggle hidden file display\n"
			let ln=ln+1 | let @f=@f . "\" S : start a shell in cursor dir\n"
			let ln=ln+1 | let @f=@f . "\" ? : toggle long help\n"
		else
			let ln=ln+1 | let @f="\" ? : toggle long help\n"
		endif
		let w:helplines = ln
    silent put! f
    let @f=save_f
endfunction " >>>

" vim: set ts=2 sw=2 foldmethod=marker foldmarker=<<<,>>> foldlevel=2 :
