local luxstrap = {}

local LUA_VERSION = "jit"

local function download(url, dest, cb)
    local tmp = dest .. ".tmp"

    vim.net.request(url, { outpath = tmp }, vim.schedule_wrap(function(err)
        if err then
            vim.fn.delete(tmp)
            vim.notify("luxstrap: failed to download lux-lua: " .. tostring(err), vim.log.levels.ERROR)
            return
        end

        local renamed, rename_err = vim.uv.fs_rename(tmp, dest)
        if not renamed and vim.uv.fs_stat(dest) then
            vim.uv.fs_unlink(dest)
            renamed, rename_err = vim.uv.fs_rename(tmp, dest)
        end

        if not renamed then
            vim.fn.delete(tmp)
            vim.notify("luxstrap: failed to install lux-lua: " .. tostring(rename_err), vim.log.levels.ERROR)
            return
        end

        cb()
    end))
end

function luxstrap.detect_platform()
    local uname = vim.uv.os_uname()
    local arch = uname.machine:lower()
    local sysname = uname.sysname:lower()

    if arch == "arm64" then
        arch = "aarch64"
    end

    if sysname == "linux" then
        return arch, "unknown-linux-gnu", ".so"
    elseif sysname == "darwin" then
        return arch, "apple-darwin", ".so"
    elseif sysname:match("windows") then
        return arch, "pc-windows-msvc", ".dll"
    end

    error(
        "luxstrap: unable to detect current operating system! Please report this at https://github.com/lumen-oss/luxstrap.nvim/issues/new with your operating system, version and architecture.")
end

---@param cb fun()
function luxstrap.install_lux_lua(cb)
    local arch, triple, ext = luxstrap.detect_platform()

    local install_dir = vim.fn.stdpath("data")
    local dest = install_dir .. "/lux" .. ext

    package.cpath = install_dir .. "/?" .. ext .. ";" .. package.cpath

    -- Reuse an existing library; lux.nvim owns updates through `lux.toml`.
    if vim.fn.filereadable(dest) == 1 then
        local ok, err = pcall(require, "lux")
        if ok then
            cb()
            return
        end

        vim.notify(
            "luxstrap: existing lux-lua failed to load, downloading a fresh copy: " .. tostring(err),
            vim.log.levels.WARN
        )
    end

    local url = string.format(
        "https://github.com/lumen-oss/lux/releases/latest/download/lux-%s-%s-%s%s",
        "luajit",
        arch,
        triple,
        ext
    )

    vim.fn.mkdir(install_dir, "p")
    vim.notify("luxstrap: downloading lux-lua", vim.log.levels.INFO)

    download(url, dest, function()
        if not package.loaded.lux then
            local ok, err = pcall(require, "lux")

            if not ok then
                vim.notify(
                    "luxstrap: downloaded lux-lua failed to load: " .. tostring(err),
                    vim.log.levels.ERROR
                )
                return
            end
        end

        vim.notify("luxstrap: lux-lua installed to " .. dest)
        cb()
    end)
end

---@param lux LuxModule
function luxstrap.install_lux_nvim(lux)
    local tree_path = vim.fn.stdpath("data") .. "/lux"

    local config = lux.config.new()
        :lua_version(LUA_VERSION)
        :extra_servers({ "https://lux.lumen-labs.org/rocks-binaries/" })
        :entrypoint_layout(lux.config.nvim_layout())
        :user_tree(tree_path)
        :build()

    local tree = config:user_tree(LUA_VERSION)
    local plugin_dir = tree:root() .. "/site/pack/lux/start/lux.nvim"

    if not vim.o.runtimepath:find(plugin_dir, 1, true) then
        vim.opt.runtimepath:append(plugin_dir)
    end

    if vim.fn.isdirectory(plugin_dir) == 1 then
        vim.cmd.runtime("plugin/lux-nvim.lua")
        return
    end

    vim.notify("luxstrap: installing lux.nvim")

    local coro = require("luxstrap.coroutine")

    coro.execute(function()
        lux.operations.install({ { package = "lux.nvim" } }, tree, config)

        vim.cmd.runtime("plugin/lux-nvim.lua")

        vim.notify("luxstrap: lux.nvim downloaded successfully")
        vim.cmd.Lux("add lux.nvim")
    end)
end

return luxstrap
