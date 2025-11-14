import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

df = pd.read_csv('everything.csv')

fig, axes = plt.subplots(1, 3, figsize=(15, 4))
features = ['cpu_load', 'ram_load', 'prompt_length']

for i, feature in enumerate(features):
    axes[i].scatter(df[feature], df['ttft_sec'], alpha=0.5)
    axes[i].set_xlabel(feature)
    axes[i].set_ylabel('ttft_sec')
    axes[i].set_title(f'{feature} vs ttft_sec')

plt.tight_layout()
plt.show()

# Correlation matrix
correlation = df[['cpu_load', 'ram_load', 'prompt_length', 'ttft_sec']].corr()
print(correlation)
