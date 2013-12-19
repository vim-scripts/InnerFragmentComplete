" InnerFragmentComplete.vim: Insert mode completion based on fragments inside words.
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher.
"   - InnerFragmentComplete.vim autoload script
"
" Copyright: (C) 2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.001	01-Oct-2013	file creation

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_InnerFragmentComplete') || (v:version < 700)
    finish
endif
let g:loaded_InnerFragmentComplete = 1

"- configuration ---------------------------------------------------------------

if ! exists('g:InnerFragmentComplete_complete')
    let g:InnerFragmentComplete_complete = '.,w,b'
endif


"- mappings --------------------------------------------------------------------

inoremap <silent> <expr> <Plug>(InnerFragmentComplete) InnerFragmentComplete#Expr()
if ! hasmapto('<Plug>(InnerFragmentComplete)', 'i')
    imap <C-x>i <Plug>(InnerFragmentComplete)
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
