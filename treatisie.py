import os
import sys
import subprocess

def process_file(input_filepath, output_filepath):
    words = []
    values = []
    
    # Read the input file
    with open(input_filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith("Word:"):
                # Extract word between "Word:" and "||"
                if "||" in line:
                    word = line[len("Word:"):].split("||", 1)[0].strip()
                    words.append(word)
                else:
                    print(f"Skipped line without '||': {line}")
            elif line.startswith("Found value"):
                # Extract value after "Value:"
                if "Value:" in line:
                    value_part = line.split("Value:", 1)[1].strip()
                    # Extract the numeric value
                    num_str = ''
                    for char in value_part:
                        if char.isdigit():
                            num_str += char
                        else:
                            break
                    if num_str:
                        values.append(int(num_str))
                    else:
                        print(f"Skipped line without numeric value: {line}")
                else:
                    print(f"Skipped line without 'Value:': {line}")
    
    # Check if the number of words and values match
    if len(words) != len(values):
        print(f"Warning: Number of words ({len(words)}) does not match number of values ({len(values)})")
    
    # Write paired words and values to the output file
    with open(output_filepath, 'w', encoding='utf-8') as f:
        for word, value in zip(words, values):
            f.write(f"{word}::{value}\n")
    print(f"Extracted {min(len(words), len(values))} word-value pairs.")

def open_file(filepath):
    try:
        if sys.platform.startswith('darwin'):  # macOS
            subprocess.run(['open', '-a', 'Cursor', filepath], check=True)
        elif sys.platform.startswith('win'):   # Windows
            subprocess.run(['cursor', filepath], check=True)
        elif sys.platform.startswith('linux'): # Linux
            subprocess.run(['cursor', filepath], check=True)
        else:
            print("Unsupported OS for opening with Cursor.")
    except subprocess.CalledProcessError as e:
        print(f"Failed to open {filepath} with Cursor: {e}")
    except FileNotFoundError:
        print("Cursor command not found. Please ensure it is installed and in your PATH.")

if __name__ == '__main__':
    input_filepath = "/Users/jordan/Documents/AED/shopmanipulator.txt"
    output_filepath = "/Users/jordan/Documents/AED/shopmanipulatoroutput.txt"
    
    process_file(input_filepath, output_filepath)
    print(f"Words and values extracted and saved to {output_filepath}")
    
    # Automatically open the output file with Cursor
    open_file(output_filepath)