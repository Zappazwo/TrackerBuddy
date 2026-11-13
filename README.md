# TrackerBuddy

Ein Addon für WoW: Forever (Client 1.60.1). Es zeigt dem Jäger genau einen Button mit dem aktuell aktiven Tracking-Symbol. Ein Klick öffnet eine Liste aller bekannten Tracking-Fähigkeiten (Jäger-Tracks plus Minerale/Kräuter finden usw.). Ein Klick auf einen Eintrag wirkt den Zauber und schließt die Liste, auch im Kampf.

## Installation

1. Ordner `TrackerBuddy` (der Ordner im Repo, nicht das ganze Repo) kopieren nach:
   `World of Warcraft\_forever_\Interface\AddOns\`
2. Hinweis: Der Name des Forever-Installationsordners ist nicht sicher. Schau im WoW-Ordner nach, welcher Ordner neben `_classic_era_` bzw. `_retail_` liegt, und nimm den.
3. Spiel starten (oder `/reload`). Das Addon muss im AddOn-Menü der Charakterauswahl aktiviert sein.

## Benutzung

- Linksklick auf den Button: Liste öffnen/schließen (auch im Kampf).
- Klick auf einen Eintrag: Tracking wird gewirkt, die Liste schließt sich.
- Der aktive Eintrag ist golden hervorgehoben. Tooltips zeigen den Namen.
- Shift + Ziehen: Button verschieben (nicht im Kampf). Die Position wird pro Charakter gespeichert.
- Nach dem Wiederbeleben wird das zuletzt aktive Tracking automatisch wieder eingeschaltet (sobald du nicht mehr im Kampf bist).

## Bekannte Grenzen

- Außerhalb des Kampfs tut ein Klick auf den bereits aktiven Eintrag nichts, damit du das Tracking nicht aus Versehen ausschaltest.
- Im Kampf ist jeder Eintrag anklickbar. Ein Klick auf das aktive Tracking kann es dort ausschalten.

## Test-Checkliste im Spiel

Vorher `/console scriptErrors 1` eingeben, damit Lua-Fehler sichtbar werden.

- [ ] Liste öffnet und schließt sich außerhalb des Kampfs
- [ ] Liste öffnet und schließt sich im Kampf
- [ ] Tracking wechseln außerhalb des Kampfs
- [ ] Tracking wechseln im Kampf
- [ ] Klick auf einen Eintrag schließt die Liste (außerhalb und im Kampf)
- [ ] Icon aktualisiert sich nach dem Wechsel
- [ ] Minerale finden / Kräuter finden erscheinen, wenn gelernt
- [ ] Klick auf den aktiven Eintrag außerhalb des Kampfs lässt das Tracking an
- [ ] Position bleibt nach `/reload` erhalten
- [ ] Nach Tod und Wiederbeleben kommt das letzte Tracking zurück
- [ ] Keine Lua-Fehler (`/console scriptErrors 1`)

## Entwicklung

Tests der Kernlogik laufen ohne Spiel, nötig ist `lua5.1`:

```bash
bash tests/run.sh
```
