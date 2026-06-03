Verwende in Godot ausschließlich Tabs als einrückungen, und zwar ein mal \t pro Einrückungsstufe. Eine Zeile sollte nicht mit Leerzeichen beginnen.

In Godot solltest du vermeiden den Walross-Operator (:=) zu verwenden, wenn es nicht unbedingt notwendig ist. Normale Zuweisungen sind eigentlich normale Gleichheitszeiten.

Versuche den Resource import error fehler zu vermeiden, indem du den Editor kurz headless startest, so z.b.:

Aus dem Projekt-Root oder mit --path. Nutze dafür immer die neueste Godot-Runtime, die im Repo-Ordner `godot-runtime` liegt. Wähle die höchste Version und nutze für Headless-Tests bevorzugt die passende `*_console.exe`.

Beispiel in PowerShell:

```
$godot = Get-ChildItem .\godot-runtime\Godot_v*-stable_win64_console.exe | Sort-Object { [version]($_.BaseName -replace '^Godot_v([0-9.]+)-.*$', '$1') } | Select-Object -Last 1 -ExpandProperty FullName
& $godot -e --headless --path src --quit-after 2
& $godot --headless --path src --script tests/test_schema_title_sync.gd
```

Du kannst eine Instanz im Projektordner headless ausführen, um deinen Code zu testen. Schreibe gerne auch so einfache Tests, die die Funktionalität von Klassen etc. testen.

Nutze den Godot MCP Server um die Godot Dokumentation abzurufen und nutze den OpenAI MCP Server um die OpenAI Dokumentation abzurufen.

Wenn du temporäre Tests/Skripte anlegst denke daran sie und ihre .uuid Dateien zu entfernen wenn du fertig bist.

Verwende in UI-Texten im deutschen immer korrekte Umlaute wie "ä" anstatt umschreibungen wie "ae".



Führe nach jedem erfolgreichen implementieren oder ändern eines Features den Befehl

python "E:\Dokumente\BotsVMSync\wiki-agent\extern\create_message_queue_json.py" --audio-file "E:\Dokumente\BotsVMSync\wiki-agent\extern\standard_voicemsg\codex_agent.ogg" --text "Fortschrittstext hier"

aus. Der Text soll Informationen darüber enthalten, was du gemacht hast und was in dem Projekt jetzt anders ist/welche Features jetzt existieren oder was geändert wurde. Erwähne immer auch den Namen des Projektes.



Brich niemals ab, weil Sachen "zu lange dauern". Sprecheridentifizierung und Rendering und alle Prozesse allgemein dürfen so lange brauchen wie sie eben brauchen, füge von dir selbst aus keine "Optimierungen" ein.
