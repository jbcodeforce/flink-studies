import argparse
import os
import subprocess
import sys
from openai import OpenAI

MODEL_NAME = "gpt-oss:20b"
# Configure OpenAI client to use Ollama
client = OpenAI(
    base_url="http://localhost:11434/v1",  # Ollama API endpoint
    api_key="ollama",  # Required but not used by Ollama
)

def read_prompt_from_file(file_path: str) -> str:
    """Read prompt from a file."""
    with open(file_path, 'r') as f:
        return f.read().strip()

def generate_code(prompt: str) -> str:
    """Generate code using Ollama via OpenAI SDK."""
    print(f"Generating code using {MODEL_NAME}")
    try:
        response = client.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": "You are a helpful Python coding assistant. Generate only Python code without any explanations."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.2,  # Lower temperature for more focused code generation
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"Error generating code: {e}")
        return None

def clean_code(code: str) -> str:
    """Clean generated code."""
    lines = []
    inside_code = False
    for line in code.splitlines():
        if line.strip().startswith("```"):
            inside_code = not inside_code
            continue
        if inside_code or (line.strip().startswith("import") or line.strip().startswith("def")):
            lines.append(line)
    return "\n".join(lines)

def test_python_code(file_path: str) -> bool:
    """Test the generated Python code by running it.
    
    Args:
        file_path: Path to the Python file to test
        
    Returns:
        bool: True if test passes, False otherwise
    """
    try:
        print(f"Testing generated code in {file_path}")
        # Run the Python file in a new process
        result = subprocess.run(
            [sys.executable, file_path],
            capture_output=True,
            text=True,
            timeout=10  # 10 second timeout
        )
        
        # Print output
        if result.stdout:
            print("Output:")
            print(result.stdout)
            
        # Check for errors
        if result.returncode != 0:
            print("Error running code:")
            print(result.stderr)
            return False
            
        return True
    except subprocess.TimeoutExpired:
        print(f"Error: Code execution timed out after 10 seconds")
        return False
    except Exception as e:
        print(f"Error testing code: {e}")
        return False

def save_code_to_file(code: str, file_path: str) -> bool:
    """Save generated code to a file."""
    try:
        with open(file_path, 'w') as f:
            f.write(code)
        return True
    except Exception as e:
        print(f"Error saving code to file: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        prog=os.path.basename(__file__),
        description="Generate code using Ollama via OpenAI SDK"
    )
    
    # Add arguments for prompt input (either file or string) and output file
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument('-f', '--file', help='Path to prompt file')
    input_group.add_argument('-p', '--prompt', help='Prompt string')
    
    parser.add_argument('-o', '--output', required=True, help='Output file path')
    parser.add_argument('-t', '--test', action='store_true', help='Test the generated code after saving')
    
    args = parser.parse_args()
    
    # Get prompt either from file or command line
    prompt = read_prompt_from_file(args.file) if args.file else args.prompt
    
    if not prompt:
        print("Error: Empty prompt")
        return
    
    # Generate code
    generated_code = generate_code(prompt)
    if not generated_code:
        return
    print(f"Generated code: {generated_code}")
    cleaned_code = clean_code(generated_code)
    if not cleaned_code:
        return
        
    # Save code to file
    if not save_code_to_file(cleaned_code, args.output):
        print("Failed to save generated code")
        return
        
    print(f"Code successfully generated and saved to {args.output}")
    
    # Test the code if requested
    if args.test:
        if test_python_code(args.output):
            print("Code test passed successfully")
        else:
            print("Code test failed")

if __name__ == "__main__":
    main()
