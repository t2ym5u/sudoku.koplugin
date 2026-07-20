-- i18n.lua — Plugin translation module (sudoku-family local copy)
--
-- Drop-in replacement for `local _ = require("gettext")` in plugin screens.
-- Priority: custom table → KOReader gettext → original string.
--
-- This plugin is part of the sudoku_common family (vendors sudoku-common's
-- common/ per-repo), so it has no reliable package.path to game-common's
-- shared i18n module. This file is therefore a self-contained duplicate,
-- vendored identically across the sudoku-family plugins (same pattern as
-- common/sudoku_grid_utils.lua). Only the strings shared by the family's
-- common/base_screen.lua and common/base_board.lua belong in the table
-- below — a plugin's own UI strings (name, description, variant-specific
-- messages) live in that plugin's own `i18n_fr.lua` and get merged in from
-- main.lua:
--   require("i18n").extend(lrequire("i18n_fr"))
--
-- Usage:
--   local _ = require("i18n")   -- works exactly like _() from gettext
--   local i18n = require("i18n")
--   i18n.lang()                  -- returns "fr", "en", etc.

local koreader_t = require("gettext")

local function lang()
    return (G_reader_settings and G_reader_settings:readSetting("language") or "en"):sub(1, 2)
end

local S = {
    ["Close"]       = { fr = "Fermer" },
    ["Rules"]       = { fr = "Règles" },

    ["Easy"]    = { fr = "Facile" },
    ["Medium"]  = { fr = "Moyen" },
    ["Hard"]    = { fr = "Difficile" },
    ["Expert"]  = { fr = "Expert" },

    ["Note: On"]              = { fr = "Notes : actif" },
    ["Note: Off"]             = { fr = "Notes : inactif" },
    ["Note mode enabled."]    = { fr = "Mode notes activé." },
    ["Note mode disabled."]   = { fr = "Mode notes désactivé." },

    ["Show result"]  = { fr = "Voir la solution" },
    ["Hide result"]  = { fr = "Masquer la solution" },
    ["Showing the solution."]              = { fr = "Affichage de la solution." },
    ["Hide result to keep playing."]       = { fr = "Masquez la solution pour continuer à jouer." },

    ["Keep going!"]                     = { fr = "Continuez !" },
    ["Everything looks good!"]          = { fr = "Tout est correct !" },
    ["There are mistakes highlighted in red."] = { fr = "Les erreurs sont mises en évidence en rouge." },

    ["Last move undone."]  = { fr = "Dernier coup annulé." },
    ["Nothing to undo."]   = { fr = "Rien à annuler." },
    ["Puzzle complete!"]   = { fr = "Puzzle terminé !" },
    ["Started a new game."] = { fr = "Nouvelle partie lancée." },

    ["Clear the cell before adding notes."] = { fr = "Effacez la case avant d'ajouter des notes." },
    ["Cell already empty."]                 = { fr = "Case déjà vide." },
    ["This cell is fixed."]                 = { fr = "Cette case est fixe." },
    ["Tap a cell, then pick a number."]     = { fr = "Touchez une case, puis choisissez un chiffre." },
}

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
