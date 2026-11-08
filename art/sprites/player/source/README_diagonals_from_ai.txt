HackSla samurai diagonal sprites (2026-11-08, per pixel-art-player-diagonals-request.md)

Files for Claude import
- player_diag_down.png : 30x30, diagonal front facing lower-right (flip = lower-left)
- player_diag_up.png   : 30x30, diagonal back facing upper-right (flip = upper-left)
- hacksla_samurai_diagonals_30px.png : the two above as one 60x30 sheet
- hacksla_samurai_diagonals_source.png : high-res generated source (green bg)
- hacksla_samurai_diagonals_preview.png : 8x preview of the sheet
- hacksla_samurai_diagonals_compare.png : front (existing, resized to 30) + diag_down + diag_up

Spec
- Transparent, 16 colors, feet aligned to cell bottom, same as existing player sprites
- Together with existing front/back/right (+flips) this completes 8 directions

Known issue
- In diag_up, the drawn sword points up-right; in the other views it points down.
  At 30x30 it reads as a raised sword while walking away.
