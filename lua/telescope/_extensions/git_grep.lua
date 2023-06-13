local git_grep = require('git_grep')

return require('telescope').register_extension {
  setup = function(ext_config, _config)
    for k, v in pairs(ext_config) do
        git_grep.config[k] = v
    end
  end,

  exports = {
    grep = git_grep.grep,
    live_grep = git_grep.live_grep,
  }
}
