import os
import matplotlib.pyplot as plt
import numpy as np

# Data configuration
years = ['2020', '2021', '2022', '2023', '2024', '2025', '2026']

chips_list = [30, 35, 42, 50, 57, 63, 65]
dc_list = [10, 12, 14, 16, 18, 19, 20]
staff_list = [48, 40, 32, 23, 16, 11, 8]
energy_list = [2, 3, 3, 4, 4, 4, 4]
data_list = [10, 10, 9, 7, 5, 3, 3]

labels = [
    'Chips & Compute Hardware',
    'Data Center Infrastructure',
    'R&D Staff (Human Capital)',
    'Energy & Electricity',
    'Data Procurement & RLHF'
]

values_matrix = np.array([
    chips_list,
    dc_list,
    staff_list,
    energy_list,
    data_list
])

colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd']

# Create figure
fig, ax = plt.subplots(figsize=(12, 7), dpi=100)

# Stacked area plot
ax.stackplot(years, values_matrix, labels=labels, colors=colors, alpha=0.88)

# Compute cumulative baselines to position center percentage annotations
cumulative = np.zeros(len(years))
for row_idx, row in enumerate(values_matrix):
    prev_cumulative = cumulative.copy()
    cumulative += row
    mid_points = (prev_cumulative + cumulative) / 2.0
    
    for x_idx, (year, val, mid) in enumerate(zip(years, row, mid_points)):
        # Contrast coloring based on band thickness
        text_color = 'black' if val < 5 else 'white'
        ax.text(x_idx, mid, f'{val}%', ha='center', va='center', fontsize=9, fontweight='bold', color=text_color)

# Styling layout
ax.set_title('Evolution of AI Frontier Training Budgets (2020 – 2026)', fontsize=15, fontweight='bold', pad=25)
ax.set_xlabel('Year', fontsize=12, labelpad=10)
ax.set_ylabel('Share of Frontier Training Budget (%)', fontsize=12, labelpad=10)
ax.set_ylim(0, 100)
ax.set_xlim(0, len(years) - 1)
ax.set_xticks(range(len(years)))
ax.set_xticklabels(years)
ax.grid(axis='y', linestyle='--', alpha=0.4)

# Top horizontal legend
ax.legend(loc='upper center', bbox_to_anchor=(0.5, 1.08), ncol=3, frameon=True, facecolor='white', edgecolor='#cccccc', fontsize=9.5)

plt.tight_layout()

# Save plot to assets directory
assets_dir = os.path.join(os.path.dirname(__file__), 'assets')
os.makedirs(assets_dir, exist_ok=True)
plot_path = os.path.join(assets_dir, 'ai_budget_stacked_area.png')
plt.savefig(plot_path, dpi=300, bbox_inches='tight')

# Display output
plt.show()
