# Changelog

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
