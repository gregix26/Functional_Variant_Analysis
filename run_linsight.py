import pyBigWig
import pandas as pd
import sys

# --- Config ---
VEP_CSV = sys.argv[1]          # your VEP CSV file
BIGWIG = sys.argv[2]           # LINSIGHT bigwig file
OUTPUT = sys.argv[3]           # output CSV name

# --- Load data ---
df = pd.read_csv(VEP_CSV)
print(f"Loaded {len(df)} variants")
print(f"Columns: {df.columns.tolist()}")

# --- Score function ---
bw = pyBigWig.open(BIGWIG)

def get_linsight_score(location):
    try:
        chrom, coords = str(location).split(':')
        chrom = 'chr' + chrom
        pos_parts = coords.split('-')
        start = int(pos_parts[0]) - 1
        end = int(pos_parts[-1])
        vals = bw.values(chrom, start, end)
        valid = [v for v in vals if v is not None]
        return max(valid) if valid else None
    except Exception:
        return None

# --- Apply scores ---
df['LINSIGHT'] = df['Location'].apply(get_linsight_score)
print(f"Scored variants. NaN count: {df['LINSIGHT'].isna().sum()}")

bw.close()

df_nc_sorted = df.sort_values('LINSIGHT', ascending=False, na_position='last')

df_nc_sorted.to_csv(OUTPUT, index=False)
print(f"Saved {len(df_nc_sorted)} non-coding variants to {OUTPUT}")
