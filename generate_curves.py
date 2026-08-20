import matplotlib.pyplot as plt

# Data configuration
years = ['2020', '2021', '2022', '2023', '2024', '2025', '2026']

# Initializing lists safely to bypass markdown stripping bugs
chips_list = [30, 35, 42, 50, 57, 63, 65]
dc_list = [10, 12, 14, 16, 18, 19, 20]
staff_list = [48, 40, 32, 23, 16, 11, 8]
energy_list = [2, 3, 3, 4, 4, 4, 4]
data_list = [10, 10, 9, 7, 5, 3, 3]

data = {
    'Chips & Compute Hardware': chips_list,
    'Data Center Infrastructure': dc_list,
    'R&D Staff (Human Capital)': staff_list,
    'Energy & Electricity': energy_list,
    'Data Procurement & RLHF': data_list
}

colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd']

# Create the plot
plt.figure(figsize=(10, 6), dpi=100)

# Plot each component as a line
for (label, values), color in zip(data.items(), colors):
    # Convert to standard list explicitly
    val_series = list(values)
    plt.plot(years, val_series, marker='o', linewidth=2.5, label=label, color=color)
    
    # Add data labels to the first and last points for better scannability
    plt.text(years[0], val_series[0] - 3, f'{val_series[0]}%', ha='center', va='top', fontsize=9, color=color, fontweight='bold')
    plt.text(years[-1], val_series[-1] + 1.5, f'{val_series[-1]}%', ha='center', va='bottom', fontsize=9, color=color, fontweight='bold')

# Styling the layout
plt.title('Evolution of AI Frontier Training Budgets (2020 – 2026)', fontsize=14, fontweight='bold', pad=20)
plt.xlabel('Year', fontsize=12, labelpad=10)
plt.ylabel('Mean Percentage of Total Budget (%)', fontsize=12, labelpad=10)
plt.ylim(0, 100)
plt.grid(axis='y', linestyle='--', alpha=0.5)

# Place the legend prominently
plt.legend(loc='upper right', frameon=True, facecolor='white', edgecolor='none', shadow=True)

# Final tight layout processing
plt.tight_layout()

# Display the script's visual output
plt.show()
