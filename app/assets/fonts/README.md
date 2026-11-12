# SaudiRiyal font

`SaudiRiyal-*.ttf` is the OFL-licensed Saudi riyal sign (U+20C1) from the `@emran-alhaddad/saudi-riyal-font`
package. The original also mapped the ASCII letters A, B, C and D (and some private-use code points) to blank
glyphs, which made those letters disappear from every text that falls back to this font. **Only U+20C1 is mapped
in the copies here**; if the font is ever replaced, strip every other cmap entry again (fontTools:
`for st in font['cmap'].tables: st.cmap.pop(cp, None)`).

It also maps the invisible direction and zero-width marks (U+061C, U+200B-200F, U+2028-202E, U+2060-206F, U+FEFF)
to an empty zero-width glyph. Without it, the isolate marks around dates and amounts (`ltrIsolate`) showed as a
box in Arabic, because no font in the fallback chain had a glyph for them.

# Rubik font

`Rubik-Regular/Medium/Bold/ExtraBold.ttf` is the app typeface since the rebrand (2026-11-11): one family for
Latin and Arabic, SIL Open Font License 1.1 (`Rubik-LICENSE.txt`, no reserved font name). They are static
instances (weights 400, 500, 700, 800) of the official variable font `ofl/rubik/Rubik[wght].ttf` from
`github.com/google/fonts`, made with fontTools (`varLib.instancer`, then `subset` with all layout features kept)
and limited to Basic Latin, Latin-1, Arabic (U+0600-06FF), the Arabic presentation forms and common punctuation,
about 130 KB each. Checked after building: Latin letters, Western digits and Arabic letters are present. Rubik has
no riyal sign and no direction marks, so those still come from SaudiRiyal through the fallback list.
