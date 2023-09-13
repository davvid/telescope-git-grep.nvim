--- "git_grep" is the exported module.
local git_grep = {}
git_grep.config = {}

local flatten = vim.tbl_flatten
local actions = require("telescope.actions")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local sorters = require "telescope.sorters"
local make_entry = require("telescope.make_entry")
local utils = require("telescope.utils")

--- Set the opts.cwd field. This function was copied from telescope.builtins.__git.
local set_opts_cwd = function(opts)
  local configured_cwd = opts.cwd or "%:h:p"
  local cwd = vim.fn.expand(configured_cwd)
  if string.len(cwd) > 0 then
    opts.cwd = cwd
  else
    opts.cwd = vim.loop.cwd()
  end

  -- Find root of git directory and remove trailing newline characters
  local git_root, ret = utils.get_os_command_output(
    { "git", "rev-parse", "--show-toplevel" }, opts.cwd
  )
  local use_git_root = vim.F.if_nil(opts.use_git_root, true)

  if ret ~= 0 then
    local in_worktree = utils.get_os_command_output(
      { "git", "rev-parse", "--is-inside-work-tree" }, opts.cwd
    )
    local in_bare = utils.get_os_command_output(
      { "git", "rev-parse", "--is-bare-repository" }, opts.cwd
    )

    if in_worktree[1] ~= "true" and in_bare[1] ~= "true" then
      error(opts.cwd .. " is not a git directory")
    elseif in_worktree[1] ~= "true" and in_bare[1] == "true" then
      opts.is_bare = true
    end
  else
    if use_git_root then
      opts.cwd = git_root[1]
    end
  end
end

--- Initialize options for git_grep and live_git_grep.
local get_git_grep_opts = function(opts)
  -- Operate on a copy of git_grep.config
  local config = {}
  for k, v in pairs(git_grep.config) do
    config[k] = v
  end
  opts = vim.F.if_nil(opts, config)
  set_opts_cwd(opts)
  return opts
end

--- Build the "git grep" command.
local get_git_grep_command = function(prompt, opts)
  local additional_args = {}
  if opts.additional_args ~= nil then
    if type(opts.additional_args) == "function" then
      additional_args = opts.additional_args(opts)
    elseif type(opts.additional_args) == "table" then
      additional_args = opts.additional_args
    end
  end

  local default_regex = 'extended'
  local regex_types = {
    extended = '--extended-regexp',
    basic = '--basic-regexp',
    fixed = '--fixed-strings',
    perl = '--perl-regexp',
  }
  local regex = regex_types[opts.regex] or regex_types[default_regex]
  return {
    "git", "grep", "--no-color", "--column", "--line-number", regex, "-e", prompt, additional_args
  }
end

--- Interactively search for a pattern using "git grep"
git_grep.live_grep = function(opts)
  opts = get_git_grep_opts(opts)

  local live_grepper = finders.new_job(function(prompt)
    if not prompt or prompt == "" then
      return nil
    end
    return get_git_grep_command(prompt, opts)
  end, opts.entry_maker or make_entry.gen_from_vimgrep(opts), opts.max_results, opts.cwd)

  pickers
    .new(opts, {
      prompt_title = "Live Git Grep",
      finder = live_grepper,
      previewer = conf.grep_previewer(opts),
      sorter = sorters.highlighter_only(opts),
      attach_mappings = function(_, map)
        map("i", "<c-space>", actions.to_fuzzy_refine)
        return true
      end,
    })
    :find()
end

--- Use "git grep" to search for the selection or word under the cursor.
git_grep.grep = function(opts)
  opts = get_git_grep_opts(opts)
  local prompt
  local vim_mode = vim.fn.mode()
  local visual = vim_mode == "v" or vim_mode == ""

  if visual == true then
    local saved_reg = vim.fn.getreg "v"
    vim.cmd [[noautocmd sil norm "vy]]
    local sele = vim.fn.getreg "v"
    vim.fn.setreg("v", saved_reg)
    prompt = vim.F.if_nil(opts.search, sele)
  else
    prompt = vim.F.if_nil(opts.search, vim.fn.expand("<cword>"))
  end
  if string.len(prompt) == 0 then
    return
  end

  local git_grep_cmd = get_git_grep_command(prompt, opts)
  opts.entry_maker = opts.entry_maker or make_entry.gen_from_vimgrep(opts)

  pickers
    .new(opts, {
      prompt_title = "Git Grep (" .. prompt:gsub("\n", "\\n") .. ")",
      finder = finders.new_oneshot_job(git_grep_cmd, opts),
      previewer = conf.grep_previewer(opts),
      sorter = conf.file_sorter(opts),
      attach_mappings = function(_, map)
        map("i", "<c-space>", actions.to_fuzzy_refine)
        return true
      end,
    })
    :find()
end

return git_grep
