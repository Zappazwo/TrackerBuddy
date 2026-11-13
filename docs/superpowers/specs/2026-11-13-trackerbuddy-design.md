# TrackerBuddy – Design

Stand: 2026-11-13 · Client: WoW: Forever 1.60.1 (Build 70938), `## Interface: 16001`

## Ziel und Warum

Ein Jäger hat viele Aufspür-Fähigkeiten (Wildtiere, Humanoide, Verborgenes, Untote, Dämonen …),
dazu kommen Berufs- und Rassenfähigkeiten wie Mineraliensuche, Kräutersuche und Schatzsuche.
Die Fähigkeiten belegen Platz auf den Aktionsleisten, und auf einen Blick sieht man nicht,
welche gerade aktiv ist. TrackerBuddy bündelt alles in **einem** Button. Das Umschalten muss
**auch im Kampf** funktionieren.

## Verhalten

- **Hauptbutton:** quadratisch, so groß wie ein Aktionsbutton. Er zeigt das Icon der aktiven
  Fährte, ohne aktive Fährte ein neutrales Fragezeichen-Icon. Der Tooltip zeigt den Namen der
  aktiven Fährte.
- **Linksklick:** klappt die Liste auf oder zu, auch im Kampf.
- **Liste:** eine Spalte Icon-Buttons über dem Hauptbutton. Sie enthält nur Fährten-**Zauber**,
  die der Charakter kennt. Die aktive Fährte ist hervorgehoben, jeder Eintrag hat einen Tooltip
  mit dem Namen.
- **Klick auf einen Eintrag:** wirkt diese Fährte und schließt die Liste. Das geht auch im Kampf.
- **Verschieben:** Shift + Ziehen, nur außerhalb des Kampfes. Die Position wird pro Charakter
  gespeichert.
- **Wiederbeleben** *(Vorschlag von Claude, leicht entfernbar)*: Nach dem Tod ist die Fährte weg.
  Das Addon schaltet die zuletzt aktive Fährte nach dem Wiederbeleben automatisch wieder ein,
  sobald man außerhalb des Kampfes ist.

## Ziele / Nicht-Ziele / Anti-Ziele

- **Ziele:** Wechseln im Kampf, immer korrektes Icon, keine Lua-Fehler, kein Taint der
  Blizzard-Oberfläche.
- **Nicht-Ziele (vorerst):** Stadt-Filter der Minimap (Auktionator, Flugmeister …),
  Einstellungsfenster, Tastenbelegung, Lokalisierung eigener Texte (Namen kommen aus dem Spiel).
- **Anti-Ziele:** Das Addon darf im Kampf keine „Aktion blockiert“-Meldungen erzeugen und keine
  Blizzard-Frames kaputtmachen.

## Rahmenbedingungen

- Forever nutzt die moderne (Retail-)API. Alte Classic-Globals wie `GetSpellInfo` fehlen,
  stattdessen gibt es `C_Spell.*` und `C_SpellBook.*`.
- Laut Community-Tests funktionieren `C_Minimap.GetNumTrackingTypes()`, `C_Minimap.GetTrackingInfo(i)`
  (`name`, `active`, `type`, `spellID`) und `C_Minimap.SetTracking(i, on)`. Die Werte sind nicht
  geheim. `type == "spell"` steht für Fähigkeiten, `"other"` für Stadt-Filter.
- Im Kampf dürfen Addons sichere Frames nicht per Lua zeigen, verstecken oder umkonfigurieren.
  Das ist nur über Blizzards *Secure Handler*-Snippets möglich.

## Ansätze

| | Ansatz | Bewertung |
|---|---|---|
| A | Lesen und Umschalten über `C_Minimap` | einfach; Umschalten im Kampf ungetestet → **verworfen**, Kampf ist Pflicht |
| B | Nur gesicherte Zauber-Buttons | kampftauglich, aber ohne zuverlässige Anzeige der aktiven Fährte |
| **C** | **Lesen über `C_Minimap`, Umschalten per gesichertem Zauber-Button** | **gewählt:** kampftauglich und mit korrekter Anzeige |

Patrick will im Kampf wechseln können. Damit fällt A weg, und C ist B mit verlässlicher Anzeige.

## Technischer Aufbau (Ansatz C)

- **Dateien:** `TrackerBuddy/TrackerBuddy.toc` und `TrackerBuddy/TrackerBuddy.lua`, in Lua ohne XML.
  SavedVariablesPerCharacter: `TrackerBuddyDB` mit Position und letzter Fährte.
- **Hauptbutton:** `SecureHandlerClickTemplate`. Das `_onclick`-Snippet schaltet die
  Sichtbarkeit des Listen-Frames um, der als Frame-Ref übergeben wird. So klappt die Liste
  auch im Kampf auf und zu.
- **Listeneinträge:** `SecureActionButtonTemplate` mit `type = "spell"` und `spell = <spellID>`.
  Per `SecureHandlerWrapScript` versteckt jeder Klick danach die Liste.
- **Liste aufbauen:** Die Einträge entstehen aus `C_Minimap.GetTrackingInfo`, gefiltert auf
  `type == "spell"`, und zwar nur außerhalb des Kampfes. Kommt im Kampf ein Event, das einen
  Neuaufbau verlangt, merkt sich das Addon das und baut nach `PLAYER_REGEN_ENABLED` neu auf.
  Auslöser sind `PLAYER_LOGIN`, `SPELLS_CHANGED` und `LEARNED_SPELL_IN_SKILL_LINE`.
- **Icon und Hervorhebung:** Die Anzeige reagiert auf `MINIMAP_UPDATE_TRACKING`. Icons und
  Textures dürfen auch im Kampf geändert werden, Icons kommen über `C_Spell.GetSpellTexture(spellID)`.
- **Wiederbeleben:** Bei `PLAYER_ALIVE` und `PLAYER_UNGHOST` schaltet das Addon die gespeicherte
  Fährte per `C_Minimap.SetTracking` ein, sobald man nicht im Kampf ist.

## Offen / Risiken (wird im Spiel geprüft)

1. Schaltet erneutes Wirken der **bereits aktiven** Fährte sie aus? Falls ja, bekommt der aktive
   Eintrag außerhalb des Kampfes `type = nil`. Im Kampf bleibt das Restrisiko, dass die Fährte
   sich ausschaltet, wenn man genau die aktive anklickt.
2. Lösen Fährten-Zauber in Forever die globale Abklingzeit aus? Das ändert nichts am Aufbau, nur an
   der Erwartung.
3. Ob `SecureHandlerClickTemplate` und `SecureHandlerWrapScript` in Forever wie in Retail funktionieren,
   ist sehr wahrscheinlich, aber noch nicht getestet.

## Test

Im Container läuft kein WoW. Dort prüfe ich die Syntax automatisch mit `luac`/`luacheck`. Danach testet
Patrick im Spiel nach einer Checkliste: Liste öffnen und schließen in und außerhalb des Kampfes,
Fährte wechseln in und außerhalb des Kampfes, Icon aktualisiert sich, Mineraliensuche ist dabei,
Position bleibt nach `/reload` erhalten, Fährte ist nach dem Wiederbeleben wieder an.

## Dem Builder überlassen

Exakte Größen und Abstände, Rahmen-Optik, Name des Fallback-Icons, Code-Struktur innerhalb der Lua-Datei.
