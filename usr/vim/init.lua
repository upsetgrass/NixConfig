vim.env.VIMINIT = nil

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- `argv()` is mutable and nvim-tree replaces a directory argument with its
-- internal `NvimTree_1` buffer before this config is evaluated. `v:argv`
-- retains the original process command line, so extract the first real file
-- or directory argument while skipping Neovim options and Ex commands.
local function original_startup_path()
  local options_with_value = {
    ["--cmd"] = true, ["-c"] = true, ["-u"] = true, ["-i"] = true,
    ["-S"] = true, ["--listen"] = true, ["--server"] = true,
    ["--startuptime"] = true, ["--log"] = true,
  }
  local skip_next = false
  for index = 2, #vim.v.argv do
    local argument = vim.v.argv[index]
    if skip_next then
      skip_next = false
    elseif options_with_value[argument] then
      skip_next = true
    elseif argument:sub(1, 1) ~= "-" and argument:sub(1, 1) ~= "+" then
      return vim.fn.fnamemodify(argument, ":p")
    end
  end
  return ""
end
local startup_arg_path = original_startup_path()

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = false
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
vim.opt.termguicolors = true
require("onedark").setup({
  style = "darker",
  term_colors = true,
  code_style = {
    comments = "italic",
    keywords = "none",
    functions = "none",
    strings = "none",
    variables = "none",
  },
})
require("onedark").load()
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.wrap = false
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.undofile = true
vim.opt.autoread = false
vim.opt.rulerformat = '%l,%{charcol(".")} %P'
vim.opt.winbar = "%{%&buftype == '' ? '%f %m%r' : ''%}"
vim.opt.statusline = "%{%&buftype == '' ? '' : '%f '%}%h%w%m%r%=%l,%{charcol('.')} %P"

-- Keep Vim's built-in syntax files as a fallback for uncommon file variants;
-- supported source files switch to Treesitter in the FileType callback below.
vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")

require("ibl").setup({
  indent = { char = "┆" },
  scope = { enabled = false },
  exclude = { filetypes = { "NvimTree", "Outline", "help", "checkhealth", "qf" } },
})

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { silent = true })
vim.keymap.set("n", "<leader>w", "<cmd>write<CR>", { silent = true })
vim.keymap.set("n", "<leader>sw", function()
  vim.wo.wrap = not vim.wo.wrap
  vim.notify("wrap: " .. (vim.wo.wrap and "on" or "off"), vim.log.levels.INFO)
end, { desc = "Toggle line wrapping" })
-- Keep Ctrl-w exclusively as the Normal-mode window-command prefix.  In
-- Insert mode it otherwise deletes the previous word; command-line and
-- terminal modes may also consume it before Neovim can switch windows.
vim.keymap.set({ "i", "x", "s", "o", "c", "t" }, "<C-w>", "<Nop>", {
  silent = true,
  desc = "Disable Ctrl-w outside Normal mode",
})
vim.keymap.set("n", "<leader>cv", function()
  local path = vim.fn.expand("%:p")
  if path == "" or vim.bo.buftype ~= "" then
    vim.notify("Open a file to copy its path", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", path)
  vim.fn.setreg('"', path)
  vim.notify("Copied path: " .. path)
end, { desc = "Copy absolute file path" })
vim.keymap.set({ "x", "s" }, "<leader>c", '"+y', {
  silent = true, desc = "Copy selection to system clipboard",
})
vim.keymap.set("n", "<leader>q", "<cmd>quitall<CR>", { silent = true })
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  command = "checktime",
})
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    local view = vim.fn.winsaveview()
    vim.cmd([[silent keepjumps keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})
vim.cmd([[
  cnoreabbrev <expr> q getcmdtype() ==# ':' && getcmdline() ==# 'q' ? 'qa' : 'q'
  cnoreabbrev <expr> qw getcmdtype() ==# ':' && getcmdline() ==# 'qw' ? 'wqa' : 'qw'
  cnoreabbrev <expr> q! getcmdtype() ==# ':' && getcmdline() ==# 'q!' ? 'qa!' : 'q!'
  cnoreabbrev <expr> qw! getcmdtype() ==# ':' && getcmdline() ==# 'qw!' ? 'wqa!' : 'qw!'
]])

require("nvim-tree").setup({
  hijack_netrw = true,
  -- Git status is refreshed explicitly below.  The built-in BufWritePost
  -- reload races with tree navigation and only preserves a line number.
  auto_reload_on_write = false,
  sync_root_with_cwd = true,
  -- Do not let nvim-tree expand the active file automatically: that would
  -- overwrite the per-project expansion state restored below.  <leader>E
  -- remains the explicit "reveal current file" action.
  update_focused_file = { enable = false },
  view = { side = "left" },
  filters = { git_ignored = false },
  git = {
    enable = true,
    show_on_dirs = true,
    show_on_open_dirs = true,
    -- Large Scala/Chisel repositories can exceed nvim-tree's 400 ms default.
    -- A timeout must not silently turn every restored node back to plain white.
    timeout = 3000,
  },
  renderer = {
    add_trailing = true,
    highlight_git = "name",
    special_files = {},
    icons = {
      show = { file = false, folder = false, folder_arrow = false, git = false },
    },
  },
  trash = { cmd = "gio trash" },
  on_attach = function(bufnr)
    local api = require("nvim-tree.api")
    api.config.mappings.default_on_attach(bufnr)
    vim.keymap.set("n", "<leader>o", api.node.open.vertical, {
      buffer = bufnr, silent = true, desc = "Open file in vertical split",
    })
    vim.keymap.set("n", "<leader>p", api.node.open.horizontal, {
      buffer = bufnr, silent = true, desc = "Open file in horizontal split",
    })
    for _, key in ipairs({ "d", "<Del>" }) do
      vim.keymap.set({ "n", "x" }, key, api.fs.trash, {
        buffer = bufnr, silent = true, desc = "Move to trash",
      })
    end
    vim.keymap.set("n", "bd", api.marks.bulk.trash, {
      buffer = bufnr, silent = true, desc = "Move bookmarked files to trash",
    })
  end,
})
local function tree_git_highlights()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local colors = {
    clean = normal.fg and string.format("#%06x", normal.fg) or "#d8dee9",
    untracked = "#61afef",
    changed = "#98c379",
  }
  for _, group in ipairs({
    "NvimTreeFolderName", "NvimTreeEmptyFolderName", "NvimTreeOpenedFolderName",
    "NvimTreeSymlinkFolderName", "NvimTreeRootFolder", "NvimTreeFileName",
    "NvimTreeExecFile", "NvimTreeSymlink", "NvimTreeSpecialFile",
    "NvimTreeGitIgnoredIcon", "NvimTreeGitFileIgnoredHL", "NvimTreeGitFolderIgnoredHL",
  }) do
    vim.api.nvim_set_hl(0, group, { fg = colors.clean })
  end
  for _, group in ipairs({ "NvimTreeGitNewIcon", "NvimTreeGitFileNewHL", "NvimTreeGitFolderNewHL" }) do
    vim.api.nvim_set_hl(0, group, { fg = colors.untracked })
  end
  for _, group in ipairs({
    "NvimTreeGitDirtyIcon", "NvimTreeGitStagedIcon", "NvimTreeGitDeletedIcon",
    "NvimTreeGitRenamedIcon", "NvimTreeGitMergeIcon", "NvimTreeGitFileDirtyHL",
    "NvimTreeGitFileStagedHL", "NvimTreeGitFileDeletedHL", "NvimTreeGitFileRenamedHL",
    "NvimTreeGitFileMergeHL", "NvimTreeGitFolderDirtyHL", "NvimTreeGitFolderStagedHL",
    "NvimTreeGitFolderDeletedHL", "NvimTreeGitFolderRenamedHL", "NvimTreeGitFolderMergeHL",
  }) do
    vim.api.nvim_set_hl(0, group, { fg = colors.changed })
  end
end
tree_git_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = tree_git_highlights })
local tree_events = require("nvim-tree.api").events
tree_events.subscribe(tree_events.Event.TreeOpen, function()
  tree_git_highlights()
end)

-- Highlight common code annotations without requiring an extra runtime
-- plugin.  Matches are window-local so each split gets the same annotations.
local annotation_matches = {}
local annotation_groups = {
  { name = "Todo", pattern = [[\<TODO\>]], fg = "#ffcc66", bg = "#3d3420" },
  { name = "Fixme", pattern = [[\<FIXME\>]], fg = "#ff6b6b", bg = "#402326" },
  { name = "Note", pattern = [[\<NOTE\>]], fg = "#69dafa", bg = "#1d3740" },
  { name = "Hack", pattern = [[\<\%(HACK\|XXX\)\>]], fg = "#c099ff", bg = "#302842" },
  { name = "Warn", pattern = [[\<\%(WARN\|WARNING\|BUG\)\>]], fg = "#ff9e64", bg = "#422d20" },
}
for _, item in ipairs(annotation_groups) do
  vim.api.nvim_set_hl(0, item.name, { fg = item.fg, bg = item.bg, bold = true })
end
local function refresh_annotation_matches(win)
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then return end
  for _, id in ipairs(annotation_matches[win] or {}) do
    pcall(vim.fn.matchdelete, id, win)
  end
  annotation_matches[win] = {}
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  if ft == "NvimTree" or ft == "Outline" or ft == "qf" or vim.bo[buf].buftype ~= "" then return end
  for _, item in ipairs(annotation_groups) do
    local id = vim.fn.matchadd(item.name, item.pattern, 120, -1, { window = win })
    annotation_matches[win][#annotation_matches[win] + 1] = id
  end
end
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "FileType" }, {
  callback = function(event)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(event.buf) then refresh_annotation_matches(event.win or vim.api.nvim_get_current_win()) end
    end)
  end,
})
vim.api.nvim_create_autocmd("WinClosed", {
  callback = function(event)
    annotation_matches[tonumber(event.match)] = nil
  end,
})
vim.schedule(function() refresh_annotation_matches() end)
-- nvim-tree updates Git status asynchronously.  Its renderer preserves the
-- cursor line, but the node occupying that line can change after a redraw.
-- Remember the node selected by the user and restore that exact path whenever
-- an asynchronous render moves the cursor to another node.
local tree_selected_path
local restoring_tree_cursor = false
local function remember_tree_cursor()
  if restoring_tree_cursor or vim.bo.filetype ~= "NvimTree" then return end
  local node = require("nvim-tree.api").tree.get_node_under_cursor()
  if node and node.absolute_path then tree_selected_path = node.absolute_path end
end
vim.api.nvim_create_autocmd("FileType", {
  pattern = "NvimTree",
  callback = function(event)
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
      buffer = event.buf,
      callback = remember_tree_cursor,
    })
    vim.schedule(remember_tree_cursor)
  end,
})
tree_events.subscribe(tree_events.Event.TreeRendered, function()
  if restoring_tree_cursor or not tree_selected_path then return end
  local tree = require("nvim-tree.api")
  local current = tree.tree.get_node_under_cursor()
  if current and current.absolute_path == tree_selected_path then return end
  if not vim.uv.fs_stat(tree_selected_path) then
    tree_selected_path = current and current.absolute_path or nil
    return
  end
  restoring_tree_cursor = true
  pcall(tree.tree.find_file, { buf = tree_selected_path, focus = false })
  restoring_tree_cursor = false
end)
local tree_refresh_timer
local function refresh_tree_git_status()
  -- Reloading rebuilds the rendered node list while preserving only the old
  -- line number.  When Git results change the visible rows this can move the
  -- cursor to another node, so never refresh while the user is navigating the
  -- tree.  `R` remains available for an explicit refresh.
  if vim.bo.filetype == "NvimTree" then return end
  if tree_refresh_timer then tree_refresh_timer:stop() end
  tree_refresh_timer = vim.defer_fn(function()
    tree_refresh_timer = nil
    -- The user may have entered the tree after this refresh was scheduled.
    -- Never rebuild its nodes while the cursor is being moved there.
    if vim.bo.filetype == "NvimTree" then return end
    local tree = require("nvim-tree.api")
    if not tree.tree.is_visible() then return end
    local selected = tree.tree.get_node_under_cursor()
    local selected_path = selected and selected.absolute_path
    tree.tree.reload()
    -- A reload preserves the old line, not the node on that line.  Restore the
    -- selected file/directory by identity so Git rendering cannot move it.
    if selected_path and vim.uv.fs_stat(selected_path) then
      tree.tree.find_file({ buf = selected_path, focus = false })
    end
  end, 150)
end
vim.api.nvim_create_autocmd({ "TermLeave", "TermClose", "BufWritePost" }, {
  callback = refresh_tree_git_status,
})
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = { "*/.git/index", "*/.git/HEAD" },
  callback = refresh_tree_git_status,
})
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle project tree" })
vim.keymap.set("n", "<leader>E", "<cmd>NvimTreeFindFile<CR>", { desc = "Reveal current file" })
vim.keymap.set("n", "<leader>ef", "<cmd>NvimTreeFocus<CR>", { desc = "Focus project tree" })

require("gitsigns").setup({
  numhl = true,
  current_line_blame = true,
  current_line_blame_opts = { delay = 600, virt_text_pos = "eol" },
  on_attach = function(bufnr)
    local gs = require("gitsigns")
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("n", "]h", gs.next_hunk, vim.tbl_extend("force", opts, { desc = "Next Git change" }))
    vim.keymap.set("n", "[h", gs.prev_hunk, vim.tbl_extend("force", opts, { desc = "Previous Git change" }))
    vim.keymap.set("n", "<leader>gp", gs.preview_hunk, vim.tbl_extend("force", opts, { desc = "Preview Git change" }))
    vim.keymap.set("n", "<leader>gb", function() gs.blame_line({ full = true }) end,
      vim.tbl_extend("force", opts, { desc = "Show Git blame" }))
  end,
})

local function toggle_git_blame_list()
  local blame_windows = {}
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local filetype = vim.bo[bufnr].filetype
    local name = vim.api.nvim_buf_get_name(bufnr)
    if filetype == "fugitiveblame" or name:match("^fugitiveblame://") then
      table.insert(blame_windows, winid)
    end
  end

  if #blame_windows > 0 then
    for _, winid in ipairs(blame_windows) do
      if vim.api.nvim_win_is_valid(winid) then
        pcall(vim.api.nvim_win_close, winid, true)
      end
    end
    return
  end

  local ok, err = pcall(vim.cmd, "Git blame")
  if not ok then
    vim.notify("Git blame 打开失败：" .. tostring(err), vim.log.levels.ERROR)
  end
end
vim.keymap.set("n", "<leader>l", toggle_git_blame_list, { desc = "Toggle Git blame list" })

vim.g.project_history_no_data_notified = 1
require("project").setup({
  patterns = {
    ".git", "flake.nix", "shell.nix", "vim.nix", "Cargo.toml",
    "package.json", "pyproject.toml", "build.sbt", "build.sc", "pom.xml", "go.mod",
  },
  silent_chdir = true,
})

local fzf = require("fzf-lua")
fzf.setup({
  "default",
  file_icons = false,
  color_icons = false,
  fzf_opts = { ["--ignore-case"] = true },
  grep = { rg_opts = "--column --line-number --no-heading --color=always --ignore-case --max-columns=4096 -e" },
})
local function fzf_bottom_window()
  return { winopts = { split = "botright new" } }
end
vim.keymap.set("n", "<leader>f", function()
  fzf.files(fzf_bottom_window())
end, { desc = "Find project file in bottom window" })
vim.keymap.set("n", "<leader>g", function()
  fzf.live_grep(fzf_bottom_window())
end, { desc = "Search project text in bottom window" })
vim.keymap.set("n", "<leader>b", "<cmd>FzfLua buffers<CR>", { desc = "Find open buffer" })
vim.keymap.set("n", "<leader>fc", function()
  local ignore = vim.g.fzf_ignore_case ~= false
  vim.g.fzf_ignore_case = not ignore
  fzf.setup({ fzf_opts = { ["--ignore-case"] = vim.g.fzf_ignore_case } })
  vim.notify("fzf: " .. (vim.g.fzf_ignore_case and "ignore case" or "smart case"))
end, { desc = "Toggle fzf case mode" })

-- Render the current Markdown document in the system browser.  The Nix
-- package already contains its Node dependencies, so it does not read or
-- install anything from an external Neovim configuration.
vim.g.mkdp_auto_start = 0
vim.g.mkdp_auto_close = 1
vim.g.mkdp_refresh_slow = 0
vim.g.mkdp_command_for_global = 0
vim.g.mkdp_open_to_the_world = 0
vim.g.mkdp_open_ip = "127.0.0.1"
vim.g.mkdp_echo_preview_url = 1
vim.g.mkdp_page_title = "${name} - Markdown Preview"
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(event)
    vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreviewToggle<CR>", {
      buffer = event.buf,
      silent = true,
      desc = "Toggle Markdown browser preview",
    })
  end,
})

local outline = require("outline")
outline.setup({
  providers = {
    priority = (function()
      local priority = vim.deepcopy(require("outline.config").defaults.providers.priority)
      table.insert(priority, "treesitter")
      return priority
    end)(),
  },
  outline_window = {
    position = "right",
    relative_width = false,
    width = 32,
    focus_on_open = false,
    auto_close = false,
    auto_jump = false,
  },
  guides = { enabled = true, markers = { bottom = "`", middle = "+", vertical = "|", horizontal = "-" } },
  symbols = {
    icon_fetcher = function(kind)
      local labels = {
        Class = "C", Interface = "I", Struct = "S", Enum = "E", EnumMember = "e",
        Method = "m", StaticMethod = "m", Function = "f", Constructor = "c",
        Field = "v", Property = "p", Variable = "v", Constant = "k",
        Module = "M", Namespace = "N", Package = "P", File = "F",
        String = "T", Object = "O", TypeAlias = "T", Macro = "#",
      }
      return "[" .. (labels[kind] or ".") .. "]"
    end,
  },
  symbol_folding = { autofold_depth = 2, markers = { ">", "v" } },
  keymaps = { close = {} },
})
vim.keymap.set("n", "<leader>r", function()
  if not outline.is_open() and vim.bo.buftype ~= "" then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == "" then
        vim.api.nvim_set_current_win(win)
        break
      end
    end
  end
  outline.toggle({ focus_outline = false })
end, { desc = "Toggle document outline" })
vim.keymap.set("n", "<leader>o", outline.focus_toggle, { desc = "Focus outline or code" })
vim.keymap.set("n", "<leader>of", function()
  outline.open({ focus_outline = true })
end, { desc = "Focus document outline" })
vim.keymap.set("n", "<leader>oc", outline.focus_code, { desc = "Focus code" })

vim.filetype.add({
  extension = {
    cc = "cpp", cp = "cpp", cxx = "cpp", cplusplus = "cpp",
    hh = "cpp", hpp = "cpp", hxx = "cpp", inl = "cpp", ipp = "cpp", tpp = "cpp",
    scala = "scala", sbt = "scala", sc = "scala",
    mk = "make", mak = "make",
    v = "verilog", sv = "verilog", svh = "verilog",
  },
  filename = {
    ["Makefile"] = "make",
    ["GNUmakefile"] = "make",
    ["build.sbt"] = "scala",
    ["build.sc"] = "scala",
  },
  pattern = {
    [".*[Mm]akefile.*"] = "make",
  },
})

require("toggleterm").setup({ direction = "float", float_opts = { border = "rounded" } })
vim.keymap.set("n", "<leader>tt", "<cmd>ToggleTerm<CR>", { desc = "Toggle terminal" })
vim.keymap.set("t", "<C-]>", [[<C-\><C-n>]], { desc = "Leave outer terminal mode" })
vim.api.nvim_create_user_command("Shell", function()
  vim.cmd("botright 12new")
  local win = vim.api.nvim_get_current_win()
  vim.cmd("terminal")
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = vim.api.nvim_get_current_buf(),
    once = true,
    callback = function()
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end)
    end,
  })
  vim.cmd("startinsert")
end, { desc = "Open interactive shell split" })
vim.cmd([[
  cnoreabbrev <expr> shell getcmdtype() ==# ':' && getcmdline() ==# 'shell' ? 'Shell' : 'shell'
]])

local function language_semantic_highlights()
  -- OneDark intentionally keeps identifiers subdued. Use a higher-contrast
  -- code palette so Scala/Chisel keywords such as `val` and `class`, types,
  -- calls, members and literals are immediately distinguishable.
  local captures = {
    comment = { fg = "#727169", italic = true },
    keyword = { fg = "#ff7ab2", bold = true },
    ["keyword.type"] = { fg = "#c099ff", bold = true },
    ["keyword.function"] = { fg = "#c099ff", bold = true },
    ["keyword.import"] = { fg = "#82aaff" },
    ["keyword.modifier"] = { fg = "#ff7ab2" },
    ["keyword.operator"] = { fg = "#ff7ab2" },
    ["keyword.conditional"] = { fg = "#ff7ab2" },
    ["keyword.repeat"] = { fg = "#ff7ab2" },
    type = { fg = "#5de4c7" },
    ["type.builtin"] = { fg = "#5de4c7" },
    module = { fg = "#82aaff" },
    ["function"] = { fg = "#ffd866" },
    ["function.call"] = { fg = "#ffd866" },
    ["function.method"] = { fg = "#ffd866" },
    ["function.method.call"] = { fg = "#ffd866" },
    constructor = { fg = "#ffd866" },
    variable = { fg = "#d7dae0" },
    ["variable.parameter"] = { fg = "#f5bde6" },
    ["variable.member"] = { fg = "#7dcfff" },
    property = { fg = "#7dcfff" },
    string = { fg = "#a9dc76" },
    character = { fg = "#a9dc76" },
    number = { fg = "#ff9e64" },
    ["number.float"] = { fg = "#ff9e64" },
    boolean = { fg = "#ff9e64" },
    constant = { fg = "#ff9e64" },
    ["constant.builtin"] = { fg = "#ff9e64" },
    operator = { fg = "#89ddff" },
    attribute = { fg = "#f5bde6" },
  }
  local languages = {
    "bash", "c", "cpp", "c_sharp", "css", "go", "html", "java",
    "javascript", "json", "lua", "make", "markdown", "nix", "php",
    "python", "ruby", "rust", "scala", "systemverilog", "toml", "tsx",
    "typescript", "yaml", "zig",
  }
  for capture, style in pairs(captures) do
    vim.api.nvim_set_hl(0, "@" .. capture, style)
    for _, lang in ipairs(languages) do
      vim.api.nvim_set_hl(0, "@" .. capture .. "." .. lang, style)
    end
  end

  for _, lang in ipairs(languages) do
    for kind, capture in pairs({
      namespace = "module", type = "type", class = "type", enum = "type",
      interface = "type", struct = "type", typeParameter = "type",
      variable = "variable", parameter = "variable.parameter", property = "variable.member",
      enumMember = "constant", function_ = "function", method = "function.method",
      macro = "attribute", keyword = "keyword", comment = "comment",
      string = "string", number = "number", operator = "operator",
      decorator = "attribute",
    }) do
      local name = kind == "function_" and "function" or kind
      vim.api.nvim_set_hl(0, "@lsp.type." .. name .. "." .. lang, { link = "@" .. capture .. "." .. lang })
    end
  end
end
language_semantic_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = language_semantic_highlights })

local four_space_filetypes = {
  bash = true, c = true, cpp = true, c_sharp = true, cuda = true, go = true,
  java = true, javascript = true, javascriptreact = true, lua = true, nix = true,
  objc = true, objcpp = true, php = true, python = true, ruby = true, rust = true,
  scala = true, sh = true, systemverilog = true, typescript = true,
  typescriptreact = true, verilog = true, vim = true, zig = true,
}

vim.api.nvim_create_autocmd("FileType", {
  callback = function(event)
    local filetype = vim.bo[event.buf].filetype
    if filetype == "make" then
      -- GNU Make recipes require a literal tab as their first character.
      vim.bo[event.buf].expandtab = false
      vim.bo[event.buf].shiftwidth = 8
      vim.bo[event.buf].tabstop = 8
      vim.bo[event.buf].softtabstop = 0
    elseif four_space_filetypes[filetype] then
      vim.bo[event.buf].expandtab = true
      vim.bo[event.buf].shiftwidth = 4
      vim.bo[event.buf].tabstop = 4
      vim.bo[event.buf].softtabstop = 4
    else
      vim.bo[event.buf].expandtab = true
      vim.bo[event.buf].shiftwidth = 2
      vim.bo[event.buf].tabstop = 2
      vim.bo[event.buf].softtabstop = 2
    end
    if filetype == "verilog" then
      vim.treesitter.language.register("systemverilog", "verilog")
    end
    local lang = vim.treesitter.language.get_lang(filetype)
    if lang and pcall(vim.treesitter.language.add, lang) then
      pcall(vim.treesitter.start, event.buf, lang)
    end
  end,
})

require("blink.cmp").setup({
  keymap = {
    preset = "none",
    ["<Up>"] = { "select_prev", "fallback" },
    ["<Down>"] = { "select_next", "fallback" },
    ["<Tab>"] = { "accept", "fallback" },
    ["<C-Space>"] = { "show", "fallback" },
    ["<C-e>"] = { "hide", "fallback" },
  },
  completion = { list = { selection = { preselect = false } } },
  sources = { default = { "lsp", "path", "buffer" } },
  fuzzy = { implementation = "lua" },
})

vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
vim.lsp.config("clangd", {
  cmd = { vim.fn.exepath("clangd"), "--background-index", "--clang-tidy" },
})
vim.lsp.config("lua_ls", {
  cmd = { vim.fn.exepath("lua-language-server") },
  settings = { Lua = { telemetry = { enable = false } } },
  on_init = function(client)
    local root = client.root_dir
    if root and (vim.uv.fs_stat(root .. "/.luarc.json") or vim.uv.fs_stat(root .. "/.luarc.jsonc")) then
      return
    end
    if root == vim.fn.expand("~/work/NixConfig/usr/vim") then
      client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
        runtime = { version = "LuaJIT" },
        workspace = { library = { vim.env.VIMRUNTIME }, checkThirdParty = false },
        diagnostics = { globals = { "vim", "Snacks" } },
      })
    end
  end,
})
vim.lsp.config("metals", {
  cmd = { vim.fn.exepath("metals") },
  root_markers = {
    "build.sbt", "build.sc", "pom.xml", "build.gradle", "build.gradle.kts",
    ".bsp", ".metals", ".bloop", ".git",
  },
  init_options = { statusBarProvider = "off" },
})
vim.api.nvim_create_user_command("MetalsImportBuild", function()
  local clients = vim.lsp.get_clients({ bufnr = 0, name = "metals" })
  if not clients[1] then
    vim.notify("Open a Scala file in a build.sbt/build.sc/pom.xml project first", vim.log.levels.WARN)
    return
  end
  clients[1]:exec_cmd({ command = "build-import" }, { bufnr = 0 })
end, { desc = "Import Scala project build into Metals" })
if vim.fn.exists(":LspInfo") == 0 then
  vim.api.nvim_create_user_command("LspInfo", function()
    vim.cmd("checkhealth vim.lsp")
  end, { desc = "Show LSP health and attached clients" })
end
vim.api.nvim_create_user_command("MetalsLog", function()
  local client = vim.lsp.get_clients({ bufnr = 0, name = "metals" })[1]
  local root = client and client.root_dir
    or vim.fs.root(0, { "build.sbt", "build.sc", "build.gradle", "build.gradle.kts", "pom.xml", ".git" })
  local path = root and root .. "/.metals/metals.log"
  if not path or vim.fn.filereadable(path) == 0 then
    vim.notify("No Metals log found for this project", vim.log.levels.WARN)
    return
  end
  vim.cmd("botright 12split " .. vim.fn.fnameescape(path))
  vim.bo.buflisted = false
  vim.bo.readonly = true
  vim.cmd("normal! G")
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = true, silent = true })
end, { desc = "Open current project Metals log" })
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(event)
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true })
  end,
})
for _, server in ipairs({
  "nil_ls", "lua_ls", "bashls", "clangd", "pyright", "rust_analyzer",
  "marksman", "html", "cssls", "jsonls", "ts_ls", "metals", "gopls",
}) do
  vim.lsp.enable(server)
end

local function grep_symbol_fallback(action)
  local word = vim.fn.expand("<cword>")
  if word == "" then
    vim.notify("No symbol under cursor", vim.log.levels.WARN)
    return
  end
  vim.notify("LSP returned no " .. action .. "; searching project text for: " .. word,
    vim.log.levels.WARN)
  fzf.grep_cword(fzf_bottom_window())
end

local function lsp_locations_or_grep(kind)
  local request = kind == "definition" and "textDocument/definition" or "textDocument/references"
  local clients = vim.lsp.get_clients({ bufnr = 0, method = request })
  if #clients == 0 then
    grep_symbol_fallback(kind)
    return
  end

  local on_list = function(options)
    if not options.items or vim.tbl_isempty(options.items) then
      grep_symbol_fallback(kind)
      return
    end
    vim.fn.setqflist({}, " ", options)
    if #options.items == 1 then
      vim.cmd("cfirst")
    else
      vim.cmd("botright copen")
    end
  end

  if kind == "definition" then
    vim.lsp.buf.definition({ on_list = on_list })
  else
    vim.lsp.buf.references(nil, { on_list = on_list })
  end
end

vim.keymap.set("n", "gd", function() lsp_locations_or_grep("definition") end,
  { silent = true, desc = "LSP definition, project grep fallback" })
vim.keymap.set("n", "gr", function() lsp_locations_or_grep("references") end,
  { silent = true, desc = "LSP references, project grep fallback" })

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local opts = { buffer = event.buf, silent = true }
    vim.keymap.set("n", "<C-CR>", function() lsp_locations_or_grep("definition") end, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "<C-Space>", function() lsp_locations_or_grep("references") end, opts)
    vim.keymap.set("n", "<C-@>", function() lsp_locations_or_grep("references") end, opts)
    vim.keymap.set("n", "<leader>ci", vim.lsp.buf.incoming_calls, opts)
    vim.keymap.set("n", "<leader>co", vim.lsp.buf.outgoing_calls, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
  end,
})
vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Line diagnostics" })
vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end)
vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end)

require("snacks").setup({
  image = {
    enabled = true,
    doc = { enabled = true, inline = false, float = true, max_width = 80, max_height = 30 },
  },
})
vim.keymap.set("n", "<leader>i", function()
  Snacks.image.hover()
end, { desc = "Preview image under cursor" })

local personal_help_win
local function show_personal_help()
  if personal_help_win and vim.api.nvim_win_is_valid(personal_help_win) then
    vim.api.nvim_win_close(personal_help_win, true)
    personal_help_win = nil
    return
  end
  local path = vim.fn.expand("~/work/NixConfig/usr/vim/help.md")
  if vim.fn.filereadable(path) == 0 then
    vim.notify("Help file not found: " .. path, vim.log.levels.WARN)
    return
  end
  local lines = vim.fn.readfile(path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  local max_line = 40
  for _, line in ipairs(lines) do max_line = math.max(max_line, vim.fn.strdisplaywidth(line) + 2) end
  local width = math.min(math.max(max_line, 40), math.floor(vim.o.columns * 0.8))
  local height = math.min(math.max(#lines, 8), math.floor(vim.o.lines * 0.75))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded",
    row = math.floor((vim.o.lines - height) / 2 - 1),
    col = math.floor((vim.o.columns - width) / 2), width = width, height = height,
  })
  personal_help_win = win
  vim.wo[win].wrap = true
  vim.wo[win].conceallevel = 2
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, silent = true })
  end
  vim.keymap.set("n", "<leader>h", show_personal_help, {
    buffer = buf, silent = true, desc = "Close personal Vim help",
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win), once = true,
    callback = function() personal_help_win = nil end,
  })
end
vim.keymap.set("n", "<leader>h", show_personal_help, { desc = "Toggle personal Vim help" })

local session_dir = vim.env.NVIM_NIX_SESSION_DIR or vim.fn.expand("~/.local/state/nvim-nix/sessions")
local last_code_file
local project_markers = {
  ".git", "flake.nix", "shell.nix", "vim.nix", "Cargo.toml", "package.json",
  "pyproject.toml", "build.sbt", "build.sc", "pom.xml", "go.mod",
}

local function project_file(path, root)
  return type(path) == "string" and path:sub(1, #root + 1) == root .. "/"
    and not path:find("/%.git/", 1, false) and vim.fn.filereadable(path) == 1
end

local function session_path(root)
  return session_dir .. "/" .. vim.fn.sha256(root) .. ".json"
end

local function project_root_for(path)
  local dir = type(path) == "string" and path ~= "" and path or vim.fn.getcwd()
  if vim.fn.isdirectory(dir) == 0 then dir = vim.fn.fnamemodify(dir, ":h") end
  dir = vim.fs.normalize(vim.fn.resolve(dir))
  while dir ~= "/" and dir ~= "." do
    for _, marker in ipairs(project_markers) do
      if vim.fn.filereadable(dir .. "/" .. marker) == 1
        or vim.fn.isdirectory(dir .. "/" .. marker) == 1 then
        return dir
      end
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return vim.fn.getcwd()
end

-- A Neovim process represents one project session.  Keep this root fixed:
-- opening the personal help file or another file outside the project must not
-- overwrite the session belonging to the project that was originally opened.
local session_root = project_root_for(startup_arg_path)
if project_file(startup_arg_path, session_root) then last_code_file = startup_arg_path end

local function expanded_tree_dirs(node, result)
  for _, child in ipairs(node.nodes or {}) do
    if child.nodes and child.open then
      result[#result + 1] = child.absolute_path
      expanded_tree_dirs(child, result)
    end
  end
end

local function window_view(win)
  if not win or win == 0 or not vim.api.nvim_win_is_valid(win) then return nil end
  return vim.api.nvim_win_call(win, vim.fn.winsaveview)
end

local function restore_window_view(win, view)
  if not win or win == 0 or type(view) ~= "table" then return end
  pcall(vim.api.nvim_win_call, win, function() vim.fn.winrestview(view) end)
end

-- Store only normal project-file windows.  Plugin sidebars are restored by
-- their own APIs below, while transient terminal/fzf/help windows are omitted.
local function capture_code_layout(layout, root, windows, win_to_id)
  if type(layout) ~= "table" then return nil end
  if layout[1] == "leaf" then
    local win = layout[2]
    if not win or not vim.api.nvim_win_is_valid(win) then return nil end
    local buf = vim.api.nvim_win_get_buf(win)
    local file = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype ~= "" or not project_file(file, root) then return nil end
    local id = #windows + 1
    windows[id] = {
      id = id,
      file = file,
      cursor = vim.api.nvim_win_get_cursor(win),
      view = window_view(win),
    }
    win_to_id[win] = id
    return { kind = "leaf", id = id }
  end

  if layout[1] ~= "row" and layout[1] ~= "col" then return nil end
  local children = {}
  for _, child in ipairs(layout[2] or {}) do
    local saved = capture_code_layout(child, root, windows, win_to_id)
    if saved then children[#children + 1] = saved end
  end
  if #children == 0 then return nil end
  if #children == 1 then return children[1] end
  return { kind = layout[1], children = children }
end

local function restore_code_layout(layout, windows, root, target_win, restored)
  if type(layout) ~= "table" or not vim.api.nvim_win_is_valid(target_win) then return end
  if layout.kind == "leaf" then
    local saved = windows and windows[layout.id]
    if not saved or not project_file(saved.file, root) then return end
    vim.api.nvim_set_current_win(target_win)
    vim.cmd("silent edit " .. vim.fn.fnameescape(saved.file))
    restored[layout.id] = target_win
    return
  end

  if (layout.kind ~= "row" and layout.kind ~= "col") or type(layout.children) ~= "table" then return end
  local child_wins = { target_win }
  -- Create every sibling before recursively splitting any child, otherwise a
  -- nested first child would cause later siblings to be inserted inside it.
  for index = 2, #layout.children do
    vim.api.nvim_set_current_win(child_wins[index - 1])
    vim.cmd(layout.kind == "row" and "rightbelow vsplit" or "rightbelow split")
    child_wins[index] = vim.api.nvim_get_current_win()
  end
  for index, child in ipairs(layout.children) do
    restore_code_layout(child, windows, root, child_wins[index], restored)
  end
end

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function(event)
    -- Opening a directory lets nvim-tree replace and wipe Neovim's temporary
    -- directory buffer.  A queued BufEnter callback can therefore receive a
    -- buffer number which is already invalid by the time this function runs.
    if not event.buf or not vim.api.nvim_buf_is_valid(event.buf) then return end
    if vim.bo[event.buf].buftype == "" and vim.bo[event.buf].filetype ~= "gitcommit" then
      local name = vim.api.nvim_buf_get_name(event.buf)
      if project_file(name, session_root) then last_code_file = name end
    end
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local root = session_root
    local files, seen = {}, {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local path = vim.api.nvim_buf_get_name(buf)
      if vim.bo[buf].buflisted and project_file(path, root) and not seen[path] then
        files[#files + 1] = path
        seen[path] = true
      end
    end
    local active = project_file(last_code_file, root) and last_code_file or files[1]
    if not active then return end
    local cursor = { 1, 0 }
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == active then
        cursor = vim.api.nvim_win_get_cursor(win)
        break
      end
    end
    local tree = require("nvim-tree.api")
    local dirs = {}
    local nodes = tree.tree.get_nodes()
    if nodes then expanded_tree_dirs(nodes, dirs) end
    local tree_win = tree.tree.winid()
    local code_win = active and vim.fn.bufwinid(active) or -1
    local outline_win
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "Outline" then
        outline_win = win
        break
      end
    end
    local current_win = vim.api.nvim_get_current_win()
    local code_windows, win_to_id = {}, {}
    local code_layout = capture_code_layout(vim.fn.winlayout(), root, code_windows, win_to_id)
    local state = {
      root = root, files = files, active = active, cursor = cursor,
      tree_open = tree.tree.is_visible(), outline_open = outline.is_open(),
      tree_root = nodes and nodes.absolute_path or root, tree_dirs = dirs,
      code_view = window_view(code_win), tree_view = window_view(tree_win),
      outline_view = window_view(outline_win),
      code_layout = code_layout, code_windows = code_windows,
      active_code_id = win_to_id[code_win], focus_code_id = win_to_id[current_win],
      window_count = #vim.api.nvim_list_wins(), winrestcmd = vim.fn.winrestcmd(),
      focus = current_win == tree_win and "tree"
        or current_win == outline_win and "outline" or "code",
    }
    vim.fn.mkdir(session_dir, "p")
    local path = session_path(root)
    local temp = path .. "." .. vim.fn.getpid() .. ".tmp"
    if vim.fn.writefile({ vim.json.encode(state) }, temp) == 0 then
      vim.uv.fs_rename(temp, path)
    end
  end,
})

-- Restore the project after startup, before normal user input begins. The Nix
-- wrapper may finish VimEnter before this file reaches its session section, so
-- handle both an already-entered editor and the conventional startup order.
local function restore_project_session()
  -- nvim-tree also handles directory arguments during VimEnter. Run after all
  -- handlers in the current event have completed, but before normal user
  -- interaction; this avoids both directory re-hijacking and delayed jumps.
  vim.schedule(function()
  local arg_path = startup_arg_path
  if arg_path ~= "" and vim.fn.fnamemodify(arg_path, ":p"):find("/%.git/", 1, false) then
    return
  end
  local root = session_root
  local path = session_path(root)
  if vim.fn.filereadable(path) == 0 then return end
  local ok, state = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(state) ~= "table" or state.root ~= root then return end
  if vim.fn.getcwd() ~= root then
    vim.cmd("silent! cd " .. vim.fn.fnameescape(root))
  end
  local explicit_file = arg_path ~= "" and vim.fn.isdirectory(arg_path) == 0
  for _, file in ipairs(state.files or {}) do
    if project_file(file, root) then
      vim.cmd("badd " .. vim.fn.fnameescape(file))
    end
  end
  local restored_code_windows = {}
  if not explicit_file and type(state.code_layout) == "table" and type(state.code_windows) == "table" then
    -- Opening `vim <directory>` lets nvim-tree hijack Neovim's only startup
    -- window. Never reuse that sidebar as the target for normal file buffers:
    -- create a real code window first, then rebuild the saved code layout.
    if vim.bo.filetype == "NvimTree" then
      vim.cmd("rightbelow vnew")
    end
    pcall(vim.cmd, "silent! only")
    restore_code_layout(state.code_layout, state.code_windows, root,
      vim.api.nvim_get_current_win(), restored_code_windows)
  elseif project_file(state.active, root) then
    if not explicit_file then vim.cmd("edit " .. vim.fn.fnameescape(state.active)) end
    if vim.api.nvim_buf_get_name(0) == state.active and type(state.cursor) == "table" then
      pcall(vim.api.nvim_win_set_cursor, 0, state.cursor)
    end
  end
  local active_code_win = restored_code_windows[state.active_code_id or state.focus_code_id]
    or vim.fn.bufwinid(state.active or "")
  if active_code_win and active_code_win > 0 and vim.api.nvim_win_is_valid(active_code_win) then
    vim.api.nvim_set_current_win(active_code_win)
  end
  -- A directory argument explicitly means "open this project"; keep its tree
  -- visible even if an older session was saved while the restore bug was
  -- closing the sidebar. Plain `vim` still follows the saved tree state.
  local directory_start = arg_path ~= "" and vim.fn.isdirectory(arg_path) == 1
  if state.tree_open or directory_start then
    local tree = require("nvim-tree.api")
    local tree_root = vim.fn.isdirectory(state.tree_root or "") == 1 and state.tree_root or root
    tree.tree.open({ path = tree_root })
    vim.cmd("wincmd p")
    -- nvim-tree may automatically reveal the active buffer on startup. Reset
    -- that transient expansion, then replay exactly the saved directory list.
    if tree.tree.is_visible() then
      local expanded = {}
      for _, dir in ipairs(state.tree_dirs or {}) do expanded[dir] = true end
      tree.tree.collapse_all()
      tree.tree.expand_all(nil, { expand_until = function(_, node)
        return expanded[node.absolute_path] == true
      end })
    end
  end
  if state.outline_open then outline.open({ focus_outline = false }) end
  local tree_win = require("nvim-tree.api").tree.winid()
  local code_win = restored_code_windows[state.active_code_id or state.focus_code_id]
    or vim.fn.bufwinid(state.active or "")
  local outline_win
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "Outline" then
      outline_win = win
      break
    end
  end
  if type(state.winrestcmd) == "string"
    and #vim.api.nvim_list_wins() == tonumber(state.window_count) then
    pcall(vim.cmd, "silent! " .. state.winrestcmd)
  end
  if type(state.code_windows) == "table" then
    for id, saved in ipairs(state.code_windows) do
      restore_window_view(restored_code_windows[id], saved.view)
    end
  else
    restore_window_view(code_win, state.code_view)
  end
  restore_window_view(tree_win, state.tree_view)
  restore_window_view(outline_win, state.outline_view)
  local focus_win = state.focus == "tree" and tree_win
    or state.focus == "outline" and outline_win
    or restored_code_windows[state.focus_code_id or state.active_code_id] or code_win
  if focus_win and focus_win > 0 and vim.api.nvim_win_is_valid(focus_win) then
    vim.api.nvim_set_current_win(focus_win)
  end
  end)
end

-- This config reaches the session section while a directory explorer's
-- VimEnter handler is already running. A newly registered VimEnter callback
-- would miss that same event, so restore on the next event-loop turn directly.
restore_project_session()
