" ============================================================================
" .vimrc - Vim Configuration
" ============================================================================

" General Settings
" ============================================================================
set nocompatible              " Disable vi compatibility
filetype plugin indent on     " Enable file type detection
syntax on                     " Enable syntax highlighting

" Basic Settings
" ============================================================================
set encoding=utf-8            " Set UTF-8 encoding
set fileencoding=utf-8        " Set file encoding
set number                    " Show line numbers
set relativenumber            " Show relative line numbers
set ruler                     " Show cursor position
set showcmd                   " Show command in bottom bar
set wildmenu                  " Visual autocomplete for command menu
set showmatch                 " Highlight matching brackets
set laststatus=2              " Always show status line
set mouse=a                   " Enable mouse support
set clipboard=unnamed         " Use system clipboard
set backspace=indent,eol,start " Make backspace work as expected

" Search Settings
" ============================================================================
set incsearch                 " Incremental search
set hlsearch                  " Highlight search results
set ignorecase                " Case insensitive search
set smartcase                 " Case sensitive if uppercase present

" Indentation
" ============================================================================
set autoindent                " Auto indent
set smartindent               " Smart indent
set expandtab                 " Use spaces instead of tabs
set tabstop=4                 " Number of spaces per tab
set shiftwidth=4              " Number of spaces for auto indent
set softtabstop=4             " Number of spaces in tab when editing

" Performance
" ============================================================================
set lazyredraw                " Redraw only when needed
set ttyfast                   " Faster redrawing

" Backups and Undo
" ============================================================================
set nobackup                  " No backup files
set nowritebackup             " No write backups
set noswapfile                " No swap files
set undofile                  " Enable persistent undo
set undodir=~/.vim/undo       " Undo directory
set undolevels=1000           " Number of undo levels
set undoreload=10000          " Number of lines to save for undo

" Create undo directory if it doesn't exist
if !isdirectory($HOME."/.vim/undo")
    call mkdir($HOME."/.vim/undo", "p", 0700)
endif

" UI Configuration
" ============================================================================
set cursorline                " Highlight current line
set scrolloff=8               " Keep 8 lines above/below cursor
set sidescrolloff=8           " Keep 8 columns left/right of cursor
set colorcolumn=80,120        " Show column markers at 80 and 120
set signcolumn=yes            " Always show sign column

" Splits
" ============================================================================
set splitbelow                " Horizontal splits below
set splitright                " Vertical splits to the right

" Folding
" ============================================================================
set foldenable                " Enable folding
set foldlevelstart=10         " Open most folds by default
set foldmethod=indent         " Fold based on indent level

" Key Mappings
" ============================================================================
let mapleader = " "           " Set leader key to space

" Quick save
nnoremap <leader>w :w<CR>

" Quick quit
nnoremap <leader>q :q<CR>

" Clear search highlighting
nnoremap <leader>h :nohlsearch<CR>

" Navigate splits
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Resize splits
nnoremap <leader>+ :vertical resize +5<CR>
nnoremap <leader>- :vertical resize -5<CR>

" Move lines up/down
nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv

" Better indenting in visual mode
vnoremap < <gv
vnoremap > >gv

" File Type Specific Settings
" ============================================================================
autocmd FileType python setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab
autocmd FileType javascript setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
autocmd FileType typescript setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
autocmd FileType html setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
autocmd FileType css setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
autocmd FileType yaml setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
autocmd FileType markdown setlocal wrap linebreak nolist

" Remove trailing whitespace on save
autocmd BufWritePre * :%s/\s\+$//e

" Status Line
" ============================================================================
set statusline=
set statusline+=%#PmenuSel#
set statusline+=%{StatuslineMode()}
set statusline+=%#LineNr#
set statusline+=\ %f
set statusline+=%m
set statusline+=%=
set statusline+=%#CursorColumn#
set statusline+=\ %y
set statusline+=\ %{&fileencoding?&fileencoding:&encoding}
set statusline+=\[%{&fileformat}\]
set statusline+=\ %p%%
set statusline+=\ %l:%c
set statusline+=\

function! StatuslineMode()
  let l:mode=mode()
  if l:mode==#"n"
    return "NORMAL"
  elseif l:mode==?"v"
    return "VISUAL"
  elseif l:mode==#"i"
    return "INSERT"
  elseif l:mode==#"R"
    return "REPLACE"
  elseif l:mode==?"s"
    return "SELECT"
  elseif l:mode==#"t"
    return "TERMINAL"
  elseif l:mode==#"c"
    return "COMMAND"
  elseif l:mode==#"!"
    return "SHELL"
  endif
endfunction

" Colors
" ============================================================================
set background=dark
set termguicolors

" Plugin Management (vim-plug)
" ============================================================================
" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

" Plugins
call plug#begin('~/.vim/plugged')

" Color schemes
Plug 'morhetz/gruvbox'
Plug 'joshdick/onedark.vim'

" File explorer
Plug 'preservim/nerdtree'

" Fuzzy finder
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Git integration
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" Status line
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Syntax highlighting
Plug 'sheerun/vim-polyglot'

" Auto pairs
Plug 'jiangmiao/auto-pairs'

" Commentary
Plug 'tpope/vim-commentary'

" Surround
Plug 'tpope/vim-surround'

call plug#end()

" Plugin Configuration
" ============================================================================

" Gruvbox
colorscheme gruvbox

" NERDTree
nnoremap <leader>n :NERDTreeToggle<CR>
nnoremap <leader>f :NERDTreeFind<CR>

" FZF
nnoremap <leader>p :Files<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>g :Rg<CR>

" Airline
let g:airline_theme='gruvbox'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
