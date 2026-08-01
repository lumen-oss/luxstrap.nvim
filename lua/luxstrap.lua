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
        cb()
        return
    end

    local url = string.format(
        "https://github.com/lumen-oss/lux/releases/latest/download/lux-lua51-%s-%s%s",
        arch, triple, ext
    )

    vim.fn.mkdir(install_dir, "p")
    vim.notify("luxstrap: downloading lux-lua ...", vim.log.levels.INFO)

    vim.net.request(url, {
        outpath = dest,
    }, function(err, _)
        if err then
            vim.notify("luxstrap: failed to download lux-lua :(", vim.log.levels.ERROR)
        end

        package.cpath = install_dir .. "/?" .. ext .. ";" .. package.cpath

        vim.notify("luxstrap: installed to " .. dest)

        cb()
    end)
end

---@param lux LuxModule
function luxstrap.install_lux_nvim(lux)
    -- TODO
end

return luxstrap
