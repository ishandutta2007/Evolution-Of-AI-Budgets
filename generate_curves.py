import json
import os
import matplotlib.pyplot as plt

# Load configuration and data from JSON
script_dir = os.path.dirname(os.path.abspath(__file__))
json_path = os.path.join(script_dir, 'budget_data.json')

with open(json_path, 'r', encoding='utf-8') as f:
    config = json.load(f)

years = config['years']
components = config['components']

# Create the plot
plt.figure(figsize=(10, 6), dpi=100)

# Plot each component as a line and annotate all points
for comp in components:
    label = comp['name']
    val_series = comp['values']
    color = comp.get('color', None)
    
    plt.plot(years, val_series, marker='o', linewidth=2.5, label=label, color=color)
    
    # Annotate all points
    for year, val in zip(years, val_series):
        plt.text(year, val + 1.2, f'{val}%', ha='center', va='bottom', fontsize=8, color=color, fontweight='bold')

# Styling the layout
plt.title('Evolution of AI Frontier Training Budgets (2020 – 2026)', fontsize=14, fontweight='bold', pad=20)
plt.xlabel('Year', fontsize=12, labelpad=10)
plt.ylabel('Mean Percentage of Total Budget (%)', fontsize=12, labelpad=10)
plt.ylim(0, 75)
plt.grid(axis='y', linestyle='--', alpha=0.5)

# Place the legend prominently in upper left to prevent overlap
plt.legend(loc='upper left', frameon=True, facecolor='white', edgecolor='none', shadow=True)

# Final tight layout processing
plt.tight_layout()

# Save plot to assets directory
assets_dir = os.path.join(script_dir, 'assets')
os.makedirs(assets_dir, exist_ok=True)
plot_path = os.path.join(assets_dir, 'ai_budget_evolution.png')
plt.savefig(plot_path, dpi=300, bbox_inches='tight')

# Display the script's visual output
plt.show()
