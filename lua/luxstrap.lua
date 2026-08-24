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
        local pkgs = lux.operations.install(
            { { package = "lux.nvim" }, { package = "rtp.nvim" }, { package = "pathlib.nvim" } }, tree, config)

        local root_for_lux

        for _, pkg in ipairs(pkgs) do
            local root = tree:root_for(pkg)

            if pkg:name() == "lux.nvim" then
                root_for_lux = root
            end

            package.path = package.path .. ";" .. string.format("%s/src/?.lua;%s/src/?/init.lua", root, root)
            package.cpath = package.cpath .. ";" .. string.format("%s/lib/?.so;%s/lib/?.dll", root, root)
            vim.opt.runtimepath:append(string.format("%s/etc", root))
        end

        vim.notify("luxstrap: lux.nvim downloaded successfully")

        local pathlib = require("pathlib")

        local lux_nvim_directory = pathlib.new(tree:root()) / "site/pack/lux/start/lux.nvim"

        if not (pathlib.new(root_for_lux) / "src"):symlink_to(lux_nvim_directory / "lua") then
            error("failed to create symlink")
        end

        local rtp = require("rtp_nvim")

        rtp.source_rtp_dir(lux_nvim_directory:tostring())

        -- TODO: Existing installations might already have lux.nvim, making this a no-op.
        -- Once the `lux.nvim` API lands, we should use that instead, which should ideally
        -- check if lux.nvim is added, if not, add it, then sync.
        vim.cmd.Lux("add lux.nvim")
    end)
end

return luxstrap
