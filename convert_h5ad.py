#!/usr/bin/env python3
import anndata
import sys

try:
    adata = anndata.read_h5ad('dataset.h5ad')
    print(f'Loaded: {adata.n_obs} obs, {adata.n_vars} vars')
    df = adata.to_df()
    df.to_csv('dataset.csv')
    print('Saved to dataset.csv')
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
