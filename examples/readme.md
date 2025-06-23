# Beispiel Fine-Tuning Dateien

Dieses Verzeichnis enthält verschiedene kleine Fine-Tuning Projekte, die die unterschiedlichen Möglichkeiten von **finetune-collect** demonstrieren. Jede Datei ist im Projektformat der Anwendung gespeichert und kann direkt geladen werden.

| Datei | Zweck |
|-------|------|
| `openai-dpo-sample.json` | Minimalbeispiel für Direct Preference Optimization mit einer bevorzugten und einer abgelehnten Antwort. |
| `openai-simple-conversation.json` | Normale Unterhaltung bestehend aus einer Benutzer- und einer Assistentennachricht. |
| `openai-system-message-sample.json` | Beispiel für eine Systemnachricht innerhalb der Unterhaltung. |
| `openai-global-system-message-sample.json` | Die Systemnachricht wird global in den Einstellungen gespeichert. |
| `openai-function-call-sample.json` | Demonstriert einen Funktionsaufruf des Assistenten. |
| `openai-pre-text-function-call-sample.json` | Funktionsaufruf, bei dem der Assistent vor der Ausführung Text sendet. |
| `openai-local-tool-execution-sample.json` | Lokaler Funktionsaufruf über das plattformübergreifende Kommando `echo`. |
| `openai-image-sample.json` | Einfaches Vision-Beispiel mit einer Bildnachricht. |
| `openai-json-schema-sample.json` | Antwortet mit JSON entsprechend einem Schema. |
| `openai-image-function-call-sample.json` | Kombiniert ein Bild mit einem Funktionsaufruf. |
| `openai-image-json-schema-sample.json` | Kombiniert ein Bild mit einer JSON-Antwort. |
| `openai-image-function-call-json-schema-sample.json` | Vereint Bild, Funktionsaufruf und JSON-Schema-Ausgabe. |
| `openai-user-names-sample.json` | Mehrere Nutzer listen etwas auf; der Assistent nennt, wer was gesagt hat. |

Die beinhalteten Nachrichten sind absichtlich kurz gehalten und sollen lediglich als Ausgangspunkt für eigene Experimente dienen.
