" InnerFragmentComplete.vim: Insert mode completion based on fragments inside words.
"
" DEPENDENCIES:
"   - CompleteHelper.vim autoload script, version 1.32 or higher
"   - Complete/Repeat.vim autoload script
"   - CamelCaseComplete plugin (optional)
"
" Copyright: (C) 2013-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.10.005	04-Apr-2014	ENH: Also match from the start of a
"				CamelCaseWord without a base prefix. But then,
"				there must be additional (unmatched) fragments
"				after the match to avoid overlap with the
"				CamelCaseComplete completion.
"   1.10.004	02-Apr-2014	ENH: When the completion base is prefixed by a
"				fragment (e.g. "my" in "myFoo"), also offer full
"				keyword / CamelCaseWord matches, not just inner
"				fragments, as the default completion /
"				CamelCaseComplete would not use that base, yet
"				it is helpful when completing "myFooBar" from
"				"FooBar".
"   1.00.003	18-Dec-2013	Also offer following fragments, not just
"				keywords after non-keywords, when repeating
"				after a CamelCase completion.
"	002	02-Oct-2013	Implement integration with CamelCaseComplete
"				plugin.
"	001	01-Oct-2013	file creation
let s:save_cpo = &cpo
set cpo&vim

function! s:HasCamelCaseComplete()
    return (exists('g:loaded_CamelCaseComplete') && g:loaded_CamelCaseComplete)
endfunction
function! s:GetCompleteOption()
    return (exists('b:InnerFragmentComplete_complete') ? b:InnerFragmentComplete_complete : g:InnerFragmentComplete_complete)
endfunction

function! InnerFragmentComplete#UpperCase( matchText )
    return substitute(a:matchText, '^\l', '\u&', '')
endfunction
function! InnerFragmentComplete#LowerCase( matchText )
    return substitute(a:matchText, '^\u', '\l&', '')
endfunction

let s:repeatCnt = 0
function! InnerFragmentComplete#InnerFragmentComplete( findstart, base )
    if s:repeatCnt
	if a:findstart
	    return col('.') - 1
	else
	    let l:matches = []

	    " When the previous completion was part of a CamelCaseWord (e.g.
	    " "CamelCase"), we also need to offer following fragments ("Word",
	    " and "_word"), not just keywords after non-keywords.
	    let l:repeatSeparatorExpr = (s:HasCamelCaseComplete() ? '\%(\k\@!\.\|_\|\u\)\+' : '\%(\k\@!\.\)\+')

	    call CompleteHelper#FindMatches(l:matches, '\V\k' . escape(s:fullText, '\') . '\zs' . l:repeatSeparatorExpr . '\k\+', {'complete': s:GetCompleteOption()})
	    return l:matches
	endif
    endif

    if a:findstart
	" Locate the start of the keyword characters (stopping when there's an
	" underscore or a transition from uppercase to lowercase).
	let l:startCol = searchpos('\l\zs\u\+\%(\u\@!_\@!\k\)*\%#', 'bn', line('.'))[1] " Try to find lowercase-uppercase transition first.
	if l:startCol > 0
	    " Allow full matches, too, in order to complete "myFB" to "myFooBar"
	    " from "FooBar".
	    let s:isBaseInInnerFragment = 1
	else
	    let s:isBaseInInnerFragment = 0

	    let l:startCol = searchpos('\%(_\@!\k\)\+\%#', 'bn', line('.'))[1]  " Then try non-underscore keyword characters.
	    if l:startCol == 0
		return "\<C-\>\<C-o>\<Esc>" | " Beep.
	    endif

	    " Unless there's an underscore before the base, only match real
	    " inner fragments; for a completion of "FB" to "FooBar", the
	    " CamelCaseComplete completion should be used.
	    let s:isBaseInInnerFragment = (search('_\%(_\@!\k\)\+\%#', 'bn', line('.')) != 0)
	endif
	return l:startCol - 1 " Return byte index, not column.
    else
	" Find matches inside a keyword starting with a:base.
	let l:matches = []
	let l:options = {'complete': s:GetCompleteOption()}

	let l:camelCaseExpr = (s:HasCamelCaseComplete() ? CamelCaseComplete#BuildRegexp(a:base, 0)[0] : '')

	" When there's both a keyword and CamelCase match at the same position,
	" the longer one in a single branch would win and is taken. It's
	" expected that both are offered, so submit keyword and CamelCase
	" patterns separately.

	let [l:firstLetter, l:rest] = matchlist(a:base, '^\(\a\)\?\(.*\)')[1:2]
	if empty(l:firstLetter)
	    let l:startRestriction = (s:isBaseInInnerFragment ? '' : '\k\zs')
	    let l:baseExpr = [printf('\V%s\%%(%s\k\+\)', l:startRestriction, escape(l:rest, '\'))]
	    if ! empty(l:camelCaseExpr)
		call add(l:baseExpr, printf('\V%s\%%(%s\)', l:startRestriction, l:camelCaseExpr))
	    endif
	else
	    " Make the search insensitive to the case of the first character,
	    " and choose different look-behind assertions for the preceding
	    " fragment.
	    " Note: Special case to match e.g. "Header" inside "HTTPHeader".
	    let l:baseExpr = [printf('\V\%%(\%%(\%%(\k\&\U%s\)\)\zs%s\|\%%(\k\&\A\)\zs%s%s\)%s\k\+',
	    \   (l:rest =~# '^\l' ? '\|\u' : ''),
	    \   toupper(l:firstLetter),
	    \   tolower(l:firstLetter),
	    \   (s:isBaseInInnerFragment ? '\|\<' . l:firstLetter : ''),
	    \   escape(l:rest, '\')
	    \)]
	    if ! empty(l:camelCaseExpr)
		if s:isBaseInInnerFragment
		    " Also match at the start of a CamelCaseWord.
		    call add(l:baseExpr, printf('\V%s_\@!%s',
		    \   (l:firstLetter =~# '\u' ? '' : '\%(\%(\k\&\A\)\zs\|\<\)'),
		    \   l:camelCaseExpr
		    \))
		else
		    " Match inner fragments of a CamelCaseWord, and from the
		    " start of a CamelCaseWord, as long as there are additional
		    " (unmatched) fragments after the match.
		    call add(l:baseExpr, printf('\V%s_\@!%s\|%s_\@!%s\ze\%(\U\@<=\u\k\*\|\d\k\*\|_\k\*\)\>',
		    \   (l:firstLetter =~# '\u' ? '\k' : '\%(\k\&\A\)') . '\zs',
		    \   l:camelCaseExpr,
		    \   (l:firstLetter =~# '\u' ? '' : '\%(\%(\k\&\A\)\zs\|\<\)'),
		    \   l:camelCaseExpr
		    \))
		endif
	    endif

	    " Convert the matches to the case of the first character.
	    let l:options.processor = (l:firstLetter =~# '\u' ? function('InnerFragmentComplete#UpperCase') : function('InnerFragmentComplete#LowerCase'))
	endif

	call CompleteHelper#FindMatches(l:matches, l:baseExpr, l:options)
"****D echomsg '****' string(a:base) string(l:baseExpr) len(l:matches)
	return l:matches
    endif
endfunction

function! InnerFragmentComplete#Expr()
    set completefunc=InnerFragmentComplete#InnerFragmentComplete

    let s:repeatCnt = 0 " Important!
    let [s:repeatCnt, l:addedText, s:fullText] = CompleteHelper#Repeat#TestForRepeat()

    return "\<C-x>\<C-u>"
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
