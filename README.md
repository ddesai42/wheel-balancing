# Wheels

A Julia-based GUI application for recording and visualizing dynamic balancing test data for wheel balancing with two measurement planes (M1 and M2).

## Overview

This application provides an interactive interface for conducting dynamic balancing tests following a predefined 5-step test sequence. It displays balancing masses as vectors on a polar plot and records all test data for export to CSV.

## Features

- **Predefined Test Sequence**: Five-step test protocol for systematic balancing verification
- **Real-time Visualization**: Polar plot showing specified vs. actual balancing masses
- **Data Recording**: Track all completed test steps with full details
- **CSV Export**: Export complete test results for analysis
- **Initial Mass Tracking**: Separate storage of baseline balancing configuration

## Dependencies

```julia
using Gtk
using Cairo
using Printf
using Dates
```

## Installation

1. Install Julia (version 1.6 or higher recommended)
2. Install required packages:

```julia
using Pkg
Pkg.add("Gtk")
Pkg.add("Cairo")
```

## Usage

### Running the Application

```bash
Wheels.jl
```

### Workflow

1. **Select Test Step**: Choose from the dropdown (Step 0 through Step 4)
2. **Enter Actual Masses**: 
   - Specified values auto-populate from the test sequence
   - Enter the actual measured masses for M1 and M2
   - Angles are preset based on the test step
3. **Record Step**: Click "Update Plot & Record Step" to:
   - Update the polar plot visualization
   - Save the step data internally
4. **Repeat**: Complete all test steps in sequence
5. **Export**: Click "Export All Steps to CSV" to save results to `balancing_results.csv`

### Test Sequence

| Step | Description |
|------|-------------|
| **Step 0** | Baseline with initial balancing masses |
| **Step 1** | Add 1 oz at 90° on M1 |
| **Step 2** | M1 add 1 oz at 90°, M2 add 1 oz at 0° |
| **Step 3** | M1 remove 2 oz @ 90° add 1 oz @ 180°, M2 add 1 oz @ 0° |
| **Step 4** | M1 remove 1 oz @ 180° add 2 oz @ 90°, M2 remove 2 oz @ 0° add 2 oz @ 270° |

## Visualization

The polar plot displays:

- **Red Vectors**: M1 plane data
  - 🔴 Dashed circle: Specified mass
  - 🟥 Solid square: Actual mass
- **Blue Vectors**: M2 plane data
  - 🔵 Dashed circle: Specified mass
  - 🟦 Solid square: Actual mass
- **Angle Convention**: 
  - 0° at bottom
  - 90° at right
  - 180° at top
  - 270° at left

## Output

### CSV Format

The exported CSV file (`balancing_results.csv`) contains:

```csv
Step,M1_Specified_Mass,M1_Actual_Mass,M1_Angle,M2_Specified_Mass,M2_Actual_Mass,M2_Angle
"Step 0: Both planes...",0.0,0.0,0.0,0.0,0.0,0.0
"Step 1: Add 1 oz...",1.0,0.95,90.0,0.0,0.0,0.0
...
```

Each row represents one completed test step with all mass and angle measurements.

### Recorded Steps Panel

The right panel displays:
- Initial balancing masses from Step 0
- All completed steps with full details
- Running count of completed steps

## Features Explained

### Initial Balancing Masses

Step 0 captures the baseline balancing configuration. These values are displayed separately in the recorded steps panel and serve as the reference for all subsequent test steps.

### Clear All Steps

Clear All Steps:
- Removes all recorded data
- Clears the plot
- Resets the initial masses
- Allows starting a fresh test sequence

## Mathematical Representation

Masses and angles are internally represented as complex numbers:
- **Magnitude** = mass value
- **Angle** = position on the balancing plane
- **Vector addition/subtraction** uses complex arithmetic










---

**Note**: For best results, follow the test sequence in order and record Step 0 first to establish the baseline balancing configuration.
