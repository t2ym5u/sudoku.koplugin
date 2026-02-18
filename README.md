# sudoku.koplugin

A Sudoku plugin for [KOReader](https://github.com/koreader/koreader).

## Features

- **Five grid sizes** — 4×4, 6×6, 9×9, 12×12 and 16×16 (digits 10–16 shown as A–G)
- **Three difficulty levels** — Easy, Medium, Hard
- **Landscape support** — buttons displayed to the right of the grid in landscape orientation
- **Note mode** — pencil in candidate digits as small annotations
- **Digit completion** — a digit button is greyed out once all its instances are placed
- **Check** — highlights incorrect cells with a cross mark
- **Reveal solution** — shows the full solution (disables editing)
- **Undo** — step back through your moves
- **Auto-save** — game state is saved automatically and restored on next launch

## Installation

1. Download `sudoku.koplugin.zip` from the [latest release](../../releases/latest).
2. Extract into the `plugins/` folder of your KOReader data directory
   (e.g. `/mnt/us/extensions/` on Kindle, `koreader/plugins/` on Kobo).
3. Restart KOReader.
4. Open the menu → **Tools** → **Sudoku**.

## Usage

| Action | How |
|--------|-----|
| Select a cell | Tap it |
| Enter a digit | Tap the digit button |
| Erase a cell | Tap **Erase** |
| Toggle note mode | Tap **Note: Off / On** |
| Undo last move | Tap **Undo** |
| Check progress | Tap **Check** |
| New game | Tap **New game** |
| Change grid size | Tap **Grid** |
| Change difficulty | Tap **Diff** |

## License

GPL-3.0 — see [LICENSE](LICENSE).
