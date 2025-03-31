--- "git_grep" is the exported module.
local git_grep = {}
git_grep.config = {}

local flatten = vim.tbl_flatten
local actions = require('telescope.actions')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local make_entry = require('telescope.make_entry')
local utils = require('telescope.utils')

--- Set the opts.cwd field. This function was copied from telescope.builtins.__git.
local set_opts_cwd = function(opts)
    local configured_cwd = opts.cwd or '%:h:p'
    local cwd = vim.fn.expand(configured_cwd)
    if cwd:len() > 0 then
        opts.cwd = cwd
    else
        opts.cwd = vim.loop.cwd()
    end
    -- Find root of git directory and remove trailing newline characters
    local git_root, ret =
        utils.get_os_command_output({ 'git', 'rev-parse', '--show-toplevel' }, opts.cwd)
    local use_git_root = vim.F.if_nil(opts.use_git_root, true)
    if ret ~= 0 then
        local in_worktree = utils.get_os_command_output(
            { 'git', 'rev-parse', '--is-inside-work-tree' },
            opts.cwd
        )
        local in_bare = utils.get_os_command_output(
            { 'git', 'rev-parse', '--is-bare-repository' },
            opts.cwd
        )
        if in_worktree[1] ~= 'true' and in_bare[1] ~= 'true' then
            -- We are not in a git repository, but we should still allow things to run
            -- in case the user has a custom grep_command configured.
            opts.is_bare = false
            opts.is_worktree = false
        elseif in_worktree[1] ~= 'true' and in_bare[1] == 'true' then
            opts.is_bare = true
            opts.is_worktree = false
        end
    else
        if use_git_root then
            opts.cwd = git_root[1]
        end
        opts.is_worktree = true
        opts.is_bare = false
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
    -- Hack: workaround so that we can se eall results
    -- https://github.com/nvim-telescope/telescope.nvim/issues/2779
    if not opts.max_results then
        opts.max_results = 10000
    end
    opts.temp__scrolling_limit = opts.max_results
    return opts
end

--- Build the "git grep" command.
local get_git_grep_command = function(prompt, opts)
    local additional_args = {}
    if opts.additional_args ~= nil then
        if type(opts.additional_args) == 'function' then
            additional_args = opts.additional_args(opts)
        elseif type(opts.additional_args) == 'table' then
            additional_args = opts.additional_args
        end
    end
    if opts.grep_command ~= nil then
        return flatten({ opts.grep_command, prompt, additional_args })
    end
    local regex_types = {
        extended = '--extended-regexp',
        basic = '--basic-regexp',
        fixed = '--fixed-strings',
        perl = '--perl-regexp',
    }
    local regex = opts.regex and regex_types[opts.regex] or nil
    local binary
    if opts.skip_binary_files then
        binary = '-I'
    else
        binary = '--text'
    end
    local git_grep = vim.F.if_nil(opts.git_grep, { 'git', 'grep' })
    return flatten({
        git_grep,
        '--no-color',
        '--column',
        '--line-number',
        binary,
        regex or {},
        '-e',
        prompt,
        additional_args,
    })
end

--- Get the prompt for use by grep()
local get_grep_prompt = function(opts)
    local vim_mode = vim.fn.mode()
    local visual = vim_mode == 'v' or vim_mode == 'V' or vim_mode == ''
    if visual == true then
        local saved_reg = vim.fn.getreg('v')
        vim.cmd([[noautocmd sil norm "vy]])
        local selection = vim.fn.getreg('v')
        vim.fn.setreg('v', saved_reg)
        -- Trim newlines from the start and end of the V selection.
        if vim_mode == 'V' then
            selection = selection:gsub('^%s+', '')
            selection = selection:gsub('%s+$', '')
        end
        return vim.F.if_nil(opts.search, selection)
    else
        return vim.F.if_nil(opts.search, vim.fn.expand('<cword>'))
    end
end

--- Interactively search for a pattern using "git grep"
git_grep.live_grep = function(opts)
    opts = get_git_grep_opts(opts)
    local live_grepper = finders.new_job(
        function(prompt)
            if not prompt or prompt == '' then
                return nil
            end
            return get_git_grep_command(prompt, opts)
        end,
        opts.entry_maker or make_entry.gen_from_vimgrep(opts),
        opts.max_results,
        opts.cwd
    )
    pickers
        .new(opts, {
            prompt_title = opts.search_title or 'Live Git Grep',
            finder = live_grepper,
            previewer = conf.grep_previewer(opts),
            sorter = sorters.highlighter_only(opts),
            attach_mappings = function(_, map)
                map('i', '<c-space>', actions.to_fuzzy_refine)
                return true
            end,
        })
        :find()
end

--- Use "git grep" to search for the selection or word under the cursor.
git_grep.grep = function(opts)
    opts = get_git_grep_opts(opts)
    local prompt = get_grep_prompt(opts)
    if prompt:len() == 0 then
        return
    end
    local git_grep_cmd = get_git_grep_command(prompt, opts)
    opts.entry_maker = opts.entry_maker or make_entry.gen_from_vimgrep(opts)
    pickers
        .new(opts, {
            prompt_title = (opts.search_title or 'Git Grep') .. ' (' .. prompt:gsub(
                '\n',
                '\\n'
            ) .. ')',
            finder = finders.new_oneshot_job(git_grep_cmd, opts),
            previewer = conf.grep_previewer(opts),
            sorter = conf.file_sorter(opts),
            attach_mappings = function(_, map)
                map('i', '<c-space>', actions.to_fuzzy_refine)
                return true
            end,
        })
        :find()
end

--- Return a table of git repositories corresponding to the current open buffers plus the cwd.
local get_buffer_repos = function()
    local repos = {}
    local buffers = vim.api.nvim_list_bufs()
    for _, buffer in ipairs(buffers) do
        local filename = vim.api.nvim_buf_get_name(buffer)
        if filename:len() > 0 and vim.uv.fs_stat(filename) then
            -- Gather a unique set of git repositories corresopnding to the open buffers.
            local dirname = vim.fs.dirname(filename)
            local file_opts = {
                cwd = dirname,
                use_git_root = true,
            }
            set_opts_cwd(file_opts)
            -- We will only process the ones that are actual worktrees.
            if file_opts.is_worktree then
                repos[file_opts.cwd] = true
            end
        end
    end
    -- Also attempt to use vim's cwd
    local cwd_opts = { cwd = vim.loop.cwd(), use_git_root = true }
    set_opts_cwd(cwd_opts)
    if cwd_opts.is_worktree then
        repos[cwd_opts.cwd] = true
    end
    -- Return a flat table.
    local result = {}
    for repo, _ in pairs(repos) do
        table.insert(result, repo)
    end

    return result
end

--- Return true if the string ends with suffix
local endswith = function(str, suffix)
    return str:sub(-#suffix) == suffix
end

-- Transform a partial /foo/ba path into /foo.
local trim_path = function(prefix)
    -- Trim until we reach the last slash.
    while prefix:len() > 1 and not endswith(prefix, '/') do
        prefix = prefix:sub(1, -2)
    end
    -- Trim the final trailing slash unless the path is '/'.
    if prefix ~= '/' and endswith(prefix, '/') then
        prefix = prefix:sub(1, -2)
    end
    return prefix
end

--- Return the longest common prefix in a table of strings
local get_common_path_prefix = function(strs)
    if #strs == 0 then
        return '' -- Return an empty string if the input table is empty
    end

    -- Find the smallest string length in the table
    local min_length = #strs[1]
    for i = 2, #strs do
        min_length = math.min(min_length, #strs[i])
    end

    local prefix = ''
    for i = 1, min_length do
        local char = strs[1]:sub(i, i) -- Get the character from the first string
        for j = 2, #strs do
            if strs[j]:sub(i, i) ~= char then
                -- Return the prefix if a mismatch is found
                return trim_path(prefix)
            end
        end
        prefix = prefix .. char -- Add the character to the prefix if all strings match
    end

    return trim_path(prefix)
end

--- Calculate a git grep workspace command
local get_git_grep_workspace_command = function(repos)
    local this_module_path = debug.getinfo(1).source:match('@?(.*/)')
    local git_grep_cmd = { this_module_path .. 'git-grep-workspace' }
    for _, repo in ipairs(repos) do
        table.insert(git_grep_cmd, repo)
    end
    return git_grep_cmd
end

--- Use "git grep" across all repositories that are currently open in your
--- current session.
git_grep.workspace_grep = function(opts)
    opts = get_git_grep_opts(opts)
    local prompt = get_grep_prompt(opts)
    if prompt:len() == 0 then
        return
    end
    local repos = get_buffer_repos()
    opts.cwd = get_common_path_prefix(repos)
    opts.git_grep = get_git_grep_workspace_command(repos)
    opts.use_git_root = false

    git_grep.grep(opts)
end

--- A live grep over all worktrees in your current session.
git_grep.workspace_live_grep = function(opts)
    opts = get_git_grep_opts(opts)
    local repos = get_buffer_repos()
    opts.cwd = get_common_path_prefix(repos)
    opts.git_grep = get_git_grep_workspace_command(repos)
    opts.use_git_root = false

    git_grep.live_grep(opts)
end

return git_grep
