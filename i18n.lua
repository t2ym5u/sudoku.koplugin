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
    ["Close"]       = { fr = "Fermer", es = "Cerrar", de = "Schließen" },
    ["Rules"]       = { fr = "Règles", es = "Reglas", de = "Regeln" },

    ["Easy"]    = { fr = "Facile", es = "Fácil", de = "Leicht" },
    ["Medium"]  = { fr = "Moyen", es = "Medio", de = "Mittel" },
    ["Hard"]    = { fr = "Difficile", es = "Difícil", de = "Schwer" },
    ["Expert"]  = { fr = "Expert", es = "Experto", de = "Experte" },

    ["Note: On"]              = { fr = "Notes : actif", es = "Notas: activadas", de = "Notizen: an" },
    ["Note: Off"]             = { fr = "Notes : inactif", es = "Notas: desactivadas", de = "Notizen: aus" },
    ["Note mode enabled."]    = { fr = "Mode notes activé.", es = "Modo de notas activado.", de = "Notizmodus aktiviert." },
    ["Note mode disabled."]   = { fr = "Mode notes désactivé.", es = "Modo de notas desactivado.", de = "Notizmodus deaktiviert." },

    ["Show result"]  = { fr = "Voir la solution", es = "Ver la solución", de = "Lösung anzeigen" },
    ["Hide result"]  = { fr = "Masquer la solution", es = "Ocultar la solución", de = "Lösung ausblenden" },
    ["Showing the solution."]              = { fr = "Affichage de la solution.", es = "Mostrando la solución.", de = "Lösung wird angezeigt." },
    ["Hide result to keep playing."]       = { fr = "Masquez la solution pour continuer à jouer.", es = "Oculte la solución para seguir jugando.", de = "Lösung ausblenden, um weiterzuspielen." },

    ["Keep going!"]                     = { fr = "Continuez !", es = "¡Sigue así!", de = "Weiter so!" },
    ["Everything looks good!"]          = { fr = "Tout est correct !", es = "¡Todo está correcto!", de = "Alles sieht gut aus!" },
    ["There are mistakes highlighted in red."] = { fr = "Les erreurs sont mises en évidence en rouge.", es = "Hay errores resaltados en rojo.", de = "Es sind Fehler rot markiert." },

    ["Last move undone."]  = { fr = "Dernier coup annulé.", es = "Última jugada deshecha.", de = "Letzter Zug rückgängig gemacht." },
    ["Nothing to undo."]   = { fr = "Rien à annuler.", es = "Nada que deshacer.", de = "Nichts rückgängig zu machen." },
    ["Puzzle complete!"]   = { fr = "Puzzle terminé !", es = "¡Puzle completado!", de = "Rätsel vollständig!" },
    ["Started a new game."] = { fr = "Nouvelle partie lancée.", es = "Nueva partida iniciada.", de = "Neues Spiel gestartet." },

    ["Clear the cell before adding notes."] = { fr = "Effacez la case avant d'ajouter des notes.", es = "Borre la casilla antes de añadir notas.", de = "Zelle leeren, bevor Notizen hinzugefügt werden." },
    ["Cell already empty."]                 = { fr = "Case déjà vide.", es = "La casilla ya está vacía.", de = "Zelle ist bereits leer." },
    ["This cell is fixed."]                 = { fr = "Cette case est fixe.", es = "Esta casilla es fija.", de = "Diese Zelle ist vorgegeben." },
    ["Tap a cell, then pick a number."]     = { fr = "Touchez une case, puis choisissez un chiffre.", es = "Toque una casilla y elija un número.", de = "Zelle antippen und dann eine Zahl wählen." },
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
