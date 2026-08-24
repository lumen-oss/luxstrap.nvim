local luxstrap = {}

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

    if vim.fn.filereadable(dest) == 1 then
        package.cpath = install_dir .. "/?" .. ext .. ";" .. package.cpath
        return
    end

    local url = string.format(
        "https://github.com/lumen-oss/lux/releases/latest/download/lux-lua51-%s-%s%s",
        arch, triple, ext
    )

    vim.fn.mkdir(install_dir, "p")
    vim.notify("luxstrap: downloading lux-lua", vim.log.levels.INFO)

    vim.net.request(url, {
        outpath = dest,
    }, vim.schedule_wrap(function(err, _)
        if err then
            vim.notify("luxstrap: failed to download lux-lua :(", vim.log.levels.ERROR)
        end

        package.cpath = install_dir .. "/?" .. ext .. ";" .. package.cpath

        vim.notify("luxstrap: installed to " .. dest)

        cb()
    end))
end

---@param lux LuxModule
function luxstrap.install_lux_nvim(lux)
    local tree_path = vim.fn.stdpath("data") .. "/lux"

    local config = lux.config.new()
        :lua_version("5.1")
        :extra_servers({ "https://lux.lumen-labs.org/rocks-binaries/" })
        :entrypoint_layout({ layout = "nvim" })
        :user_tree(tree_path)
        :build()

    local tree = config:user_tree("5.1")

    -- if not vim.tbl_isempty(tree:match_rocks("lux.nvim")) then
    --
    -- end

    vim.notify("luxstrap: installing lux.nvim")

    local coro = require("luxstrap.coroutine")

    coro.execute(function()
        local pkgs = lux.operations.install({ { package = "lux.nvim" }, { package = "rtp.nvim" } }, tree, config)

        local rtp_nvim_pkg = vim.iter(pkgs):find(function(pkg) return pkg:name() == "rtp.nvim" end)

        local layout = tree:rock_layout(rtp_nvim_pkg)

        package.path = package.path .. ";" .. string.format("%s/?.lua;%s/?/init.lua", layout.src, layout.src)
        package.cpath = package.cpath .. ";" .. string.format("%s/?.so;%s/?.dll", layout.lib, layout.lib)

        vim.opt.runtimepath:append(tree:root() .. "/site/pack/lux/start/lux.nvim")
        vim.cmd.runtime("plugin/lux-nvim.lua")

        -- local rtp = require("rtp_nvim")
        --
        -- rtp.source_rtp_dir(tree:root() .. "/site/pack/lux/start/lux.nvim")
        -- package.path = package.path .. ";" .. string.format("%s/?.lua;%s/?/init.lua", layout.src, layout.src)

        vim.notify("luxstrap: lux.nvim downloaded successfully")

        -- TODO: Existing installations might already have lux.nvim, making this a no-op.
        -- Once the `lux.nvim` API lands, we should use that instead, which should ideally
        -- check if lux.nvim is added, if not, add it, then sync.
        vim.cmd.Lux("add lux.nvim")
    end)
end

return luxstrap
