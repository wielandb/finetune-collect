# finetune-collect
A program that helps collecting and curating OpenAI fine-tune data.

This is a program for people that want to collect and curate their fine tuning data by hand. It provides functionality to store and modify example conversations and functions that will then be exported to the `.jsonl`-Format that the OpenAI API requires for fine-tuning.

You can also provide the program with your OpenAI API key and it can generate responses for you that you then can then adapt instead of completely writing them by hand.

![conversation_example](presentation/image_example.png)





![function_example](presentation/function_example_vertical.png)

## How to export your training data to OpenAIs fine-tuning schema

For now, this functionality is not available in the program itself but only by a python-script located in `scripts/`. Call it by giving the project jsonl-File as an argument like `python3 scripts/ftc.py my-finetune-project.json`, which will create the file `output_finetune.jsonl`
