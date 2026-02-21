# ![banner-logo](presentation/banner-logo.png)
A program that helps collecting and curating OpenAI fine-tune data.

This is a program for people that want to collect and curate their fine tuning data by hand. It provides functionality to store and modify example conversations and functions that will then be exported to the `.jsonl`-Format that the OpenAI API requires for fine-tuning.

You can also provide the program with your OpenAI API key and it can generate responses for you that you then can then adapt instead of completely writing them by hand.

## [Try it online on GitHub Pages](https://wielandb.github.io/finetune-collect/export/web)

![conversation_example](presentation/image_example.png)

![function_example](presentation/function_example_vertical.png)

## Features
- Supports text, image, JSON schema, function call, audio and PDF messages
- Import OpenAI message JSON from the clipboard or drag & drop `.json`/`.ftproj` files
- Execute local functions with optional pre‑text and store the results
- Automatically upload images to a configurable server
- Save/load projects either locally or via a configurable cloud PHP endpoint
- Auto-save projects every 5 minutes or on conversation switches
- Cloud mode enforces URL-only images (base64 images must be uploaded first)
- Export images as base64 or URLs and choose which conversations to export
- Token usage and cost estimation via a script
- Conversation auto-splitting for Reinforcement Fine-Tuning
- Optional global system message and user names per message
- Show or hide meta information and token calculations per conversation

## Keyboard Shortcuts
- `Ctrl` + `S` – Save the project without re-opening the dialog
- `Del` – Delete a conversation (when selected in the list)
- `Ctrl` + `Left Click` – Enlarge image when hovering
- `Ctrl` + `Right Click` – Shrink image when hovering
- `Ctrl` + `Space` – Add new message
- Drag and drop a `.ftproj` or `.json` file onto the window to load a project or insert messages
- The application remembers the last opened project file and loads it automatically on the next start if it still exists
