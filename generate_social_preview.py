import json
import os
import io
import numpy as np
import matplotlib.pyplot as plt
from PIL import Image

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, "budget_data.json")

    with open(json_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    years_str = config["years"]
    components = config["components"]
    num_years = len(years_str)
    years_indices = np.arange(num_years)

    # Output parameters
    gif_path = os.path.join(script_dir, "assets", "social_preview.gif")
    os.makedirs(os.path.dirname(gif_path), exist_ok=True)

    frames = []
    # Total animation steps: 36 frames (~2.5s duration)
    steps = 36

    for step in range(steps + 1):
        # Progress from 0.0 to 6.0
        progress = (step / float(steps)) * (num_years - 1)
        is_final = (step == steps)

        # Strictly set figure size to 6.4 x 3.2 inches at 100 DPI (= 640x320 px)
        fig = plt.figure(figsize=(6.4, 3.2), dpi=100, facecolor="white")
        
        # Subplot area:
        # bottom=0.22 (0.22 * 320 = 70.4px, > 50px padding)
        # top=0.74 (0.74 * 320 = 236.8px, < 270px padding)
        # left=0.10, right=0.92
        ax = fig.add_axes([0.10, 0.22, 0.82, 0.52], facecolor="white")

        # Grid lines
        ax.grid(axis="y", linestyle="--", linewidth=0.8, alpha=0.5, color="#cbd5e1")
        
        # Grid/axes styling
        ax.set_xlim(-0.3, 6.3)
        ax.set_ylim(-3, 73)
        ax.set_xticks(years_indices)
        ax.set_xticklabels(years_str, fontsize=8, fontweight="bold", color="#334155")
        
        # Style Y ticks/labels
        ax.set_yticks([0, 20, 40, 60])
        ax.set_yticklabels(["0%", "20%", "40%", "60%"], fontsize=8, color="#64748b")
        
        # Spines
        for spine in ["top", "right", "left"]:
            ax.spines[spine].set_visible(False)
        ax.spines["bottom"].set_color("#cbd5e1")
        ax.spines["bottom"].set_linewidth(1.2)
        ax.tick_params(bottom=True, left=False, colors="#cbd5e1")
        
        # Render Title strictly inside bounds
        # Let's place the title at y=0.82 (0.82 * 320 = 262px, which is < 270px and > 50px)
        fig.text(
            0.10, 0.84, 
            "Evolution of AI Frontier Training Budgets", 
            fontsize=10.5, 
            fontweight="bold", 
            color="#0f172a"
        )
        
        # Add badge (2020 - 2026) at top right
        fig.text(
            0.92, 0.84,
            "2020 - 2026",
            fontsize=8,
            fontweight="bold",
            color="#475569",
            bbox=dict(boxstyle="round,pad=0.3", facecolor="#f1f5f9", edgecolor="none"),
            ha="right"
        )

        # Plot curves
        full_years_passed = int(np.floor(progress))
        frac = progress - full_years_passed

        for comp in components:
            name = comp["name"]
            values = comp["values"]
            color = comp["color"]
            
            # Simple shorthand name for legend
            legend_name = name.split(" (")[0] if " (" in name else name
            legend_name = legend_name.split(" &")[0] if " &" in legend_name else legend_name

            # Calculate line points
            x_pts = []
            y_pts = []
            for idx in range(full_years_passed + 1):
                x_pts.append(idx)
                y_pts.append(values[idx])
            
            if frac > 0.0 and full_years_passed < num_years - 1:
                x_pts.append(progress)
                y_pts.append(values[full_years_passed] + frac * (values[full_years_passed + 1] - values[full_years_passed]))
            
            # Plot the line curve
            if len(x_pts) > 0:
                ax.plot(x_pts, y_pts, color=color, linewidth=2.0, label=legend_name)
                
                # Plot completed dots
                for idx in range(full_years_passed + 1):
                    ax.plot(
                        idx, values[idx], 
                        marker="o", markersize=4.5, 
                        markerfacecolor="white", markeredgecolor=color, 
                        markeredgewidth=1.5
                    )
                    if is_final:
                        # Label every point at the end
                        val = values[idx]
                        offset = 2.2 if name != "Energy" else -4.5
                        ax.text(
                            idx, val + offset, 
                            f"{val}%", 
                            ha="center", va="bottom" if name != "Energy" else "top", 
                            fontsize=7.5, fontweight="bold", color=color
                        )

                # Show running value tag
                if not is_final and len(y_pts) > 0:
                    last_x = x_pts[-1]
                    last_y = y_pts[-1]
                    # Marker at leading point
                    ax.plot(last_x, last_y, marker="o", markersize=4.5, color=color)
                    
                    offset = 2.2 if name != "Energy" else -4.5
                    ax.text(
                        last_x, last_y + offset, 
                        f"{int(round(last_y))}%", 
                        ha="center", va="bottom" if name != "Energy" else "top", 
                        fontsize=7.0, fontweight="bold", color=color
                    )

        # Plot horizontal legend below the title
        ax.legend(
            loc="lower left",
            bbox_to_anchor=(0.0, 1.01),
            ncol=5,
            frameon=False,
            fontsize=7.5,
            handlelength=1.2,
            columnspacing=1.0,
            handletextpad=0.4
        )

        # Save frame to buffer
        buf = io.BytesIO()
        plt.savefig(buf, format="png", dpi=100)
        buf.seek(0)
        frames.append(Image.open(buf))
        plt.close(fig)

    # Save to animated GIF with durations:
    durations = [70] * len(frames)
    durations[-1] = 2400

    frames[0].save(
        gif_path,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=True
    )
    
    # Verify size
    size_bytes = os.path.getsize(gif_path)
    print(f"Generated GIF at: {gif_path}")
    print(f"File size: {size_bytes / (1024 * 1024):.2f} MB ({size_bytes / 1024:.2f} KB)")

if __name__ == "__main__":
    main()
