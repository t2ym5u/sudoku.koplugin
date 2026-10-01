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
local _              = require("i18n")

-- Play-session stats, shared with every other game through
-- game_stats.lua (Dashboard reads it). pcall'd: an install whose
-- common/ predates sudoku-common 1.4.0 has no stats_exporter.lua,
-- and a bare require would take the whole plugin down with it.
local ok_stats, StatsExporter = pcall(require, "stats_exporter")

require("i18n").extend(lrequire("i18n_fr"))

local board_module       = lrequire("board")
local SudokuBoard        = board_module.SudokuBoard
local DEFAULT_DIFFICULTY = board_module.DEFAULT_DIFFICULTY

local DailySeed = lrequire("daily_seed")

local SudokuScreen = lrequire("screen")
local generateWithProgress = lrequire("common/base_screen").generateWithProgress

-- Spelled out rather than read off self.name: ReaderUI/FileManager
-- rewrite an instance's name to "reader<id>"/"filemanager<id>" right
-- after it is built, so self.name is not the plugin id after :init().
local PLUGIN_ID = "sudoku"

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
            generateWithProgress(self.board, DEFAULT_DIFFICULTY)
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
            generateWithProgress(self.daily_board, DEFAULT_DIFFICULTY, DailySeed.rng(today))
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
    self._session_start = os.time()
    self.active_mode = "regular"
    self.screen = SudokuScreen:new{
        board  = self:getBoard(),
        plugin = self,
    }
    UIManager:show(self.screen)
end

function Sudoku:showDailyChallenge()
    if self.screen then return end
    self._session_start = os.time()
    self.active_mode = "daily"
    self.screen = SudokuScreen:new{
        board  = self:getDailyBoard(),
        plugin = self,
    }
    UIManager:show(self.screen)
end

function Sudoku:onScreenClosed()
    local elapsed = self._session_start and (os.time() - self._session_start) or 0
    self._session_start = nil
    if ok_stats then
        local cur = StatsExporter:get(PLUGIN_ID) or {}
        StatsExporter:record(PLUGIN_ID, {
            sessions    = (cur.sessions or 0) + 1,
            last_played = os.time(),
            time_played = (cur.time_played or 0) + elapsed,
        })
    end
    self.screen = nil
end

-- KOReader >= 2026.07 plugin management (PluginLoader, PR #15240).
-- PluginLoader removes self.settings_file itself; what is left is the
-- open game screen and this game's row in the shared game_stats.lua.
function Sudoku:stopPlugin()
    if self.screen then
        UIManager:close(self.screen)
        self.screen = nil
    end
end

function Sudoku:deletePluginSettings()
    if ok_stats then StatsExporter:remove(PLUGIN_ID) end
end

return Sudoku
