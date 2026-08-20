import os
import matplotlib.pyplot as plt

# Data configuration
years = ["2020", "2021", "2022", "2023", "2024", "2025", "2026"]

# Initializing lists safely to bypass markdown stripping bugs
chips_list = [30, 35, 42, 50, 57, 63, 65]
dc_list = [10, 12, 14, 16, 18, 19, 20]
staff_list = [48, 40, 32, 23, 16, 11, 8]
energy_list = [2, 3, 3, 4, 4, 4, 4]
data_list = [10, 10, 9, 7, 5, 3, 3]

data = {
    "Chips & Compute Hardware": chips_list,
    "Data Center Infrastructure": dc_list,
    "R&D Staff (Human Capital)": staff_list,
    "Energy & Electricity": energy_list,
    "Data Procurement & RLHF": data_list,
}

colors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd"]

# Create the plot
plt.figure(figsize=(10, 6), dpi=100)

# Plot each component as a line and annotate all points
for (label, values), color in zip(data.items(), colors):
    val_series = list(values)
    plt.plot(years, val_series, marker="o", linewidth=2.5, label=label, color=color)

    # Annotate all points
    for year, val in zip(years, val_series):
        # Adjust vertical offset if needed for clarity
        plt.text(
            year,
            val + 1.2,
            f"{val}%",
            ha="center",
            va="bottom",
            fontsize=8,
            color=color,
            fontweight="bold",
        )

# Styling the layout
plt.title(
    "Evolution of AI Frontier Training Budgets (2020 – 2026)",
    fontsize=14,
    fontweight="bold",
    pad=20,
)
plt.xlabel("Year", fontsize=12, labelpad=10)
plt.ylabel("Mean Percentage of Total Budget (%)", fontsize=12, labelpad=10)
plt.ylim(0, 75)
plt.grid(axis="y", linestyle="--", alpha=0.5)

# Place the legend prominently in upper left to prevent overlap
plt.legend(
    loc="upper left", frameon=True, facecolor="white", edgecolor="none", shadow=True
)

# Final tight layout processing
plt.tight_layout()

# Save plot to assets directory
assets_dir = os.path.join(os.path.dirname(__file__), "assets")
os.makedirs(assets_dir, exist_ok=True)
plot_path = os.path.join(assets_dir, "ai_budget_evolution.png")
plt.savefig(plot_path, dpi=300, bbox_inches="tight")

# Display the script's visual output
plt.show()
