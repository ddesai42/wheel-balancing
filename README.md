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

- **Step 0**: Baseline with initial balancing masses
- **Step 1**: Add 1 oz at 90° on M1
- **Step 2**: M1 add 1 oz at 90°, M2 add 1 oz at 0°
- **Step 3**: M1 remove 2 oz @ 90° add 1 oz @ 180°, M2 add 1 oz @ 0°
- **Step 4**: M1 remove 1 oz @ 180° add 2 oz @ 90°, M2 remove 2 oz @ 0° add 2 oz @ 270°

## Visualization

The polar plot displays:

- **Red Vectors**: M1 plane data
  - Dashed circle: Specified mass
  - Solid square: Actual mass
- **Blue Vectors**: M2 plane data
  - Dashed circle: Specified mass
  - Solid square: Actual mass
- **Angle Convention**: 
  - 0° at bottom
  - 90° at right
  - 180° at top
  - 270° at left

## Output

### CSV Format

The exported CSV file (`balancing_results.csv`) contains:
```
Step,M1_Specified_Mass,M1_Actual_Mass,M1_Angle,M2_Specified_Mass,M2_Actual_Mass,M2_Angle
