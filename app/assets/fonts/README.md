# SaudiRiyal font

`SaudiRiyal-*.ttf` is the OFL-licensed Saudi riyal sign (U+20C1) from the `@emran-alhaddad/saudi-riyal-font`
package. The original also mapped the ASCII letters A, B, C and D (and some private-use code points) to blank
glyphs, which made those letters disappear from every text that falls back to this font. **Only U+20C1 is mapped
in the copies here**; if the font is ever replaced, strip every other cmap entry again (fontTools:
`for st in font['cmap'].tables: st.cmap.pop(cp, None)`).
