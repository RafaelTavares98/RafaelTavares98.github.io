import pandas as pd

# 1. Define your specific paths (using 'r' to read the raw Windows path)
file_path = r"C:\Users\tavar\Desktop\Data Analyst Portifolio\RafaelTavares98.github.io\Tableau\delivery analysis\delivery analysis.csv"
output_path = r"C:\Users\tavar\Desktop\Data Analyst Portifolio\RafaelTavares98.github.io\Tableau\delivery analysis\product_melt.csv"

# 2. Read the original dataset
df = pd.read_csv(file_path)

# 3. Define the product columns to explode
# (Checking for both with-spaces and without-spaces just in case)
target_products = [
    "Mnt Wines", "Mnt Fruits", "Mnt Meat Products", 
    "Mnt Fish Products", "Mnt Sweet Products", "Mnt Gold Prods"
]
product_cols = [col for col in df.columns if col in target_products or col.replace(' ', '') in [p.replace(' ', '') for p in target_products]]

# 4. Define all other columns as 'id_vars' (these will be kept and duplicated for each row)
id_cols = [col for col in df.columns if col not in product_cols]

# 5. Explode the data (Wide to Long)
df_exploded = pd.melt(
    df,
    id_vars=id_cols,              # Anchor columns (ID, Income, Age, etc.)
    value_vars=product_cols,      # Columns to explode
    var_name="Product Category",  # New column name for the category
    value_name="Historical Spend" # New column name for the money spent
)

# 6. Save to the new copy file (Leaves original untouched)
df_exploded.to_csv(output_path, index=False)

print(f"Success! Exploded data saved as a copy here:\n{output_path}")