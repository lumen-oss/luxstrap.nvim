if vim.g.loaded_luxstrap_nvim then
    return
end

local luxstrap = require("luxstrap")

luxstrap.install_lux_lua(function()
    ---@type boolean, LuxModule|string
    local ok, lux = pcall(require, "luxstrap.lux-lua-shim")

    if not ok then
        error("installation is corrupted. Please restart Neovim to attempt a fix.")
        return
    end

    ---@cast lux LuxModule

    luxstrap.install_lux_nvim(lux)
end)


vim.g.loaded_luxstrap_nvim = true
