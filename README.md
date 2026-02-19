# Wheels.jl

**Dynamic Wheel Balancing Data Logger**


A Julia/GTK desktop application for recording, visualizing, and exporting data from a two-plane dynamic wheel balancing test sequence. Vectors are plotted in an isometric perspective showing both balancing planes as they sit on the wheel axle. The Wheelz version has simpler (non-sequence-based) functionality

---

## Requirements

- Julia ≥ 1.9
- The following Julia packages:
  - [`Gtk`](https://github.com/JuliaGraphics/Gtk.jl)
  - [`Cairo`](https://github.com/JuliaGraphics/Cairo.jl)
  - `Printf` (standard library)
  - `Dates` (standard library)

Install dependencies from the Julia REPL:

```julia
using Pkg
Pkg.add(["Gtk", "Cairo"])
```

---

## Running

```bash
julia Wheels.jl
```

Or from the Julia REPL:

```julia
include("Wheels.jl")
```

---

## Overview

The application guides an operator through a six-step balancing test sequence on a two-plane wheel (M1 = rear plane, M2 = front plane). At each step the operator records the actual mass placed or removed, and the application:

- Plots the specified and actual vectors for the current step on both wheel planes
- Accumulates a running **equivalent mass-angle** for each plane (complex vector sum of all additions and removals to date)
- Displays all recorded data in a scrollable step log
- Exports all results to CSV on demand

---

## Test Sequence

Defined as a `const` FOR ACTION - intake from a .json or .csv

Step 0 records the initial balancing masses already present on the wheel before the test sequence begins.

---

## Workflow

1. Launch the application.
2. Select **Step 0** and enter the initial balancing masses already on the wheel. Click **Update Plot & Record Step**. _This step is optional!_
3. For each subsequent step (1–5):
   - Select the step from the dropdown. Specified values auto-fill; actual fields reset to 0.
   - The **step info label** shows exactly what to add or remove.
   - Physically add/remove the indicated masses on the wheel.
   - Enter the **actual mass placed** and its **angle** in the entry fields.
   - Click **Update Plot & Record Step**.
4. When all steps are complete, click **Export All Steps to CSV**.

> **Note:** Removal steps do not require an entry — the removal magnitude is taken from the test sequence definition. Only additions require operator input.

---

## Display

### Isometric Plot (centre panel)

Both wheel planes are rendered in an isometric perspective as if viewed from the front-right, with M2 (front) on the left and M1 (rear) on the right, connected by the axle.

On each plane, three vector types are drawn:

| Marker | Line | Meaning |
|--------|------|---------|
| Circle | Dashed | **Specified** — the mass/angle called for by the test sequence |
| Square | Solid | **Actual** — the mass/angle entered by the operator |
| Diamond | Dash-dot | **Equivalent** — cumulative complex sum of all masses placed on this plane to date |

M1 vectors are drawn in **red** (equivalent: **green**).
M2 vectors are drawn in **blue** (equivalent: **purple**).

### Left Panel

- Step selector dropdown
- Step info label (what to add/remove this step)
- Cumulative equivalent mass readout for M1 and M2
- Data entry fields for specified and actual masses and angles
- Action buttons

### Right Panel

Scrollable log of all recorded steps, showing specified, actual, and equivalent mass-angle for each plane at each step.

---

## Equivalent Mass Calculation

The equivalent mass for each plane is the complex vector sum of all net changes recorded so far:

```
z_equiv = Σ (z_addition − z_removal)
```

where:
- **Additions** use the operator-entered actual mass at the step-defined angle
- **Removals** use the step-defined removal magnitude and angle

The equivalent mass and angle are then:
```
mass  = |z_equiv|
angle = arg(z_equiv)   [0°–360°, 0° = top, clockwise]
```

---

## CSV Output

Clicking **Export All Steps to CSV** writes `balancing_results.csv` to the working directory with the following columns:

| Column | Description |
|--------|-------------|
| `Step` | Step description |
| `M1_Spec` | M1 specified mass (oz) |
| `M1_Actual` | M1 actual mass entered (oz) |
| `M1_Angle` | M1 angle (degrees) |
| `M2_Spec` | M2 specified mass (oz) |
| `M2_Actual` | M2 actual mass entered (oz) |
| `M2_Angle` | M2 angle (degrees) |
| `M1_Equiv_Mass` | M1 cumulative equivalent mass (oz) |
| `M1_Equiv_Angle` | M1 cumulative equivalent angle (degrees) |
| `M2_Equiv_Mass` | M2 cumulative equivalent mass (oz) |
| `M2_Equiv_Angle` | M2 cumulative equivalent angle (degrees) |

---

## Angle Convention

All angles follow the **balancer instrument convention**:
- **0° = top of wheel**
- **Clockwise positive**
- Range: 0°–360°
