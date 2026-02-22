# .ftproj Format (Deutsch)

Die Datei `.ftproj` speichert ein Fineâ€‘Tuneâ€‘Projekt in serialisierter Form. Die gleichen Daten kÃ¶nnen auch als JSON mit der Endung `.json` abgelegt werden. Die Wurzelstruktur enthÃ¤lt drei SchlÃ¼ssel:

```json
{
  "functions": [],
  "conversations": {},
  "settings": {},
  "graders": [],
  "schemas": []
}
```

Nachfolgend werden alle Bereiche sowie die Bedeutung der einzelnen Felder erlÃ¤utert.

## WurzelschlÃ¼ssel
- **`functions`**: Liste von Funktionsdefinitionen, die beim Export oder Testen genutzt werden.
- **`conversations`**: Dictionary, das eine Konversationsâ€‘ID auf eine Liste von Nachrichten abbildet.
- **`settings`**: Globale Einstellungen des Projekts.
- **`graders`**: Array von Grader-Konfigurationen zur Bewertung von GesprÃ¤chen.
- **`schemas`**: Liste der verfÃ¼gbaren JSON-Schemata.

## Funktionsobjekte

Jeder Eintrag in `functions` beschreibt eine aufrufbare Funktion.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `name` | string | Ã–ffentlicher Name der Funktion. |
| `description` | string | Lesbare Beschreibung fÃ¼r BenutzeroberflÃ¤chen. |
| `parameters` | array | Liste der Parameterdefinitionen. |
| `functionExecutionEnabled` | bool | Ob die Funktion vom Programm ausgefÃ¼hrt werden darf. |
| `functionExecutionExecutable` | string | Pfad oder Kommando, das bei AusfÃ¼hrung gestartet wird. |
| `functionExecutionArgumentsString` | string | Argumente, die dem Kommando Ã¼bergeben werden. |

### Parameterobjekte

Jedes Objekt im Array `parameters` definiert ein Argument.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `type` | string | Erlaubter Wertetyp wie `String` oder `Number`. |
| `name` | string | Name des Parameters. |
| `description` | string | ErlÃ¤uterung des Parameters. |
| `minimum` | number | Kleinster zulÃ¤ssiger numerischer Wert. |
| `maximum` | number | GrÃ¶ÃŸter zulÃ¤ssiger numerischer Wert. |
| `isEnum` | bool | Gibt an, ob der Wert aus `enumOptions` gewÃ¤hlt werden muss. |
| `hasLimits` | bool | Ob `minimum` und `maximum` gelten. |
| `enumOptions` | string | Kommagetrennte erlaubte AuswahlmÃ¶glichkeiten. |
| `isRequired` | bool | Muss dieser Parameter angegeben werden. |

## GesprÃ¤che

Im Dictionary `conversations` werden alle aufgezeichneten Dialoge gespeichert. Der SchlÃ¼ssel ist die Konversationsâ€‘ID, der Wert eine Liste von Nachrichten.

### Nachrichtenobjekte

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `role` | string | Absender: `system`, `user`, `assistant` oder `meta`. |
| `type` | string | Inhaltstyp wie `Text` oder `Image`. |
| `textContent` | string | Text, der dem Modell gezeigt wird. |
| `unpreferredTextContent` | string | Alternative, die nicht verwendet wurde. |
| `preferredTextContent` | string | Bevorzugte Alternative. |
| `imageContent` | string | Base64â€‘kodierte Bilddaten. |
| `imageDetail` | integer | Detailstufe fÃ¼r die Bildverarbeitung. |
| `functionName` | string | Name des aufzurufenden Funktionsaufrufs. |
| `functionParameters` | array | Liste von Funktionsparametern. |
| `functionResults` | string | Ergebnis einer ausgefÃ¼hrten Funktion. |
| `functionUsePreText` | string | Text, der bei der AusfÃ¼hrung vorangestellt wird. |
| `userName` | string | Optionaler Benutzername. |
| `jsonSchemaName` | string | Name des ausgewÃ¤hlten JSONâ€‘Schemas fÃ¼r strukturierte JSONâ€‘Nachrichten. Leer lassen, um reines JSON ohne schemagebundene Formulare zu speichern. |
| `jsonSchemaValue` | string | Der JSON-Inhalt der Nachricht (als serialisierter Text), nicht die Schema-Definition selbst. |
| `metaData` | object | Informationen zur Konversation selbst. |
| `audioData` | string | Base64â€‘kodierte Audiodaten. |
| `audioTranscript` | string | Transkription des Audios. |
| `audioFiletype` | string | Dateiendung der Audiodaten. |
| `fileMessageData` | string | Base64â€‘kodierte Datei im Anhang. |
| `fileMessageName` | string | Name der angehÃ¤ngten Datei. |

#### Funktionsparameterobjekte

Innerhalb einer Nachricht hat jedes Element von `functionParameters` folgende Struktur.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `name` | string | Name des Parameters. |
| `isUsed` | bool | Ob der Wert verwendet werden soll. |
| `parameterValueText` | string | Textwert, der gewÃ¤hlt wurde. |
| `parameterValueChoice` | string | AusgewÃ¤hlte Option einer Enumeration. |
| `parameterValueNumber` | number | GewÃ¤hlter numerischer Wert. |

#### `metaData`-Objekt

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `ready` | bool | Zeigt an, dass das GesprÃ¤ch fertig und exportbereit ist. |
| `conversationName` | string | Optionale Bezeichnung der Konversation. |
| `notes` | string | Beliebige Notizen zum GesprÃ¤ch. |

## Einstellungen

Globale Konfiguration, gespeichert im Objekt `settings`.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `useGlobalSystemMessage` | bool | FÃ¼gt allen GesprÃ¤chen eine gemeinsame Systemnachricht voran. |
| `globalSystemMessage` | string | Text dieser globalen Systemnachricht. |
| `apikey` | string | Gespeicherter API-SchlÃ¼ssel fÃ¼r OpenAI. |
| `modelChoice` | string | GewÃ¤hltes Modell fÃ¼r TokenzÃ¤hlung oder Antworten. |
| `availableModels` | array | Liste der verfÃ¼gbaren Modelle. |
| `includeFunctions` | integer | Legt fest, wann Funktionen exportiert werden. |
| `finetuneType` | integer | GewÃ¤hlte Fineâ€‘Tuneâ€‘Methode. |
| `exportImagesHow` | integer | Art und Weise des Bildexports. |
| `useUserNames` | bool | Benutzernamen in exportierten Daten einbeziehen. |
| `schemaEditorURL` | string | URL zu einem externen JSON-Schema-Editor. |
| `projectStorageMode` | integer | Speicher-Backend des Projekts (`0` = lokal, `1` = Cloud). |
| `projectCloudURL` | string | URL zum Cloud-Endpunkt `project-storage.php`. |
| `projectCloudKey` | string | Geheimer Schluessel fuer Cloud-Speicher-/Ladeanfragen. |
| `projectCloudName` | string | Cloud-Projektkennung (entspricht einer entfernten JSON-Datei). |
| `autoSaveMode` | integer | Verhalten fuer automatisches Speichern (`0` aus, `1` alle 5 Minuten, `2` bei Konversationswechsel). |
| `tokenCounterPath` | string | Pfad zu einem externen Tool zur TokenzÃ¤hlung. |
| `exportConvos` | integer | Welche GesprÃ¤che exportiert werden. |
| `countTokensWhen` | integer | Wann die TokenzÃ¤hlung erfolgt. |
| `tokenCounts` | string | Zwischengespeicherte Tokenzahlen pro GesprÃ¤ch. |
| `countTokensModel` | integer | Modell zur SchÃ¤tzung der Tokenanzahl. |

## Schemas

Jedes Element im Array `schemas` beschreibt ein JSON-Schema.

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `name` | string | Anzeigename des Schemas. |
| `schema` | object | UrsprÃ¼ngliches, vom Benutzer eingegebenes Schema. |
| `resolvedSchema` | object | Zur Laufzeit aufgelöste Version, bei der externe URL-`$ref` bereits durch ihren Inhalt ersetzt wurden (falls ladbar). |
| `sanitizedSchema` | object | Bereinigte Version des Schemas fÃ¼r die Verwendung. |
| `externalSchemaErrors` | array | Optionale Fehlerliste beim Laden externer Schema-Referenzen. |
### BinÃ¤r vs. JSON

Bei Speicherung als `.ftproj` wird das komplette Objekt mit Godots `store_var` serialisiert. Mit `.json` wird dieselbe Struktur als JSONâ€‘Text geschrieben.
