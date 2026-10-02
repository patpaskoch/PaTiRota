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
- [ ] PT-ROTA-002 PaTiRota erscheint in der AddOn-Liste mit Beschreibung (noch ohne eigenes Icon, keine weiße Textur)
- [ ] PT-ROTA-003 Login und `/reload` ohne Lua-Fehler
- [ ] PT-ROTA-004 `/prota debug`: Cooldown-API, Usable-API, GCD-Referenz 61304 lesbar ja/nein und je Platz Zustand
  und Button-Zauber (Ausgabe melden)

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

- [ ] PT-ROTA-020 Zaubername eintippen + Enter: Platz zeigt Icon und Namen, Fenster zeigt den Skill
- [ ] PT-ROTA-021 Zauber-ID eintippen + Enter funktioniert ebenso
- [ ] PT-ROTA-022 Zauber aus dem Zauberbuch auf einen Platz ziehen: wird übernommen
- [ ] PT-ROTA-023 Unbekannter Name: Chat-Hinweis „kein Zauber … gefunden“, Platz unverändert
- [ ] PT-ROTA-024 Leer + Enter leert den Platz; Hoch/Runter ändern die Reihenfolge, das Fenster folgt
- [ ] PT-ROTA-025 Derselbe Zauber auf einem zweiten Platz: die Plätze tauschen, nie doppelt
- [ ] PT-ROTA-026 Slots bleiben nach `/reload` und Relog; „Standard wiederherstellen“ behält die Slots
- [ ] PT-ROTA-027 Nicht gelernter Zauber im Slot: „nicht gelernt“, nicht hervorgehoben, Klick wirkt nichts

## Cooldowns / Empfehlung

- [ ] PT-ROTA-030 Bereiter Skill: „BEREIT“ (grün)
- [ ] PT-ROTA-031 Nach dem Wirken: Restzeit zählt herunter, danach wieder BEREIT
- [ ] PT-ROTA-032 Globaler Cooldown: andere Skills zeigen „GCD“, die Hervorhebung springt nicht durch die Liste
- [ ] PT-ROTA-033 Hervorgehoben ist immer der höchste bereite Platz; „Nächstes: …“ oben stimmt
- [ ] PT-ROTA-034 Alles auf Abklingzeit: „Nächstes: X in n s“ = der Skill, der zuerst fertig wird
- [ ] PT-ROTA-035 Zu wenig Mana: „nicht nutzbar“, nicht empfohlen

## Feste Cast-Buttons

- [ ] PT-ROTA-040 Klick auf einen Skill wirkt genau diesen Zauber auf das aktuelle Ziel (ein Klick, ein Zauber)
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
- [ ] PT-ROTA-062 Icon in der AddOn-Liste, sobald die Grafik ergänzt ist
