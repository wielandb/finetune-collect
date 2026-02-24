Verwende in Godot ausschließlich Tabs als einrückungen, und zwar ein mal \t pro Einrückungsstufe. Eine Zeile sollte nicht mit Leerzeichen beginnen.

In Godot solltest du vermeiden den Walross-Operator (:=) zu verwenden, wenn es nicht unbedingt notwendig ist. Normale Zuweisungen sind eigentlich normale Gleichheitszeiten.

Versuche den Resource import error fehler zu vermeiden, indem du den Editor kurz headless startest, so z.b.:

Aus dem Projekt-Root oder mit --path

godot -e --headless --path src --quit-after 2
godot --headless --path src --script tests/test_schema_title_sync.gd

Du kannst eine Instanz im Projektordner headless ausführen, um deinen Code zu testen. Schreibe gerne auch so einfach tests die die Funktionalität von Klassen etc testen. Nutze immer die Version 4.6.1 um alles zu testen.

Nutze den Godot MCP Server um die Godot Dokumentation abzurufen und nutze den OpenAI MCP Server um die OpenAI Dokumentation abzurufen.

Wenn du temporäre Tests/Skripte anlegst denke daran sie und ihre .uuid Dateien zu entfernen wenn du fertig bist.

Verwende in UI-Texten im deutschen immer korrekte Umlaute wie "ä" anstatt umschreibungen wie "ae".