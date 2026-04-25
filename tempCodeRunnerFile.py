def open_file(filepath):
    try:
        if sys.platform.startswith('darwin'):  # macOS
            subprocess.run(['open', '-a', 'Windsurf', filepath], check=True)
        elif sys.platform.startswith('win'):   # Windows
            subprocess.run(['windsurf', filepath], check=True)
        elif sys.platform.startswith('linux'): # Linux
            subprocess.run(['windsurf', filepath], check=True)
        else:
            print("Unsupported OS for opening with Windsurf.")
    except subprocess.CalledProcessError as e:
        print(f"Failed to open {filepath} with Windsurf: {e}")
    except FileNotFoundError:
        print("Windsurf command not found. Please ensure it is installed and in your PATH.")

if __name__ == '__main__':
    input_filepath = "/Users/jordan/Documents/AED/shopmanipulator.txt"
    output_filepath = "/Users/jordan/Documents/AED/shopmanipulatoroutput.txt"
    
    process_file(input_filepath, output_filepath)
    print(f"Words and values extracted and saved to {output_filepath}")
    
    # Automatically open the output file with Windsurf
