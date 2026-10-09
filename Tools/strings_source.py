# -*- coding: utf-8 -*-
"""Single source of truth for every user-facing string of AI CAT (en / es).

Run `python3 Tools/gen_strings.py` after editing: it regenerates
AICat/Resources/Localizable.xcstrings and AICat/Resources/InfoPlist.xcstrings.
Keys are referenced from Swift through `L10n.string("key")` (app) and
`TextKey("key")` (AICatCore). `Tools/validate_project.py` checks that every
referenced key exists here and has both languages.
"""

STRINGS = {
    # ---- app / common -------------------------------------------------------
    "app.name": ("AI CAT", "AI CAT"),
    "app.tagline": ("Learn AI with a curious kitten", "Aprende IA con un gatito curioso"),
    "common.continue": ("Continue", "Continuar"),
    "common.back": ("Back", "Atrás"),
    "common.play": ("Play", "Jugar"),
    "common.next": ("Next", "Siguiente"),
    "common.retry": ("Try again", "Intentar de nuevo"),
    "common.done": ("Done", "Listo"),
    "common.close": ("Close", "Cerrar"),
    "common.cancel": ("Cancel", "Cancelar"),
    "common.ok": ("OK", "OK"),
    "common.yes": ("Yes", "Sí"),
    "common.no": ("No", "No"),
    "common.loading": ("Loading…", "Cargando…"),
    "common.coming_soon": ("Coming soon", "Próximamente"),
    "common.locked": ("Locked", "Bloqueado"),
    "common.level": ("Level", "Nivel"),
    "common.xp": ("XP", "XP"),
    "common.stage": ("Stage", "Etapa"),
    "common.hint": ("Hint", "Pista"),
    "common.skip": ("Skip", "Saltar"),
    "common.settings": ("Settings", "Ajustes"),
    "common.language": ("Language", "Idioma"),
    "common.english": ("English", "Inglés"),
    "common.spanish": ("Spanish", "Español"),
}

INFOPLIST = {
    "CFBundleDisplayName": ("AI CAT", "AI CAT"),
    "CFBundleName": ("AI CAT", "AI CAT"),
}
