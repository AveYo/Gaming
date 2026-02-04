Settings - Personalization - Themes - Mouse cursor - Customize pointer image
Browse under Normal select, and pick [tarik.cur](/tarik.cur)

Press `Win`+`R` (Run dialog) and enter:
`reg add HKCU\Environment /v SDL_MOUSE_RELATIVE_CURSOR_VISIBLE /d 1 /f`

Log off / Exit Steam, then reopen it, and launch CS2!

---
To undo it,
the Normal select cursor has a Reset button
and in the Run dialog enter:
`reg delete HKCU\Environment /v SDL_MOUSE_RELATIVE_CURSOR_VISIBLE /f`
then Exit Steam