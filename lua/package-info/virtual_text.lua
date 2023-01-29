local constants = require("package-info.utils.constants")
local state = require("package-info.state")
local config = require("package-info.config")
local clean_version = require("package-info.helpers.clean_version")
local get_dependency_name_from_line = require("package-info.helpers.get_dependency_name_from_line")

local M = {}

--- Draws virtual text on given buffer line
-- @param line_number: number - line on which to place virtual text
-- @param dependency_name: string - dependency based on which to get the virtual text
-- @return nil
M.__display_on_line = function(line_number, dependency_name)
    local virtual_text = {
        group = constants.HIGHLIGHT_GROUPS.up_to_date,
        icon = config.options.icons.style.up_to_date,
        version = state.dependencies.installed[dependency_name].current,
    }

    if config.options.hide_up_to_date then
        virtual_text.version = ""
        virtual_text.icon = ""
    end

    local outdated_dependency = state.dependencies.outdated[dependency_name]

    if outdated_dependency and outdated_dependency.latest ~= state.dependencies.installed[dependency_name].current then
        virtual_text = {
            group = constants.HIGHLIGHT_GROUPS.outdated,
            icon = config.options.icons.style.outdated,
            version = clean_version(outdated_dependency.latest),
        }
        if config.options.diagnostic and config.options.diagnostic.enable then
            table.insert(M.diagnostics, {
                bufnr = state.buffer.id,
                lnum = line_number - 1,
                col = 0,
                severity = config.options.diagnostic.severity.outdated,
                message = string.format(
                    "Outdated: %s %s < %s",
                    dependency_name,
                    outdated_dependency.current,
                    outdated_dependency.latest
                ),
                source = "package-info",
                user_data = { version = virtual_text.version },
            })
        end
    end

    if not config.options.icons.enable then
        virtual_text.icon = ""
    end

    vim.api.nvim_buf_set_extmark(state.buffer.id, state.namespace.id, line_number - 1, 0, {
        virt_text = { { virtual_text.icon .. virtual_text.version, virtual_text.group } },
        virt_text_pos = "eol",
        priority = 200,
    })

    -- NOTE: used for testing only since there's no way to get virtual text content via nvim API
    return virtual_text
end

--- Clear all plugin virtual text in package.json
-- @return nil
M.clear = function()
    if state.is_virtual_text_displayed then
        vim.api.nvim_buf_clear_namespace(state.buffer.id, state.namespace.id, 0, -1)

        state.is_virtual_text_displayed = false
    end
end

--- Handles virtual text displaying
-- @param outdated_dependencies?: table - outdated dependencies
-- {
--     [dependency_name]: {
--         current: string - currently installed version
--         latest: string - latest available version
--     }
-- }
-- @return nil
M.display = function()
    if config.options.diagnostic.enable then
        M.diagnostics = {}
    end
    for line_number, line_content in ipairs(state.buffer.lines) do
        local dependency_name = get_dependency_name_from_line(line_content)

        if dependency_name then
            M.__display_on_line(line_number, dependency_name)
        end
    end
    if config.options.diagnostic.enable then
        local opts = { virtual_text = false }
        vim.diagnostic.set(state.namespace.id, state.buffer.id, M.diagnostics, opts)
    end

    state.is_virtual_text_displayed = true
end

return M
