# Code Helper

A CLI tool that uses Ollama's GPT-OSS model to generate and test Python code.

## Prerequisites

* Python 3.8+
* Ollama running locally (`docker run -d -v ollama:/root/.ollama -p 11434:11434 ollama/ollama`)
* Required Python packages: `pip install -r requirements.txt`

## Usage

Generate code from prompt:
```bash
python main.py -p "Write a function that calculates factorial" -o factorial.py
```

Generate code from prompt file:
```bash
python main.py -f prompt.txt -o output.py
```

Generate and test code:
```bash
python main.py -p "Write a function that prints Hello World" -o hello.py -t
```

## Arguments

* `-p, --prompt`: Prompt string for code generation
* `-f, --file`: File containing the prompt
* `-o, --output`: Output file path for generated code
* `-t, --test`: Test the generated code after saving

## Features

* Uses GPT-OSS 20B model via Ollama
* Cleans markdown code blocks from responses
* Tests generated code in isolated subprocess
* 10-second timeout for code execution
* Captures and displays code output and errors
