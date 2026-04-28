import os
import glob

# Define the target directory and the output file path
target_dir = r"C:\Users\tavar\Downloads\Nova pasta (2)"
output_file = os.path.join(target_dir, "merged_output.txt")

# Find all .txt files in the target directory
search_pattern = os.path.join(target_dir, "*.txt")
txt_files = glob.glob(search_pattern)

# Exclude the output file from the list if it already exists from a previous run
if output_file in txt_files:
    txt_files.remove(output_file)

# Open the output file in write mode
with open(output_file, 'w', encoding='utf-8') as outfile:
    
    # Iterate through each text file found
    for file_path in txt_files:
        
        # Read the content of the current file
        with open(file_path, 'r', encoding='utf-8') as infile:
            content = infile.read()
            
            # Write the content to the output file
            outfile.write(content)
            
            # Add a separator between files
            outfile.write("\n\n")

print(f"Merged {len(txt_files)} files into {output_file}")