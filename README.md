# telescope-git-grep.nvim

*Telescope Git Grep* is a [telescope](https://github.com/nvim-telescope/telescope.nvim)
extension that uses `git grep` to search tracked files.


## Installation

You can install this plugin using your favorite vim package manager, eg.
[vim-plug](https://github.com/junegunn/vim-plug),
[Packer](https://github.com/wbthomason/packer.nvim) or
[lazy](https://github.com/folke/lazy.nvim).

**Packer**:
```lua
use({"davvid/telescope-git-grep.nvim", branch = "main"})
```

**lazy**:
```lua
{
    "davvid/telescope-git-grep.nvim",
    branch = "main"
}
```

**vim-plug**
```VimL
Plug 'davvid/telescope-git-grep.nvim'
```


## Usage

Activate the custom Telescope commands and `git_grep` extension by adding

```lua
require('telescope').load_extension('git_grep')
```

somewhere after your `require('telescope').setup()` call.

The following `Telescope` extension commands are provided:

```VimL
Telescope git_grep grep
Telescope git_grep live_grep

" Specify a custom repository path using the "cwd" option
Telescope git_grep live_grep cwd=~/path/to/repo
```

These commands can also be used from your `init.lua`.
For example, to bind `git_grep` to `<leader>g` and `live_git_grep` to `<leader>G` use:

```lua
local git_grep = require('git_grep')

-- Use git_grep to search for the current word and fuzzy-search over the result.
vim.keymap.set({'n', 'v'}, '<leader>g', function()
    git_grep.grep()
end)

-- Use live_grep to interactively search for a pattern.
vim.keymap.set('n', '<leader>G', function()
    git_grep.live_grep()
end)
```


## Configuration

**NOTE**: You typically do not need to configure these fields.
The following configuration fields are available when needed.

```lua
require('telescope').setup {
    extensions = {
        git_grep = {
            cwd = '%:h:p',
            use_git_root = true
        }
    }
}
```

The values shown above are the default values. You do not typically need to specify the
`git_grep = {...}` extension configuration if the defaults work fine for you as-is.

You can also pass a `{ cwd = '...', use_git_root = true }` table as the first argument
directly to the extension functions to set these values at specific call sites.


## Notes

The default values of `cwd = '%:h:p'` and `use_git_root = true` make it so that
`git grep` commands are launched from the root of the repository corresponding
to current buffer's file. If the buffer is an anonymous buffer (with no filename)
then nvim's current directory will be used.

Setting `use_git_root = false` will launch `git grep` from the subdirectory
containing the current file. This causes `git grep` to only search files
within that directory.

Set `cwd = '/some/repo'` and set `use_git_root = false` if you want `git grep`
to search in a specific directory.


## Development

The [Garden file](garden.yaml) can be used to generate docs and run lint
checks using [Garden](https://github.com/davvid/garden).

```sh
# Run lint checks using "luacheck"
garden lint
```


## Acknowledgements

`telescope-git-grep` was adapted from Telescope's internal
`telescope/builtin/__git.lua` and `telescope/builtin/__files.lua` modules.
