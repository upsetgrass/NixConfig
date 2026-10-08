vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.wrap = false
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.undofile = true

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { silent = true })
vim.keymap.set("n", "<leader>w", "<cmd>write<CR>", { silent = true })
vim.keymap.set("n", "<leader>q", "<cmd>quitall<CR>", { silent = true })
vim.cmd([[
  cnoreabbrev <expr> q getcmdtype() ==# ':' && getcmdline() ==# 'q' ? 'qa' : 'q'
  cnoreabbrev <expr> qw getcmdtype() ==# ':' && getcmdline() ==# 'qw' ? 'wqa' : 'qw'
  cnoreabbrev <expr> q! getcmdtype() ==# ':' && getcmdline() ==# 'q!' ? 'qa!' : 'q!'
  cnoreabbrev <expr> qw! getcmdtype() ==# ':' && getcmdline() ==# 'qw!' ? 'wqa!' : 'qw!'
]])

require("nvim-tree").setup({
  hijack_netrw = true,
  sync_root_with_cwd = true,
  update_focused_file = { enable = true },
  view = { side = "left" },
  renderer = { add_trailing = true, icons = { show = { file = false, folder = false, folder_arrow = false, git = false } } },
  trash = { cmd = "gio trash" },
  on_attach = function(bufnr)
    local api = require("nvim-tree.api")
    api.config.mappings.default_on_attach(bufnr)
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
vim.keymap.set("n", "<leader>f", "<cmd>FzfLua files<CR>", { desc = "Find project file" })
vim.keymap.set("n", "<leader>g", "<cmd>FzfLua live_grep<CR>", { desc = "Search project text" })
vim.keymap.set("n", "<leader>b", "<cmd>FzfLua buffers<CR>", { desc = "Find open buffer" })
vim.keymap.set("n", "<leader>fc", function()
  local ignore = vim.g.fzf_ignore_case ~= false
  vim.g.fzf_ignore_case = not ignore
  fzf.setup({ fzf_opts = { ["--ignore-case"] = vim.g.fzf_ignore_case } })
  vim.notify("fzf: " .. (vim.g.fzf_ignore_case and "ignore case" or "smart case"))
end, { desc = "Toggle fzf case mode" })

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
  extension = { v = "verilog", sv = "verilog", svh = "verilog" },
})

require("toggleterm").setup({ direction = "float", float_opts = { border = "rounded" } })
vim.keymap.set({ "n", "t" }, "<leader>tt", "<cmd>ToggleTerm<CR>", { desc = "Toggle terminal" })
vim.keymap.set("t", "<Esc>", [[<C-\\><C-n>]], { desc = "Leave terminal mode" })

vim.api.nvim_create_autocmd("FileType", {
  callback = function(event)
    if vim.bo[event.buf].filetype == "verilog" then
      vim.treesitter.language.register("systemverilog", "verilog")
    end
    local lang = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
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
vim.lsp.config("metals", { init_options = { statusBarProvider = "off" } })
for _, server in ipairs({
  "nil_ls", "lua_ls", "bashls", "clangd", "pyright", "rust_analyzer",
  "marksman", "html", "cssls", "ts_ls", "metals", "gopls",
}) do
  vim.lsp.enable(server)
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local opts = { buffer = event.buf, silent = true }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "<C-CR>", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "<C-Space>", vim.lsp.buf.references, opts)
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
  local path = vim.fn.expand("~/nix/vim/help.md")
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

local session_dir = vim.env.NVIM_NIX_SESSION_DIR or vim.fn.expand("~/nix/vim/state/sessions")
local last_code_file
local project_markers = {
  ".git", "flake.nix", "shell.nix", "vim.nix", "Cargo.toml", "package.json",
  "pyproject.toml", "build.sbt", "build.sc", "pom.xml", "go.mod",
}

local function project_file(path, root)
  return type(path) == "string" and path:sub(1, #root + 1) == root .. "/"
    and vim.fn.filereadable(path) == 1
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

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function(event)
    if vim.bo[event.buf].buftype == "" then
      local name = vim.api.nvim_buf_get_name(event.buf)
      if name ~= "" then last_code_file = name end
    end
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local root = project_root_for(last_code_file) 
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
    local state = {
      root = root, files = files, active = active, cursor = cursor,
      tree_open = tree.tree.is_visible(), outline_open = outline.is_open(),
      tree_root = nodes and nodes.absolute_path or root, tree_dirs = dirs,
      code_view = window_view(code_win), tree_view = window_view(tree_win),
      outline_view = window_view(outline_win),
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

vim.defer_fn(function()
  local arg_path = vim.fn.argc() > 0 and vim.fn.argv(0) or ""
  local root = project_root_for(arg_path)
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
  if project_file(state.active, root) then
    if not explicit_file then vim.cmd("edit " .. vim.fn.fnameescape(state.active)) end
    if vim.api.nvim_buf_get_name(0) == state.active and type(state.cursor) == "table" then
      pcall(vim.api.nvim_win_set_cursor, 0, state.cursor)
    end
  end
  if state.tree_open then
    local tree = require("nvim-tree.api")
    local tree_root = vim.fn.isdirectory(state.tree_root or "") == 1 and state.tree_root or root
    tree.tree.open({ path = tree_root })
    local expanded = {}
    for _, dir in ipairs(state.tree_dirs or {}) do expanded[dir] = true end
    tree.tree.expand_all(nil, { expand_until = function(_, node)
      return expanded[node.absolute_path] == true
    end })
    vim.cmd("wincmd p")
  end
  if state.outline_open then outline.open({ focus_outline = false }) end
  vim.defer_fn(function()
    local tree_win = require("nvim-tree.api").tree.winid()
    local code_win = vim.fn.bufwinid(state.active or "")
    local outline_win
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "Outline" then
        outline_win = win
        break
      end
    end
    restore_window_view(code_win, state.code_view)
    restore_window_view(tree_win, state.tree_view)
    restore_window_view(outline_win, state.outline_view)
    local focus_win = state.focus == "tree" and tree_win
      or state.focus == "outline" and outline_win or code_win
    if focus_win and focus_win > 0 and vim.api.nvim_win_is_valid(focus_win) then
      vim.api.nvim_set_current_win(focus_win)
    end
  end, 200)
end, 150)
