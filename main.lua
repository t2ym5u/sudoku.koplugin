-- Add the plugin's own directory to package.path so that local modules
-- (board, board_widget, screen) can be loaded with a plain require().
local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. package.path

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local board_module = require("board")
local SudokuBoard    = board_module.SudokuBoard
local DEFAULT_DIFFICULTY = board_module.DEFAULT_DIFFICULTY

local SudokuScreen = require("screen")

-- ---------------------------------------------------------------------------
-- Sudoku — KOReader plugin entry point
-- ---------------------------------------------------------------------------

local Sudoku = WidgetContainer:extend{
    name = "sudoku",
    is_doc_only = false,
}

function Sudoku:ensureSettings()
    if not self.settings_file then
        self.settings_file = DataStorage:getSettingsDir() .. "/sudoku.lua"
    end
    if not self.settings then
        self.settings = LuaSettings:open(self.settings_file)
    end
end

function Sudoku:init()
    self:ensureSettings()
    self.ui.menu:registerToMainMenu(self)
end

function Sudoku:addToMainMenu(menu_items)
    menu_items.sudoku = {
        text = _("Sudoku"),
        sorting_hint = "tools",
        callback = function()
            self:showGame()
        end,
    }
end

function Sudoku:getBoard()
    if not self.board then
        self:ensureSettings()
        -- Create a default board; load() will restore n/box_rows/box_cols from
        -- the saved state (old saves without those fields default to 9×9).
        self.board = SudokuBoard:new()
        local state = self.settings:readSetting("state")
        if not self.board:load(state) then
            self.board:generate(DEFAULT_DIFFICULTY)
        end
    end
    return self.board
end

function Sudoku:saveState()
    if not self.board then
        return
    end
    self:ensureSettings()
    self.settings:saveSetting("state", self.board:serialize())
    self.settings:flush()
end

function Sudoku:showGame()
    if self.screen then
        return
    end
    self.screen = SudokuScreen:new{
        board = self:getBoard(),
        plugin = self,
    }
    UIManager:show(self.screen)
end

function Sudoku:onScreenClosed()
    self.screen = nil
end

return Sudoku
