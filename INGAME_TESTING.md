# Ingame Testing – PaTiRota

World of Warcraft: Forever
Interface: 16001

Diese Datei dokumentiert ausschließlich Tests im echten WoW-Client.

Automatisierte Tests, CI und Code Review zählen NICHT als Ingame-Verifikation.
Regeln und Eintragen von Ergebnissen: [PaTiAdmin/docs/TESTING.md](https://github.com/patpaskoch/PaTiAdmin/blob/main/docs/TESTING.md#in-game-test-files).

## Legende

- [ ] offen / noch nicht bestätigt
- [x] vom Owner im echten Client bestätigt
- ❌ FAIL = im echten Client fehlgeschlagen
- 🔧 FIX IMPLEMENTED = Codefix vorhanden, Retest noch offen
- ✅ VERIFIED = erfolgreich im echten Client bestätigt
- MANUAL RETEST REQUIRED = erneuter Test notwendig

## Installation / Laden

- [ ] PT-ROTA-001 Fresh Install aus dem Release-ZIP: genau ein Ordner `PaTiRota/`, Addon lädt allein
- [ ] PT-ROTA-002 PaTiRota erscheint in der AddOn-Liste mit Beschreibung
- [ ] PT-ROTA-003 Login und `/reload` ohne Lua-Fehler
- [x] PT-ROTA-004 `/prota debug`: Cooldown-API, Usable-API, GCD-Referenz 61304 lesbar ja/nein und je Platz Zustand
  und Button-Zauber (Ausgabe melden)
  - ✅ VERIFIED 2026-10-03
  - Owner: `/prota debug` funktioniert. Außerhalb des Kampfes: Cooldown-API C_Spell.GetSpellCooldown, Usable-API
    C_Spell, GCD 61304 readable false; Blitzschlag (403) und Erdschock (8042) known true, READY, Button-Zauber
    richtig; kein abgefangener API-Fehler. Im Kampf: Combat yes, beide known true, beide UNKNOWN, Buttons behalten
    ihren Zauber.

## Fenster

- [ ] PT-ROTA-010 `/prota`, `/patirota`, `/prota toggle` blenden das Fenster ein und aus; `/prota show`, `hide`
- [ ] PT-ROTA-011 Am Header verschieben; Position bleibt nach `/reload`
- [ ] PT-ROTA-012 Lock/Unlock, Größe (Scale) und Panel-Deckkraft wirken
- [ ] PT-ROTA-013 ••• → Einklappen: nur der Header bleibt; Ausklappen; bleibt nach `/reload`
- [ ] PT-ROTA-014 Ohne Skills: Hinweis „Noch keine Skills …“, kein leeres Fenster
- [ ] PT-ROTA-015 Test Mode `/prota test`: vier Beispiel-Skills, Sturmschlag hervorgehoben und BEREIT, 3.2 s / 6.8 s,
  TEST-Badge; Klick wirkt nichts
- [ ] PT-ROTA-016 deDE: alle Texte deutsch, keine Schlüsselnamen, nichts abgeschnitten (Einstellungen, Zeilen)

## Einstellungen / Slots

- [x] PT-ROTA-020 Zaubername eintippen + Enter: Platz zeigt Icon und Namen, Fenster zeigt den Skill
  - ✅ VERIFIED 2026-10-04
  - Owner: Zaubername + Enter funktioniert.
- [x] PT-ROTA-021 Zauber-ID eintippen + Enter funktioniert ebenso
  - ✅ VERIFIED 2026-10-04
  - Owner: Zauber-ID + Enter geht auch.
- [x] PT-ROTA-022 Zauber aus dem Zauberbuch auf einen Platz ziehen: wird übernommen
  - ✅ VERIFIED 2026-10-04
  - Owner: Ziehen aus dem Zauberbuch funktioniert auch.
- [ ] PT-ROTA-023 Unbekannter Name: Chat-Hinweis „kein Zauber … gefunden“, Platz unverändert
- [x] PT-ROTA-024 Leer + Enter leert den Platz; Hoch/Runter ändern die Reihenfolge, das Fenster folgt
  - ✅ VERIFIED 2026-10-04
  - Owner: Hoch/Runter funktionieren; Platz leeren (leer + Enter) funktioniert.
  - Owner-Wunsch: Pfeile statt Text bei Hoch/Runter → PT-ROTA-066
- [x] PT-ROTA-025 Derselbe Zauber auf einem zweiten Platz: die Plätze tauschen, nie doppelt
  - ✅ VERIFIED 2026-10-04
  - Owner: derselbe Zauber auf einem zweiten Platz: die Plätze tauschen.
- [x] PT-ROTA-026 Slots bleiben nach `/reload` und Relog; „Standard wiederherstellen“ behält die Slots
  - ✅ VERIFIED 2026-10-04
  - Owner: Plätze bleiben nach `/reload`; „Standard wiederherstellen“ behält die Plätze.
- [ ] PT-ROTA-027 Nicht gelernter Zauber im Slot: „nicht gelernt“, nicht hervorgehoben, Klick wirkt nichts
- [x] PT-ROTA-065 Einstellungen: Hinweis „Eintippen oder aus dem Zauberbuch ziehen“ steht über der Skill-Liste, Hinweis
  zur Tastenbelegung (Pfad ESC > Tastaturbelegung > PaTiRota) darunter; nichts abgeschnitten oder überlappt (deDE)
  - 🔧 FIX IMPLEMENTED 2026-10-04 (Owner-Wunsch: Drag&Drop-Info über, Tasten-Info unter die Liste)
  - ✅ VERIFIED 2026-10-04
  - Owner: beide Hinweise stehen so da (oben Eintippen/Ziehen, unten Tastenbelegung).
- [ ] PT-ROTA-066 Einstellungen: Hoch/Runter sind Pfeile (^ / v) statt Text; Tooltip „Hoch“ / „Runter“; bei Platz 1
  ist ^ und bei Platz 10 v ausgegraut; Klick verschiebt wie vorher
  - 🔧 FIX IMPLEMENTED 2026-10-04 (Owner-Wunsch: Pfeile statt Text)
  - MANUAL RETEST REQUIRED

## Cooldowns / Empfehlung

- [ ] PT-ROTA-030 Bereiter Skill: „BEREIT“ (grün)
- [ ] PT-ROTA-031 Nach dem Wirken: Restzeit zählt herunter, danach wieder BEREIT
  - ❌ FAIL 2026-10-03
  - Im echten Kampf zeigen die bekannten und wirkbaren Skills Blitzschlag (403) und Erdschock (8042) UNKNOWN /
    „unklar“; kein Countdown.
  - 🔧 FIX IMPLEMENTED 2026-10-03
  - Der Cooldown-Adapter nahm die Tabelle von C_Spell.GetSpellCooldown auch mit unlesbaren Werten und fragte
    GetSpellCooldown nie; jetzt gewinnt die erste Quelle mit lesbaren Werten, `/prota debug` zeigt Quelle und
    Lesbarkeit je API. Echt geheime Werte werden nicht umgangen („im Kampf nicht lesbar“).
  - MANUAL RETEST REQUIRED
- [ ] PT-ROTA-032 Globaler Cooldown: andere Skills zeigen „GCD“, die Hervorhebung springt nicht durch die Liste
- [ ] PT-ROTA-033 Hervorgehoben ist immer der höchste bereite Platz; „Nächstes: …“ oben stimmt
  - ❌ FAIL 2026-10-03
  - Im echten Kampf: „Nächstes: nichts Lesbares bereit“, obwohl Blitzschlag und Erdschock bekannt und über ihre
    festen Buttons wirkbar sind.
  - 🔧 FIX IMPLEMENTED 2026-10-03
  - Folgt aus dem Fix von PT-ROTA-031 (lesbare Quelle statt UNKNOWN).
  - MANUAL RETEST REQUIRED
- [ ] PT-ROTA-034 Alles auf Abklingzeit: „Nächstes: X in n s“ = der Skill, der zuerst fertig wird
- [ ] PT-ROTA-035 Zu wenig Mana: „nicht nutzbar“, nicht empfohlen
- [ ] PT-ROTA-036 Im Kampf `/prota debug`: je Platz „source modern | legacy | none“ und je API „call ok, start/duration
  readable | secret | missing“ (Ausgabe melden); geheime Werte erscheinen nie als Zahl
- [ ] PT-ROTA-037 Ist der Cooldown im Kampf wirklich geheim: Status „im Kampf nicht lesbar“ (nicht „unklar“), Tooltip
  erklärt es, keine Empfehlung wird erfunden; der Button wirkt trotzdem
- [x] PT-ROTA-038 Abklingzeit-Uhr am Icon: nach dem Wirken läuft über dem Skill-Icon die WoW-Uhr ab, auch im Kampf, wenn die
  Anzeige „im Kampf nicht lesbar“ sagt (`/prota debug`: „clock SetCooldown“ oder „clock duration object“; Ausgabe melden)
  - ❌ FAIL 2026-10-03
  - Owner: im Kampf keine Uhr am Icon. Ursache noch offen (`/prota debug` im Kampf: „clock …“ und „last caught API error“).
  - Ursache: in den Einstellungen war „Abklingzeit-Uhr am Icon“ aus (`/prota debug`: „clock off“).
  - ✅ VERIFIED 2026-10-03
  - Owner: mit eingeschalteter Uhr läuft bei Erdschock (8042) im Kampf die Uhr über dem Icon. Blitzschlag (403) hat
    keine eigene Abklingzeit (nur GCD), daher dort keine Uhr — erwartet.
- [ ] PT-ROTA-039 Einstellungen → „Abklingzeit-Uhr am Icon“ aus: keine Uhr; an: Uhr wieder da; kein Lua-Fehler, Klick auf das
  Icon wirkt weiterhin genau den Zauber des Platzes
- [x] PT-ROTA-064 Im Kampf mit Uhr: während die Abklingzeit läuft, liegt der dunkle Uhr-Schatten über dem Icon; ist sie
  abgelaufen, ist das Icon wieder voll farbig (wie bei der Blizzard-Aktionsleiste)
  - ❌ FAIL 2026-10-03
  - Owner: nichts wird farbig (keine Uhr, Icon bleibt grau).
  - Ursache: die Uhr war in den Einstellungen aus („clock off“, siehe PT-ROTA-038).
  - ✅ VERIFIED 2026-10-03
  - Owner: mit eingeschalteter Uhr ist das Icon dunkel, solange die Uhr läuft, und danach wieder farbig.

## Feste Cast-Buttons

- [x] PT-ROTA-040 Klick auf einen Skill wirkt genau diesen Zauber auf das aktuelle Ziel (ein Klick, ein Zauber)
  - ✅ VERIFIED 2026-10-03
  - Owner: Blitzschlag-Button wirkt Blitzschlag, Erdschock-Button wirkt Erdschock — auch während die Anzeige
    „unklar“ zeigt. Ein Klick bleibt die explizite Spieleraktion.
- [ ] PT-ROTA-041 Klick auf einen nicht hervorgehobenen Skill wirkt genau diesen (nicht den empfohlenen)
- [ ] PT-ROTA-042 Im Kampf: Buttons behalten ihren Zauber, nur die Hervorhebung wandert; kein automatisches Zaubern
- [ ] PT-ROTA-043 Slot im Kampf ändern: Hinweis „nach dem Kampf“, Buttons ändern sich erst nach dem Kampf
- [ ] PT-ROTA-044 Tastenbelegung pro Platz (ESC > Tastaturbelegung > PaTiRota): Taste wirkt den Zauber dieses Platzes
  (echten Menüpfad melden); PaTiRota setzt selbst keine Taste
- [ ] PT-ROTA-045 Tastenbelegung bei ausgeblendetem oder eingeklapptem Fenster (Verhalten melden)

## Combat / Sicherheit

- [ ] PT-ROTA-050 Kein Lua-Fehler im Kampf
- [ ] PT-ROTA-051 Keine `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN`; `taint.log` ohne PaTiRota-Eintrag
- [ ] PT-ROTA-052 Im Kampf gesperrt mit Hinweis: Ausblenden, Einklappen, Test Mode, Position zurücksetzen

## Combined

- [ ] PT-ROTA-060 Zusammen mit allen PaTi-Addons geladen: kein Lua-Fehler, `/prota` antwortet nur PaTiRota
- [ ] PT-ROTA-061 PaTiSuite: „Rota“ erscheint (nach Tank); Ein-/Ausblenden wirkt; Zustand bleibt nach `/reload`
- [ ] PT-ROTA-062 Icon in der AddOn-Liste korrekt (Rotationspfeile mit Skill-Icons), keine weiße oder fehlende Textur
