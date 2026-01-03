import re

def parse_line(line):
    # Regex to extract the Index at the end of the line
    # Line format: Found value within range at address: <ADDR>, Value: <VAL>, Initial Address: <INIT_ADDR>, Index: <IDX>
    match = re.search(r'Index:\s*(\d+)', line)
    if match:
        return int(match.group(1))
    return None

def main():
    entries = []
    
    # Read reportStripper.txt
    try:
        with open('reportStripper.txt', 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('Found value within range at address:'):
                    idx = parse_line(line)
                    if idx is not None:
                        entries.append((idx, line))
    except FileNotFoundError:
        print("reportStripper.txt not found.")
        return

    # Read reportStripperERROR.txt
    try:
        with open('reportStripperERROR.txt', 'r') as f:
            for line in f:
                line = line.strip()
                # Only take lines that look like valid entries (not undefined, not QVal)
                if line.startswith('Found value within range at address:'):
                    idx = parse_line(line)
                    if idx is not None:
                        entries.append((idx, line))
    except FileNotFoundError:
        print("reportStripperERROR.txt not found.")
        return

    # Sort entries by index
    entries.sort(key=lambda x: x[0])

    # Write back to reportStripper.txt
    with open('reportStripper.txt', 'w') as f:
        for idx, line in entries:
            f.write(line + '\n')
    
    print(f"Successfully processed {len(entries)} entries and updated reportStripper.txt")

if __name__ == "__main__":
    main()
