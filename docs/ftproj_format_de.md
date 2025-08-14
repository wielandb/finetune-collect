# .ftproj Format (Deutsch)

Die Datei `.ftproj` speichert ein Fine‑Tune‑Projekt in serialisierter Form. Die gleichen Daten können auch als JSON mit der Endung `.json` abgelegt werden. Die Wurzelstruktur enthält drei Schlüssel:

```json
{
  "functions": [],
  "conversations": {},
  "settings": {},
  "graders": [],
  "schemas": []
}
```

Nachfolgend werden alle Bereiche sowie die Bedeutung der einzelnen Felder erläutert.

## Wurzelschlüssel
- **`functions`**: Liste von Funktionsdefinitionen, die beim Export oder Testen genutzt werden.
- **`conversations`**: Dictionary, das eine Konversations‑ID auf eine Liste von Nachrichten abbildet.
- **`settings`**: Globale Einstellungen des Projekts.
- **`graders`**: Array von Grader-Konfigurationen zur Bewertung von Gesprächen.
- **`schemas`**: Liste der verfügbaren JSON-Schemata.

## Funktionsobjekte

Jeder Eintrag in `functions` beschreibt eine aufrufbare Funktion.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `name` | string | Öffentlicher Name der Funktion. |
| `description` | string | Lesbare Beschreibung für Benutzeroberflächen. |
| `parameters` | array | Liste der Parameterdefinitionen. |
| `functionExecutionEnabled` | bool | Ob die Funktion vom Programm ausgeführt werden darf. |
| `functionExecutionExecutable` | string | Pfad oder Kommando, das bei Ausführung gestartet wird. |
| `functionExecutionArgumentsString` | string | Argumente, die dem Kommando übergeben werden. |

### Parameterobjekte

Jedes Objekt im Array `parameters` definiert ein Argument.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `type` | string | Erlaubter Wertetyp wie `String` oder `Number`. |
| `name` | string | Name des Parameters. |
| `description` | string | Erläuterung des Parameters. |
| `minimum` | number | Kleinster zulässiger numerischer Wert. |
| `maximum` | number | Größter zulässiger numerischer Wert. |
| `isEnum` | bool | Gibt an, ob der Wert aus `enumOptions` gewählt werden muss. |
| `hasLimits` | bool | Ob `minimum` und `maximum` gelten. |
| `enumOptions` | string | Kommagetrennte erlaubte Auswahlmöglichkeiten. |
| `isRequired` | bool | Muss dieser Parameter angegeben werden. |

## Gespräche

Im Dictionary `conversations` werden alle aufgezeichneten Dialoge gespeichert. Der Schlüssel ist die Konversations‑ID, der Wert eine Liste von Nachrichten.

### Nachrichtenobjekte

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `role` | string | Absender: `system`, `user`, `assistant` oder `meta`. |
| `type` | string | Inhaltstyp wie `Text` oder `Image`. |
| `textContent` | string | Text, der dem Modell gezeigt wird. |
| `unpreferredTextContent` | string | Alternative, die nicht verwendet wurde. |
| `preferredTextContent` | string | Bevorzugte Alternative. |
| `imageContent` | string | Base64‑kodierte Bilddaten. |
| `imageDetail` | integer | Detailstufe für die Bildverarbeitung. |
| `functionName` | string | Name des aufzurufenden Funktionsaufrufs. |
| `functionParameters` | array | Liste von Funktionsparametern. |
| `functionResults` | string | Ergebnis einer ausgeführten Funktion. |
| `functionUsePreText` | string | Text, der bei der Ausführung vorangestellt wird. |
| `userName` | string | Optionaler Benutzername. |
| `jsonSchemaName` | string | Name des ausgewählten JSON‑Schemas. |
| `jsonSchemaValue` | string | Zusätzliche Schema‑Informationen. |
| `metaData` | object | Informationen zur Konversation selbst. |
| `audioData` | string | Base64‑kodierte Audiodaten. |
| `audioTranscript` | string | Transkription des Audios. |
| `audioFiletype` | string | Dateiendung der Audiodaten. |
| `fileMessageData` | string | Base64‑kodierte Datei im Anhang. |
| `fileMessageName` | string | Name der angehängten Datei. |

#### Funktionsparameterobjekte

Innerhalb einer Nachricht hat jedes Element von `functionParameters` folgende Struktur.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `name` | string | Name des Parameters. |
| `isUsed` | bool | Ob der Wert verwendet werden soll. |
| `parameterValueText` | string | Textwert, der gewählt wurde. |
| `parameterValueChoice` | string | Ausgewählte Option einer Enumeration. |
| `parameterValueNumber` | number | Gewählter numerischer Wert. |

#### `metaData`-Objekt

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `ready` | bool | Zeigt an, dass das Gespräch fertig und exportbereit ist. |
| `conversationName` | string | Optionale Bezeichnung der Konversation. |
| `notes` | string | Beliebige Notizen zum Gespräch. |

## Einstellungen

Globale Konfiguration, gespeichert im Objekt `settings`.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `useGlobalSystemMessage` | bool | Fügt allen Gesprächen eine gemeinsame Systemnachricht voran. |
| `globalSystemMessage` | string | Text dieser globalen Systemnachricht. |
| `apikey` | string | Gespeicherter API-Schlüssel für OpenAI. |
| `modelChoice` | string | Gewähltes Modell für Tokenzählung oder Antworten. |
| `availableModels` | array | Liste der verfügbaren Modelle. |
| `includeFunctions` | integer | Legt fest, wann Funktionen exportiert werden. |
| `finetuneType` | integer | Gewählte Fine‑Tune‑Methode. |
| `exportImagesHow` | integer | Art und Weise des Bildexports. |
| `useUserNames` | bool | Benutzernamen in exportierten Daten einbeziehen. |
| `schemaEditorURL` | string | URL zu einem externen JSON-Schema-Editor. |
| `tokenCounterPath` | string | Pfad zu einem externen Tool zur Tokenzählung. |
| `exportConvos` | integer | Welche Gespräche exportiert werden. |
| `countTokensWhen` | integer | Wann die Tokenzählung erfolgt. |
| `tokenCounts` | string | Zwischengespeicherte Tokenzahlen pro Gespräch. |
| `countTokensModel` | integer | Modell zur Schätzung der Tokenanzahl. |

## Schemas

Jedes Element im Array `schemas` beschreibt ein JSON-Schema.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `name` | string | Anzeigename des Schemas. |
| `schema` | object | Ursprüngliches, vom Benutzer eingegebenes Schema. |
| `sanitizedSchema` | object | Bereinigte Version des Schemas für die Verwendung. |

### Binär vs. JSON

Bei Speicherung als `.ftproj` wird das komplette Objekt mit Godots `store_var` serialisiert. Mit `.json` wird dieselbe Struktur als JSON‑Text geschrieben.
