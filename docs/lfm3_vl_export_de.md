# LFM3-VL-Export

`scripts/export_lfm3_vl.py` konvertiert gespeicherte **JSON-Projekte von
finetune-collect** in einen portablen Datensatz für Vision Supervised Fine-Tuning
(SFT) mit TRL, insbesondere für `LiquidAI/LFM3-VL-2B`.

## Verifiziertes Zielformat

Stand: 25. November 2026. Grundlage sind die [LFM3-VL-Modellkarte](https://huggingface.co/LiquidAI/LFM3-VL-2B),
Liquids [Dokumentation für Vision-Datensätze](https://docs.liquid.ai/lfm/fine-tuning/datasets)
und die [TRL-Datensatzformate](https://huggingface.co/docs/trl/dataset_formats#vision-datasets).
LFM3-VL benötigt kein eigenes universelles Austauschformat: Für diesen Export
verwenden wir den dokumentierten **konversationellen VLM-SFT-Datensatz**.

Jede Zeile der exportierten `dataset.jsonl` enthält ein Trainingsbeispiel:

```json
{
  "messages": [
    {"role": "system", "content": [{"type": "text", "text": "Antworte als JSON."}]},
    {"role": "user", "content": [
      {"type": "text", "text": "Welche Verkehrszeichen sind zu sehen?"},
      {"type": "image"}
    ]},
    {"role": "assistant", "content": [{"type": "text", "text": "{\"zeichen\": []}"}]}
  ],
  "images": ["images/<sha256>.png"]
}
```

Die Bildplatzhalter und die Einträge in `images` haben dieselbe Reihenfolge.
Auf der Festplatte stehen relative Bildpfade. **Vor dem Training** wandelt der
mitgelieferte Loader diese in dekodierte `PIL.Image`-Objekte um, wie TRL es erwartet.
Die JSONL-Datei allein ohne diese Dekodierung ist noch kein direkt verwendbarer
TRL-Vision-Datensatz. Den gesamten Ausgabeordner zusammen auf den Trainingsserver
kopieren.

Der Export setzt keine LFM-Bildtokens, ChatML-Trennzeichen oder Denktexte ein.
Die modellspezifische Formatierung übernimmt später der originale Processor mit
seinem Chat-Template. Ein OpenAI-`response_format` ist kein Trainingsziel;
trainiert wird der tatsächliche JSON-Antworttext.

## Installation und Aufruf

Python **3.10 oder neuer**:

```bash
python -m pip install -r scripts/requirements_lfm3_vl.txt
python scripts/export_lfm3_vl.py mein-projekt.json lfm3-export
```

Für den reinen Export reicht `Pillow`; `datasets` wird nur vom Loader für das
Training und vom entsprechenden Integrationstest benötigt. Zum Beispiel:

```bash
python -m pip install "Pillow>=10.4,<14"
python scripts/export_lfm3_vl.py examples/lfm3-vl-traffic-signs.json lfm3-demo --offline
```

Das Quellprojekt in finetune-collect **als `.json` speichern**. Native `.ftproj`
sind mit Godots `store_var` serialisiert und werden nicht vom Python-Konverter
gelesen. Ein bereits vorhandener Ausgabeordner wird nicht überschrieben.
Bei einem Fehler wird auch kein teilweise exportierter Datensatz hinterlassen.

| Option | Verhalten |
| --- | --- |
| Ohne zusätzliche Optionen | Nur Gespräche mit `type: "meta"` und `metaData.ready: true`. |
| `--include-unready` | Auch noch nicht fertige Gespräche einbeziehen; die Inhaltsprüfung bleibt aktiv. |
| `--conversation-id ID` | Nur diese ID auswählen; mehrfach verwendbar. Der Fertig-Filter gilt weiterhin. |
| `--offline` | Keine Bild-URLs herunterladen; bei ausgewählten URL-Bildern abbrechen. |
| `--timeout 30` | Zeitlimit pro Bild-Download in Sekunden. |
| `--max-image-mib 32` | Maximale Größe einer Quelldatei bzw. dekodierter Base64-Binärdaten. |

Die Auswahl ist unabhängig von `settings.exportConvos` und den OpenAI-
Exporteinstellungen. `conversationOrder` bestimmt die Reihenfolge; fehlende IDs
werden in der Reihenfolge des `conversations`-Objekts angehängt. Veraltete und
doppelte Einträge in `conversationOrder` werden ignoriert.

Neben `dataset.jsonl` entstehen `images/*.png` und `export-info.json` mit den
exportierten Gesprächs-IDs, übersprungenen unfertigen IDs und der Zahl eindeutiger
Bilder. Einstellungen, API-Schlüssel, Notizen und Schema-Definitionen werden
nicht in den Datensatz übernommen. Das Quellprojekt bleibt unverändert.

## Abbildung des Projektformats

| finetune-collect | Export |
| --- | --- |
| `Image.imageContent`: reines Base64 oder `data:image/...;base64,...` | Bild dekodieren und als lokale RGB-PNG-Datei speichern. |
| `Image.imageContent`: HTTP(S)-URL | Bild herunterladen, dekodieren und ebenfalls lokal speichern. |
| Aufeinanderfolgende Nachrichten derselben Rolle | Inhalt zu einem Turn verbinden; aufeinanderfolgende Textteile mit einer Leerzeile trennen. |
| `Text.textContent` | Textteil im ursprünglichen Wortlaut. |
| `JSON.jsonSchemaValue` oder historisches `JSON Schema.jsonSchemaValue` | JSON-Syntax prüfen und den ursprünglichen serialisierten Text als Textteil erhalten. |
| `JSON.jsonSchemaName`, Projekt-`schemas` | Annotationseingabe in der App; werden nicht als Antwortinhalt exportiert. |
| `settings.useGlobalSystemMessage` und `globalSystemMessage` | Gemeinsame Systemnachricht voranstellen; zusätzliche anfängliche lokale Systemtexte bleiben erhalten. |
| `meta` | Für die Auswahl auswerten, anschließend entfernen. |
| `settings.imageAutoRotateSetting` | `0`: Pixelorientierung beibehalten; `1` und `2`: vorhandene EXIF-Orientierung anwenden. |

Mehrere Bilder und mehrere User-/Assistant-Turns sind möglich. Ein Gespräch
muss mit Nutzereingaben beginnen, mit einer Assistentenantwort enden und
mindestens ein Bild enthalten. Bilder müssen Nutzereingaben sein. Systemtexte
sind nur am Anfang erlaubt. Die Bildanzahl muss zu den Bildplatzhaltern passen.

Transparenz wird auf Weiß reduziert; Bilder werden ohne EXIF-Metadaten als RGB
gespeichert. Gleiche resultierende PNG-Dateien werden nur einmal abgelegt.
Nicht unterstützte Nachrichten wie Funktionsaufrufe, Audio, PDFs oder unbekannte
Rollen, defekte Bilder, mehrteilige/animierte Bilddateien, leere Textnachrichten
und ungültige JSON-Antworten führen zu einem Fehler mit Gesprächs-ID und, soweit
möglich, Nachrichtennummer. Es werden keine Nachrichten stillschweigend entfernt.
Eine automatische Prüfung der Antworten gegen das jeweilige JSON-Schema ist
nicht Teil des Exports; die Annotation muss vor dem Fertig-Markieren geprüft sein.
Preference-/RFT-Daten werden nicht in SFT-Ziele umgedeutet.

## Für TRL laden

Vom Repository-Hauptverzeichnis aus:

```python
from scripts.export_lfm3_vl import load_training_dataset

dataset = load_training_dataset("lfm3-export/dataset.jsonl")
sample = dataset[0]
assert sample["images"][0].mode == "RGB"
```

`dataset` kann als `train_dataset` an `trl.SFTTrainer` übergeben werden. Dafür
zusätzlich die GPU-Trainingsumgebung nach der aktuellen LFM3-VL-/TRL-Anleitung
einrichten; diese Export-Abhängigkeiten installieren weder Torch noch das Modell.
Den zu `LiquidAI/LFM3-VL-2B` gehörenden `AutoProcessor` als `processing_class`
verwenden. Bilder und Bildplatzhalter werden vom Vision-Collator verbunden.
TRL empfiehlt für VLMs `SFTConfig(max_length=None)`, damit eine Kürzung keine
Bildtokens abschneidet, siehe [SFTTrainer](https://huggingface.co/docs/trl/sft_trainer#training-vision-language-models).

Das ist eine Datenschnittstelle, kein getestetes GPU-Trainingsrezept. Insbesondere
`assistant_only_loss=True` setzt Unterstützung für Generationsmasken im
Chat-Template voraus und sollte nicht ungeprüft eingeschaltet werden. Die
[Liquid-TRL-Anleitung](https://docs.liquid.ai/lfm/fine-tuning/trl) weist zudem
darauf hin, dass ihr Text-LoRA-Beispiel kein Ersatz für ein modellspezifisches
multimodales Trainingsrezept ist.

## Verkehrszeichen-Beispielprojekt

[`examples/lfm3-vl-traffic-signs.json`](../examples/lfm3-vl-traffic-signs.json)
direkt in finetune-collect laden. Es enthält:

- Ein JSON-Eingabeschema mit einer Liste erkannter Zeichen, Referenz,
  Bezeichnung, Beschriftung, Form, Hintergrund-/Randfarbe, Zusatzzeichen und
  einem Unsicherheitsfeld.
- Zwei eingebettete, synthetische Zeichenbilder, damit das Projekt offline
  geöffnet und der Export ausprobiert werden kann.
- Eine fertige STOP-Annotation und einen unfertigen Tempo-30-Entwurf, um den
  Fertig-Filter zu demonstrieren.
- Eine globale Systemnachricht mit dem erwarteten JSON-Inhalt.

Die Grafiken sind **Formular- und Exportbeispiele**, keine realistischen
Trainingsfotos. Für ein Modellprojekt durch eigene Bilder ersetzen, Annotationen
prüfen und danach als fertig markieren. Eine Auswahl von IDs kann beispielsweise
für ein separat aufbewahrtes Evaluationsset verwendet werden.

## Tests

```bash
python -m unittest discover -s tests -p test_export_lfm3_vl.py -v
godot --headless --path src --import
godot --headless --path src -s res://tests/test_lfm3_vl_example.gd
```

Die Python-Tests prüfen unter anderem tatsächliche HTTP-Bilddownloads inklusive
Weiterleitungen, mehrere Bilder/Turns, Base64, JSON-Zieltexte, Systemnachrichten,
Filter, EXIF/RGB, Fehlerbereinigung und das Laden mit Hugging Face Datasets nach
Verschieben eines Exportordners. Ohne `datasets` wird nur dieser Loader-Test
übersprungen. Der Godot-Test lädt das Beispielprojekt in der Anwendung und prüft
Schema-Formular, Bilddarstellung, JSON-Roundtrip und Fertig-Status.
