local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local DataStorage    = require("datastorage")
local LuaSettings    = require("luasettings")
local UIManager      = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _              = require("gettext")

local board_module       = lrequire("board")
local SudokuBoard        = board_module.SudokuBoard
local DEFAULT_DIFFICULTY = board_module.DEFAULT_DIFFICULTY

local DailySeed = lrequire("daily_seed")

local SudokuScreen = lrequire("screen")

local Sudoku = WidgetContainer:extend{
    name        = "sudoku",
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
        text         = _("Sudoku"),
        sorting_hint = "tools",
        callback     = function() self:showGame() end,
    }
end

function Sudoku:getBoard()
    if not self.board then
        self:ensureSettings()
        self.board = SudokuBoard:new()
        local state = self.settings:readSetting("state")
        if not self.board:load(state) then
            self.board:generate(DEFAULT_DIFFICULTY)
        end
    end
    return self.board
end

-- Daily Challenge: a separate save slot from the regular game (own settings
-- key) so starting it never clobbers a regular game in progress. Generated
-- with a date-seeded rng so every player gets the same puzzle on a given
-- calendar day; re-opening the same day resumes the same puzzle+progress
-- instead of silently regenerating.
function Sudoku:getDailyBoard()
    if not self.daily_board then
        self:ensureSettings()
        local today = DailySeed.today()
        local state = self.settings:readSetting("daily_state")
        self.daily_board = SudokuBoard:new()
        local loaded = state and self.daily_board:load(state)
        if not (loaded and self.daily_board.daily_seed == today) then
            self.daily_board:generate(DEFAULT_DIFFICULTY, DailySeed.rng(today))
            self.daily_board.daily_seed = today
        end
    end
    return self.daily_board
end

function Sudoku:isDailyCompletedToday()
    self:ensureSettings()
    local today = DailySeed.today()
    return self.settings:readSetting("daily_completed_" .. today) == true
end

function Sudoku:saveState()
    if self.active_mode == "daily" then
        if not self.daily_board then return end
        self:ensureSettings()
        self.settings:saveSetting("daily_state", self.daily_board:serialize())
        if self.daily_board:isSolved() then
            self.settings:saveSetting("daily_completed_" .. self.daily_board.daily_seed, true)
        end
        self.settings:flush()
        return
    end
    if not self.board then return end
    self:ensureSettings()
    self.settings:saveSetting("state", self.board:serialize())
    self.settings:flush()
end

function Sudoku:showGame()
    if self.screen then return end
    self.active_mode = "regular"
    self.screen = SudokuScreen:new{
        board  = self:getBoard(),
        plugin = self,
    }
    UIManager:show(self.screen)
end

function Sudoku:showDailyChallenge()
    if self.screen then return end
    self.active_mode = "daily"
    self.screen = SudokuScreen:new{
        board  = self:getDailyBoard(),
        plugin = self,
    }
    UIManager:show(self.screen)
end

function Sudoku:onScreenClosed()
    self.screen = nil
end

return Sudoku
