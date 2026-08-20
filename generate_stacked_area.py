import json
import os
import matplotlib.pyplot as plt
import numpy as np

# Load configuration and data from JSON
script_dir = os.path.dirname(os.path.abspath(__file__))
json_path = os.path.join(script_dir, "budget_data.json")

with open(json_path, "r", encoding="utf-8") as f:
    config = json.load(f)

years = config["years"]
components = config["components"]

labels = [c["name"] for c in components]
colors = [c.get("color", "#1f77b4") for c in components]
values_matrix = np.array([c["values"] for c in components])

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
        text_color = "black"# if val < 5 else "white"
        if str(year) == "2020":
            x_offset = 0.1
        elif str(year) == "2026":
            x_offset = -0.1
        else:
            x_offset = 0
        ax.text(
            x_idx + x_offset,
            mid,
            f"{val}%",
            ha="center",
            va="center",
            fontsize=9,
            fontweight="bold",
            color=text_color,
        )

# Styling layout
ax.set_title(
    "Evolution of AI Frontier Training Budgets (2020 – 2026)",
    fontsize=15,
    fontweight="bold",
    pad=25,
)
ax.set_xlabel("Year", fontsize=12, labelpad=10)
ax.set_ylabel("Share of Frontier Training Budget (%)", fontsize=12, labelpad=10)
ax.set_ylim(0, 100)
ax.set_xlim(0, len(years) - 1)
ax.set_xticks(range(len(years)))
ax.set_xticklabels(years)
ax.grid(axis="y", linestyle="--", alpha=0.4)

# Top horizontal legend
ax.legend(
    loc="upper center",
    bbox_to_anchor=(0.5, 1.06),
    ncol=5,
    frameon=True,
    facecolor="white",
    edgecolor="#cccccc",
    fontsize=9.5,
)

plt.tight_layout()

# Save plot to assets directory
assets_dir = os.path.join(script_dir, "assets")
os.makedirs(assets_dir, exist_ok=True)
plot_path = os.path.join(assets_dir, "ai_budget_stacked_area.png")
plt.savefig(plot_path, dpi=300, bbox_inches="tight")

# Display output
plt.show()
