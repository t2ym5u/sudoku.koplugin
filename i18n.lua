-- i18n.lua — Plugin translation module
--
-- Drop-in replacement for `local _ = require("gettext")`.
-- Priority: custom table → KOReader gettext → original string.
--
-- This module holds no strings of its own, on purpose. `package.loaded` is
-- keyed by module name alone, so every `require("i18n")` on the device shares
-- one slot and the first plugin loaded takes it — a table defined here would
-- simply never be consulted on any install that also has an alphabetically
-- earlier plugin. All of this plugin's strings therefore live in its own
-- `i18n_fr.lua`, which is merged into whichever module won the slot:
--   require("i18n").extend(lrequire("i18n_fr"))
--
-- This file still matters: `common/` points at sudoku-common, which ships no
-- i18n.lua, so on an install where this plugin is the first one loaded it is
-- the module that takes the slot.
--
-- Usage:
--   local _ = require("i18n")   -- works exactly like _() from gettext
--   local i18n = require("i18n")
--   i18n.lang()                  -- returns "fr", "en", etc.

local koreader_t = require("gettext")

local function lang()
    return (G_reader_settings and G_reader_settings:readSetting("language") or "en"):sub(1, 2)
end

local S = {}

local function translate(s)
    local l = lang()
    if l ~= "en" then
        local entry = S[s]
        if entry and entry[l] then return entry[l] end
    end
    return koreader_t(s)
end

local function extend(tbl)
    for k, v in pairs(tbl) do
        S[k] = v
    end
end

return setmetatable({ lang = lang, extend = extend }, {
    __call = function(_, s) return translate(s) end,
})
