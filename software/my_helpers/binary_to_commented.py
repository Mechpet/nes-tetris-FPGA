import re
def translate(lines):
    # Go through every line and if a line contains a binary number, strip comments and comment like in font_rom.sv
    return_lines = []
    for line in lines:
        stripped_line = line.strip()
        if stripped_line[0:3] == "8'b":
            binary_num = stripped_line[3:11]
            # Found binary number.
            line = line.rstrip()
            last_num = re.match('.+([0-9])[^0-9]*$', line)
            line = line[:last_num.start(1) + 1]
            line += ' '
            for bit in binary_num:
                if bit == '0':
                    line += ' '
                else:
                    line += '*'
            line += '\n'

        return_lines.append(line)
    
    return return_lines

txt_file = input(f"What is the .txt file?: ")
out_file = input(f"What is the output .txt file?: ")

try:
    with open(txt_file) as f:
        lines = f.readlines()
except FileNotFoundError:
    print(f"ERROR: No .txt file named {txt_file} was found.")
else:
    new_lines = translate(lines)
    print(new_lines)
    with open(out_file, 'w') as f:
        f.writelines(new_lines)