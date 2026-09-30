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

    -- Hints (common/base_screen.lua :onHint). Three taps: where to look, why,
    -- then the value. R/C are row/column -- localised to L/C in French.
    ["Hint"] = { fr = "Astuce", es = "Pista", de = "Tipp" },
    ["There is a wrong value on the board."] = { fr = "Une valeur est incorrecte dans la grille.", es = "Hay un valor incorrecto en la cuadrícula.", de = "Ein Wert im Gitter ist falsch." },
    ["Nothing left to fill in."] = { fr = "Il ne reste rien à remplir.", es = "No queda nada por rellenar.", de = "Es ist nichts mehr auszufüllen." },
    ["No purely logical step is available here."] = { fr = "Aucune déduction purement logique n'est possible ici.", es = "Aquí no hay ninguna deducción puramente lógica.", de = "Hier ist kein rein logischer Schritt möglich." },

    ["There is a cell you can solve in row %1."] = { fr = "Une case peut être résolue dans la ligne %1.", es = "Hay una casilla resoluble en la fila %1.", de = "In Zeile %1 lässt sich eine Zelle lösen." },
    ["There is a cell you can solve in column %1."] = { fr = "Une case peut être résolue dans la colonne %1.", es = "Hay una casilla resoluble en la columna %1.", de = "In Spalte %1 lässt sich eine Zelle lösen." },
    ["There is a cell you can solve in the box around R%1C%2."] = { fr = "Une case peut être résolue dans le bloc autour de L%1C%2.", es = "Hay una casilla resoluble en la caja alrededor de F%1C%2.", de = "Im Block um Z%1S%2 lässt sich eine Zelle lösen." },
    ["There is a cell you can solve in the shaded region around R%1C%2."] = { fr = "Une case peut être résolue dans la région colorée autour de L%1C%2.", es = "Hay una casilla resoluble en la región sombreada alrededor de F%1C%2.", de = "In der markierten Region um Z%1S%2 lässt sich eine Zelle lösen." },

    ["R%1C%2 has only one value left."] = { fr = "L%1C%2 n'a plus qu'une seule valeur possible.", es = "A F%1C%2 solo le queda un valor posible.", de = "Für Z%1S%2 bleibt nur ein Wert übrig." },
    ["%1 fits in only one cell of row %2."] = { fr = "Le %1 ne peut aller que dans une seule case de la ligne %2.", es = "El %1 solo cabe en una casilla de la fila %2.", de = "Die %1 passt nur in eine Zelle von Zeile %2." },
    ["%1 fits in only one cell of column %2."] = { fr = "Le %1 ne peut aller que dans une seule case de la colonne %2.", es = "El %1 solo cabe en una casilla de la columna %2.", de = "Die %1 passt nur in eine Zelle von Spalte %2." },
    ["%1 fits in only one cell of that box."] = { fr = "Le %1 ne peut aller que dans une seule case de ce bloc.", es = "El %1 solo cabe en una casilla de esa caja.", de = "Die %1 passt nur in eine Zelle dieses Blocks." },
    ["%1 fits in only one cell of that region."] = { fr = "Le %1 ne peut aller que dans une seule case de cette région.", es = "El %1 solo cabe en una casilla de esa región.", de = "Die %1 passt nur in eine Zelle dieser Region." },
    ["You need %1 first."] = { fr = "Il faut d'abord repérer %1.", es = "Antes hay que detectar %1.", de = "Dazu muss man zuerst %1 erkennen." },
    ["R%1C%2 = %3. Hints used: %4."] = { fr = "L%1C%2 = %3. Astuces utilisées : %4.", es = "F%1C%2 = %3. Pistas usadas: %4.", de = "Z%1S%2 = %3. Verwendete Tipps: %4." },

    -- Technique names, as they read inside "You need %1 first."
    ["locked candidates"] = { fr = "des candidats verrouillés", es = "candidatos bloqueados", de = "blockierte Kandidaten" },
    ["a naked pair"]      = { fr = "une paire nue", es = "un par desnudo", de = "ein nacktes Paar" },
    ["a hidden pair"]     = { fr = "une paire cachée", es = "un par oculto", de = "ein verstecktes Paar" },
    ["a naked triple"]    = { fr = "un triplet nu", es = "un trío desnudo", de = "ein nackter Drilling" },
    ["a hidden triple"]   = { fr = "un triplet caché", es = "un trío oculto", de = "ein versteckter Drilling" },
    ["a naked quad"]      = { fr = "un quadruplet nu", es = "un cuarteto desnudo", de = "ein nackter Vierling" },
    ["an X-Wing"]         = { fr = "un X-Wing", es = "un X-Wing", de = "ein X-Wing" },
    ["a Swordfish"]       = { fr = "un Swordfish", es = "un Swordfish", de = "ein Swordfish" },
    ["an XY-Wing"]        = { fr = "un XY-Wing", es = "un XY-Wing", de = "ein XY-Wing" },
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
