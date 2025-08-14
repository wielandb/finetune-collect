# .ftproj Format

The `.ftproj` file is a serialized representation of a fine‑tune project. The same data can also be saved as textual JSON with the `.json` extension. Each project root contains three keys:

```json
{
  "functions": [],
  "conversations": {},
  "settings": {},
  "graders": [],
  "schemas": []
}
```

Each section is described below along with the meaning of every field.

## Root keys
- **`functions`**: Array of function definitions used when exporting or testing conversations.
- **`conversations`**: Dictionary mapping a conversation ID to an array of message objects.
- **`settings`**: Global configuration options for the project.
- **`graders`**: Array of grader configurations used to evaluate conversations.
- **`schemas`**: Array of JSON schema entries available in the project.

## Function entries

Each item of the `functions` array describes one callable function.

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | The function's public name used in API calls. |
| `description` | string | Human readable description shown in UIs. |
| `parameters` | array | List of parameter definitions. |
| `functionExecutionEnabled` | bool | Whether the function can be executed by the program. |
| `functionExecutionExecutable` | string | Path or command to run the function if execution is enabled. |
| `functionExecutionArgumentsString` | string | Arguments passed when running the executable. |

### Parameter objects

Each object inside the `parameters` array defines one argument.

| Field | Type | Description |
| --- | --- | --- |
| `type` | string | Allowed value type, e.g. `String` or `Number`. |
| `name` | string | Parameter name. |
| `description` | string | Explanation of the parameter. |
| `minimum` | number | Lowest allowed numeric value. |
| `maximum` | number | Highest allowed numeric value. |
| `isEnum` | bool | Indicates if the value must be chosen from `enumOptions`. |
| `hasLimits` | bool | Whether `minimum` and `maximum` are enforced. |
| `enumOptions` | string | Comma separated allowed choices when `isEnum` is `true`. |
| `isRequired` | bool | If `true`, the parameter must be provided. |

## Conversations

The `conversations` dictionary stores all recorded dialogues. The key is the conversation ID and the value is a list of messages.

### Message objects

| Field | Type | Description |
| --- | --- | --- |
| `role` | string | Sender of the message: `system`, `user`, `assistant`, or `meta`. |
| `type` | string | Message content type such as `Text` or `Image`. |
| `textContent` | string | Text body shown to the model. |
| `unpreferredTextContent` | string | Alternative text that was not used. |
| `preferredTextContent` | string | Preferred alternative text. |
| `imageContent` | string | Base64 encoded image data. |
| `imageDetail` | integer | Level of detail for image processing. |
| `functionName` | string | Name of the function call to make. |
| `functionParameters` | array | List of function argument objects. |
| `functionResults` | string | Results returned by an executed function. |
| `functionUsePreText` | string | Text prepended when executing a function. |
| `userName` | string | Optional user display name. |
| `jsonSchemaValue` | string | Additional schema information. |
| `metaData` | object | Information about the conversation itself. |
| `audioData` | string | Base64 encoded audio data. |
| `audioTranscript` | string | Transcript of the audio. |
| `audioFiletype` | string | File extension of the audio data. |
| `fileMessageData` | string | Base64 encoded file attached to the message. |
| `fileMessageName` | string | Name of the attached file. |

#### Function parameter objects

Within a message, each entry of `functionParameters` uses the structure below.

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | Name of the parameter. |
| `isUsed` | bool | Whether the value should be included. |
| `parameterValueText` | string | Text value selected by the user. |
| `parameterValueChoice` | string | Enumeration choice selected by the user. |
| `parameterValueNumber` | number | Numeric value selected by the user. |

#### `metaData` object

| Field | Type | Description |
| --- | --- | --- |
| `ready` | bool | Indicates that the conversation is finished and ready for export. |
| `conversationName` | string | Optional label for the conversation. |
| `notes` | string | Arbitrary notes about the conversation. |

## Settings

Global configuration stored in the `settings` object.

| Field | Type | Description |
| --- | --- | --- |
| `useGlobalSystemMessage` | bool | Prepend a single system message to all conversations. |
| `globalSystemMessage` | string | Text of the global system message. |
| `apikey` | string | Stored API key for OpenAI requests. |
| `modelChoice` | string | Selected model for token counting or completions. |
| `availableModels` | array | List of models available to the user. |
| `includeFunctions` | integer | Determines when functions are included during export. |
| `finetuneType` | integer | Selected fine‑tuning method. |
| `exportImagesHow` | integer | How image messages are exported. |
| `useUserNames` | bool | Include user names in exported data. |
| `schemaEditorURL` | string | URL to an external JSON schema editor. |
| `jsonSchema` | string | Default JSON schema used for validation. |
| `tokenCounterPath` | string | Path to an external token counting tool. |
| `exportConvos` | integer | Determines which conversations are exported. |
| `countTokensWhen` | integer | Specifies when token counting is performed. |
| `tokenCounts` | string | Cached token counts per conversation. |
| `countTokensModel` | integer | Model used to estimate token counts. |

## Schemas

Each item in the `schemas` array represents one JSON schema definition.

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | Display name for the schema. |
| `schema` | object | Original schema as entered by the user. |
| `sanitizedSchema` | object | Sanitized version of the schema for safe usage. |

### Binary vs JSON

When saved with the `.ftproj` extension, the entire object is serialized with Godot's `store_var`. Using `.json` saves the same structure as plain JSON text.
