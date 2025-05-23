# Changelog

## v1.4.0

**Features**

- The current directory is now included in the list of repositories to search
  when using the "workspace" grep functions. Set `use_vim_cwd = false`
  when configuring the plugin to disable this behavior.

## v1.3.0

**Features**

- New `git_grep.workspace_grep` and `git_grep.workspace_live_grep` commands
  are available for performing `git grep` across all of the repositories
  in your current session.


## v1.2.0

**Features**

- The title can now be customized using the `search_title` option.

- The grep command can now be customized using the `grep_command` option.

- An error is no longer produced when run outside of a git repository.


## v1.1.1

**Features**

- The results were being limited to `250` results in newer Telescope versions.
  We now override this limit to `10000`. Configure `max_results` if the default
  value of `10000` is not sufficient.


## v1.1.0

**Features**

- The grep regex type is no longer passed to `git grep` unless it is configured to do so
  in the lua configuration. This makes the plugin use the same regex type as your git
  configuration by default. See the [README](README.md) for more details.

If you suddenly no longer have extended regexes and do not want to change your
git configuration, configure `regex = 'extended'` in your neovim lua configuration to
get the original behavior.


## v1.0.2

**Fixes**

- Typofix from the `v1.0.1` update.
  ([#2](https://github.com/davvid/telescope-git-grep.nvim/pull/2))


## v1.0.1

**Fixes**

- The `--no-color` option is now passed to `git grep` to guard against users
  having `[ui] color = always` configured in their `~/.gitconfig`.
  ([#1](https://github.com/davvid/telescope-git-grep.nvim/pull/1))


## v1.0.0

**Initial Release**

- Telescope-Git-Grep is feature complete.

- The `git_grep.grep()` and `git_grep.live_git()` functions are the
  main entry points into this plugin.
