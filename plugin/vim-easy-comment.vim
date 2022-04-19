"============================================================================
"
"File:        vim-easy-comment.vim
"Author:      Alex Ray <sparrow@disroot.org>
"Version:     1.0.0
"Description: Vim plugin for auto commenting/uncommenting multiple lines
" 	      depending on the given file
" 	      Modified directly from https://github.com/KarimElghamry/vim-auto-comment/blob/master/plugin/vim-auto-comment.vim
"License:     This program is free software. It comes without any warranty,
"             to the extent permitted by applicable law. You can redistribute
"             it and/or modify it under the terms of the Do What The Fuck You
"             Want To Public License, Version 2, as published by Sam Hocevar.
"             See http://sam.zoy.org/wtfpl/COPYING for more details.
"
"============================================================================


" ---------------- COMMON FUNCTIONS ------------------ "

" function to reverse a given string
function! s:ReverseString(input_string)
  let output = ''
  for i in split(a:input_string, '\zs')
    let output = i . output
  endfor
  return output
endfunction

" function to retrieve proper comment character by filetype or extension
function! s:GetCommentChar(set)
  let extension = expand('%:e')
  let ftype = &filetype

  if a:set == 'block'
    let comment = g:default_block_comment
    let collection = g:block_comment_dict
  elseif a:set == 'inline'
    let comment = g:default_inline_comment
    let collection = g:inline_comment_dict
  else
    throw "invalid identifier for comment character collection"
  endif

  " check file extension against each entry in comment dictionary
  for item in items(collection)
    if index(item[1], extension) >= 0 || index(item[1], ftype) >= 0
      let comment = item[0]
      break
    endif
  endfor

  return comment
endfunction

" function to get number of indentation spaces before line content
function! s:GetIndent(str)
  return len(matchstr(a:str, '^\s*'))
endfunction

" Determine if line is empty/comprised of only whitespace
function! s:IsEmpty(line)
  if len(a:line) == 0 || len(matchstr('^\s*$', a:line))
    return 1
  else
    return 0
  endif
endfunction

" function to comment a single line (by line number)
function! s:CommentLine(lnum, char, str, g_indent)
  let res = s:GetIndent(a:str)
  let l_indent = res - a:g_indent
  let before = repeat(" ", a:g_indent)
  let after = repeat(" ", l_indent)
  let newline = substitute(a:str, '.*', before.escape(a:char, s:esc_chrs).' '.after.escape(trim(a:str), s:esc_chrs), "g")
  call setline(a:lnum, newline)
endfunction

" function to un-comment a single line (by line number)
function! s:UnCommentLine(lnum, char, str)
  let indent = repeat(" ", s:GetIndent(a:str))
  let newline = substitute(a:str, '^\s*'.a:char.' ', indent, "g")
  call setline(a:lnum, newline)
endfunction

" determine if a line is already commented with comment character
function! s:IsCommented(char, str)
  if len(matchstr(a:str, '^\s*'.escape(a:char, s:esc_chrs)))
    return 1
  else
    return 0
  endif
endfunction

" Merge two dictionaries, also recursively combining nested keys.
" Otherwise 'override' takes priority.
"  function! s:DictMerge(defaults, override) abort
"    let l:new = a:defaults
"    for [l:k, l:v] in items(a:override)
"      if type(get(l:new, l:k)) is v:t_dict && type(l:v) is v:t_dict
"        call DictMerge(l:new[l:k], l:v)
"      else
"        let l:new[l:k] = l:v
"      endif
"    endfor
"    return l:new
"  endfunction

" Override any filetypes with user-defined values from a dict where
" type(value) == v:t_list by exploding and reconstructing the dictionary
function! s:MergeCommentDict(defaults, user_specified) abort
  let tmp = {}
  for dct in [a:defaults, a:user_specified]
    for [dk, dv] in items(dct)
      for val in dv  " should be a list value
        let tmp[val] = dk
      endfor
    endfor
  endfor
  let new = {}
  for [k, v] in items(tmp)
    if !has_key(new, v)
      let new[v] = []
    endif
    call add(new[v], k)
  endfor
  return new
endfunction


" ---------------- GLOBAL VARIABLES ------------------ "

" dictionary for mapping inline comment tokens to the corresponding files
let s:default_inline_dict = {
		\ '//': ["js", "javascript", "ts", "typescript", "cpp", "c", "dart"],
		\ '#': ["py", "python", "sh", "zsh"],
		\ '" ': ["vim"],
		\ }
if exists('g:inline_comment_dict')
  let g:inline_comment_dict = s:MergeCommentDict(s:default_inline_dict, g:inline_comment_dict)
else
  let g:inline_comment_dict = s:default_inline_dict
endif

" variable for setting the default inlink comment token if the current file is
" not found in the dictionary
let g:default_inline_comment = '#'

" dictionary for mapping block comment tokens to the corresponding files
let s:default_block_dict = {
		\ '/*': ["js", "javascript", "ts", "typescript", "cpp", "c", "dart"],
		\ '"""': ["py", "python"],
		\ }
if exists('g:block_comment_dict')
  let g:block_comment_dict = s:MergeCommentDict(s:default_block_dict, g:block_comment_dict)
else
  let g:block_comment_dict = s:default_block_dict
endif

" variable for setting the default block comment token if the current file is
" not found in the dictionary
let g:default_block_comment = '/*'

" Escape these characters when substituting comment content in `setline`
let s:esc_chrs = '^$.*?/\[]|&='


" -------------- INLINE COMMENTING -----------------"

" call CommentLine or UncommentLine for a single line
function! s:AutoInlineCommentSingle()
  " Single (normal) mode line commenting
  let line = getline('.')
  let line_no = line('.')
  let comment_char = s:GetCommentChar('inline')
  let indent = s:GetIndent(line)
  if s:IsEmpty(line)
    :
  elseif s:IsCommented(comment_char, line)
    call s:UnCommentLine(line_no, comment_char, line)
  else
    call s:CommentLine(line_no, comment_char, line, indent)
  endif
endfunction

" call CommentLine or UncommentLine for multiple lines in Visual mode
function! s:AutoInlineCommentMultiple() range
  " For visual mode selection commenting multiple lines
  let lines = getline(a:firstline, a:lastline)
  let g_indent = s:GetIndent(lines[0])
  let comment_char = s:GetCommentChar('inline')
  for i in range(a:firstline, a:lastline)
    let line = getline(i)
    if s:IsEmpty(line)
      continue
    " only UN-comment if first or last line has a comment character
    elseif s:IsCommented(comment_char, lines[0]) || s:IsCommented(comment_char, lines[-1])
      call s:UnCommentLine(i, comment_char, line)
    else
      call s:CommentLine(i, comment_char, line, g_indent)
    endif
  endfor
endfunction



" ------------- BLOCK COMMENTING -------------- "

" Determine whether or not to comment or uncomment a block of visually selected text
function! s:AutoBlockCommentMultiple() range abort
  let comment_char = s:GetCommentChar('block')
  let reverse_comment_char = s:ReverseString(comment_char)
  let first_str = getline(a:firstline)
  let last_str = getline(a:lastline)
  let dif = a:lastline-a:firstline
  if dif == 0
    "  single line to comment out
    call s:AutoBlockCommentSingle()
    return 0
  endif

  if s:IsCommented(comment_char, first_str) && len(matchstr(last_str, reverse_comment_char.'$'))
    call s:UnCommentLine(a:firstline, comment_char, first_str)
    let new_lastline = substitute(last_str, ' '.reverse_comment_char.'$', '', "g")
    call setline(a:lastline, new_lastline)
  else
    let indent = s:GetIndent(first_str)
    if s:IsEmpty(first_str)
      call setline(a:firstline, repeat(' ', indent).comment_char)
    else
      call s:CommentLine(a:firstline, comment_char, first_str, indent)
    endif

    if s:IsEmpty(last_str)
      call setline(a:lastline, repeat(' ', indent).reverse_comment_char)
    else
      let new_lastline = substitute(last_str, '$', ' '.reverse_comment_char, "g")
      call setline(a:lastline, new_lastline)
    endif
  endif

endfunction

" Comment or un-comment a single line of text using block comment method
function! s:AutoBlockCommentSingle() abort
  let line = getline('.')
  let line_no = line('.')
  if !len(line) || len(matchstr(line, '^\s*$'))
      :
  else
    let indent = s:GetIndent(line)
    let char = s:GetCommentChar('block')
    let rev_char = s:ReverseString(char)
    let commented = matchstr(line, '^\s*'.escape(char, s:esc_chrs).'.*'.escape(rev_char, s:esc_chrs).'$')
    if len(commented)
      call setline(line_no, substitute(line, '\('.char.'\s\|\s'.rev_char.'$\)', '', "g"))
    else
      let l:newline = repeat(' ', indent).char.' '.trim(line).' '.rev_char
      call setline(line_no, l:newline)
    endif
  endif
endfunction



" ------------- DEFINE COMMANDS --------------- "

command! -nargs=0 AutoInlineCommentSingle call <SID>AutoInlineCommentSingle()
command! -range AutoInlineCommentMultiple <line1>,<line2>call <SID>AutoInlineCommentMultiple()
command! -nargs=0 AutoBlockCommentSingle call <SID>AutoBlockCommentSingle()
command! -range AutoBlockCommentMultiple <line1>,<line2>call <SID>AutoBlockCommentMultiple()




" ----------- DEFINE DEFAULT MAPPINGS --------- "

if !exists('g:autocomment_map_keys')
    let g:autocomment_map_keys = 1
endif

if (g:autocomment_map_keys)
  " Inline comment mapping
  vnoremap <silent><C-/> :AutoInlineCommentMultiple<CR>
  nnoremap <silent><C-/> :AutoInlineCommentSingle<CR>

  " Block comment mapping
  vnoremap <silent><C-S-?> :AutoBlockCommentMultiple<CR>
  nnoremap <silent><C-S-?> :AutoBlockCommentSingle<CR>
endif

