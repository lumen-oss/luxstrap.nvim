local lux = require("luxstrap.lux-lua-shim")

local workspace = {}

---@readonly
workspace.PROJECT_PATH = vim.fn.stdpath("config")

function workspace.get()
    local ws = lux.workspace.new(workspace.PROJECT_PATH)

    if not ws then
        error(string.format("unable to create Lux project at %s", workspace.PROJECT_PATH))
    end

    return ws
end

return workspace
