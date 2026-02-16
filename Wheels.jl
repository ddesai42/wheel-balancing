using Gtk
using Cairo
using Printf
using Dates

# ============================================================================
# TEST SEQUENCE DEFINITION
# ============================================================================

const TEST_STEPS = [
    (step=0, desc="Step 0: Both planes with initial balancing masses", 
     m1_add=0.0, m1_angle=0.0, m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=0.0, m2_angle=0.0, m2_remove=0.0, m2_remove_angle=0.0),
    (step=1, desc="Step 1: Add 1 oz at 90° on M1", 
     m1_add=1.0, m1_angle=90.0, m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=0.0, m2_angle=0.0, m2_remove=0.0, m2_remove_angle=0.0),
    (step=2, desc="Step 2: M1 add 1 oz at 90°, M2 add 1 oz at 0°", 
     m1_add=1.0, m1_angle=90.0, m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=1.0, m2_angle=0.0, m2_remove=0.0, m2_remove_angle=0.0),
    (step=3, desc="Step 3: M1 remove 2 @ 90° add 1 @ 180°, M2 add 1 @ 0°", 
     m1_add=1.0, m1_angle=180.0, m1_remove=2.0, m1_remove_angle=90.0,
     m2_add=1.0, m2_angle=0.0, m2_remove=0.0, m2_remove_angle=0.0),
    (step=4, desc="Step 4: M1 remove 1 @ 180° add 2 @ 90°, M2 remove 2 @ 0° add 2 @ 270°", 
     m1_add=2.0, m1_angle=90.0, m1_remove=1.0, m1_remove_angle=180.0,
     m2_add=2.0, m2_angle=270.0, m2_remove=2.0, m2_remove_angle=0.0),
]

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function mass_angle_to_complex(mass, angle_deg)
    return mass * exp(im * deg2rad(angle_deg))
end

function complex_to_mass(z)
    return abs(z)
end

function complex_to_angle(z)
    return rad2deg(angle(z))
end

# ============================================================================
# CSV FUNCTIONS
# ============================================================================

function initialize_csv(csv_file)
    if !isfile(csv_file)
        open(csv_file, "w") do io
            println(io, "Step,M1_Specified_Mass,M1_Actual_Mass,M1_Angle,M2_Specified_Mass,M2_Actual_Mass,M2_Angle")
        end
    end
end

function save_to_csv(csv_file, step_desc, m1_spec, m1_actual, m1_angle, m2_spec, m2_actual, m2_angle)
    try
        open(csv_file, "a") do io
            println(io, "\"$step_desc\",$m1_spec,$m1_actual,$m1_angle,$m2_spec,$m2_actual,$m2_angle")
        end
        println("✓ Data saved to $csv_file")
        return true
    catch e
        @warn "Failed to save data: $e"
        return false
    end
end

function export_all_steps_to_csv(csv_file, completed_steps)
    try
        open(csv_file, "w") do io
            # Write header
            println(io, "Step,M1_Specified_Mass,M1_Actual_Mass,M1_Angle,M2_Specified_Mass,M2_Actual_Mass,M2_Angle")
            
            # Write all completed steps
            for step_data in completed_steps
                println(io, "\"$(step_data.desc)\",$(step_data.m1_spec),$(step_data.m1_actual),$(step_data.m1_angle),$(step_data.m2_spec),$(step_data.m2_actual),$(step_data.m2_angle)")
            end
        end
        println("✓ Exported $(length(completed_steps)) steps to $csv_file")
        return true
    catch e
        @warn "Failed to export data: $e"
        return false
    end
end

# ============================================================================
# PLOTTING FUNCTION 
# ============================================================================

function draw_target_plot(canvas, m1_data, m2_data)
    ctx = getgc(canvas)
    
    # Get canvas dimensions
    w = width(canvas)
    h = height(canvas)
    
    # Clear background - LIGHT (white)
    set_source_rgb(ctx, 1, 1, 1)
    rectangle(ctx, 0, 0, w, h)
    fill(ctx)
    
    # Setup coordinate system - center at middle
    cx = w / 2
    cy = h / 2
    scale_factor = min(w, h) / 8.0
    
    # Draw concentric circles
    set_source_rgb(ctx, 0.7, 0.7, 0.7)
    set_line_width(ctx, 1)
    for r in [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
        arc(ctx, cx, cy, r * scale_factor, 0, 2π)
        stroke(ctx)
    end
    
    # Draw angle reference lines
    set_source_rgba(ctx, 0.8, 0.8, 0.8, 0.5)
    set_line_width(ctx, 1)
    for angle in [0, 90, 180, 270]
        display_angle = 270 - angle
        rad = deg2rad(display_angle)
        x_end = cx + 3.0 * scale_factor * cos(rad)
        y_end = cy - 3.0 * scale_factor * sin(rad)
        move_to(ctx, cx, cy)
        line_to(ctx, x_end, y_end)
        stroke(ctx)
    end
    
    # Draw angle labels - BLACK text
    set_source_rgb(ctx, 0, 0, 0)
    select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
    set_font_size(ctx, 12)
    
    # 0° at bottom
    move_to(ctx, cx - 10, cy + 3.4 * scale_factor)
    show_text(ctx, "0°")
    
    # 90° at right
    move_to(ctx, cx +3.5 * scale_factor, cy + 5)
    show_text(ctx, "90°")
    
    # 180° at top
    move_to(ctx, cx - 15, cy - 3.2 * scale_factor)
    show_text(ctx, "180°")
    
    # 270° at left
    move_to(ctx, cx - 3.2 * scale_factor, cy + 5)
    show_text(ctx, "270°")
    
    # Helper function to convert angle to display coordinates
    function angle_to_display(angle_deg)
        display_angle = angle_deg - 90
        return deg2rad(display_angle)
    end
    
    # Draw M1 data (RED)
    m1_spec_complex, m1_actual_complex = m1_data
    m1_spec_mass = complex_to_mass(m1_spec_complex)
    m1_actual_mass = complex_to_mass(m1_actual_complex)
    
    if m1_spec_mass > 0.001
        angle_deg = complex_to_angle(m1_spec_complex)
        rad = angle_to_display(angle_deg)
        x = m1_spec_mass * cos(rad)
        y = m1_spec_mass * sin(rad)
        px = cx + x * scale_factor
        py = cy - y * scale_factor
        
        # Draw dashed line (specified) - RED
        set_source_rgb(ctx, 1, 0, 0)
        set_line_width(ctx, 3)
        set_dash(ctx, [5.0, 5.0], 0.0)
        move_to(ctx, cx, cy)
        line_to(ctx, px, py)
        stroke(ctx)
        set_dash(ctx, Float64[], 0.0)
        
        # Draw circle (specified)
        arc(ctx, px, py, 8, 0, 2π)
        fill(ctx)
        
        # Draw label - BLACK text
        set_font_size(ctx, 10)
        set_source_rgb(ctx, 0, 0, 0)
        move_to(ctx, px + 10, py - 10)
        show_text(ctx, @sprintf("M1S: %.2f@%.0f°", m1_spec_mass, angle_deg))
    end
    
    if m1_actual_mass > 0.001
        angle_deg = complex_to_angle(m1_actual_complex)
        rad = angle_to_display(angle_deg)
        x = m1_actual_mass * cos(rad)
        y = m1_actual_mass * sin(rad)
        px = cx + x * scale_factor
        py = cy - y * scale_factor
        
        # Draw solid line (actual) - RED
        set_source_rgb(ctx, 1, 0, 0)
        set_line_width(ctx, 3)
        move_to(ctx, cx, cy)
        line_to(ctx, px, py)
        stroke(ctx)
        
        # Draw square (actual)
        rectangle(ctx, px - 7, py - 7, 14, 14)
        fill(ctx)
        
        # Draw label - BLACK text
        set_font_size(ctx, 10)
        set_source_rgb(ctx, 0, 0, 0)
        move_to(ctx, px + 10, py + 5)
        show_text(ctx, @sprintf("M1A: %.2f@%.0f°", m1_actual_mass, angle_deg))
    end
    
    # Draw M2 data (BLUE)
    m2_spec_complex, m2_actual_complex = m2_data
    m2_spec_mass = complex_to_mass(m2_spec_complex)
    m2_actual_mass = complex_to_mass(m2_actual_complex)
    
    if m2_spec_mass > 0.001
        angle_deg = complex_to_angle(m2_spec_complex)
        rad = angle_to_display(angle_deg)
        x = m2_spec_mass * cos(rad)
        y = m2_spec_mass * sin(rad)
        px = cx + x * scale_factor
        py = cy - y * scale_factor
        
        # Draw dashed line (specified) - BLUE
        set_source_rgb(ctx, 0, 0, 1)
        set_line_width(ctx, 3)
        set_dash(ctx, [5.0, 5.0], 0.0)
        move_to(ctx, cx, cy)
        line_to(ctx, px, py)
        stroke(ctx)
        set_dash(ctx, Float64[], 0.0)
        
        # Draw circle (specified)
        arc(ctx, px, py, 8, 0, 2π)
        fill(ctx)
        
        # Draw label - BLACK text
        set_font_size(ctx, 10)
        set_source_rgb(ctx, 0, 0, 0)
        move_to(ctx, px + 10, py - 10)
        show_text(ctx, @sprintf("M2S: %.2f@%.0f°", m2_spec_mass, angle_deg))
    end
    
    if m2_actual_mass > 0.001
        angle_deg = complex_to_angle(m2_actual_complex)
        rad = angle_to_display(angle_deg)
        x = m2_actual_mass * cos(rad)
        y = m2_actual_mass * sin(rad)
        px = cx + x * scale_factor
        py = cy - y * scale_factor
        
        # Draw solid line (actual) - BLUE
        set_source_rgb(ctx, 0, 0, 1)
        set_line_width(ctx, 3)
        move_to(ctx, cx, cy)
        line_to(ctx, px, py)
        stroke(ctx)
        
        # Draw square (actual)
        rectangle(ctx, px - 7, py - 7, 14, 14)
        fill(ctx)
        
        # Draw label - BLACK text
        set_font_size(ctx, 10)
        set_source_rgb(ctx, 0, 0, 0)
        move_to(ctx, px + 10, py + 5)
        show_text(ctx, @sprintf("M2A: %.2f@%.0f°", m2_actual_mass, angle_deg))
    end
    
    # Draw legend - BLACK text
    set_font_size(ctx, 11)
    legend_x = 20
    legend_y = 30
    
    # M1 Specified (Red circle, dashed)
    set_source_rgb(ctx, 1, 0, 0)
    arc(ctx, legend_x, legend_y, 6, 0, 2π)
    fill(ctx)
    set_source_rgb(ctx, 0, 0, 0)
    move_to(ctx, legend_x + 15, legend_y + 5)
    show_text(ctx, "M1 Specified")
    
    # M1 Actual (Red square, solid)
    legend_y += 20
    set_source_rgb(ctx, 1, 0, 0)
    rectangle(ctx, legend_x - 6, legend_y - 6, 12, 12)
    fill(ctx)
    set_source_rgb(ctx, 0, 0, 0)
    move_to(ctx, legend_x + 15, legend_y + 5)
    show_text(ctx, "M1 Actual")
    
    # M2 Specified (Blue circle, dashed)
    legend_y += 20
    set_source_rgb(ctx, 0, 0, 1)
    arc(ctx, legend_x, legend_y, 6, 0, 2π)
    fill(ctx)
    set_source_rgb(ctx, 0, 0, 0)
    move_to(ctx, legend_x + 15, legend_y + 5)
    show_text(ctx, "M2 Specified")
    
    # M2 Actual (Blue square, solid)
    legend_y += 20
    set_source_rgb(ctx, 0, 0, 1)
    rectangle(ctx, legend_x - 6, legend_y - 6, 12, 12)
    fill(ctx)
    set_source_rgb(ctx, 0, 0, 0)
    move_to(ctx, legend_x + 15, legend_y + 5)
    show_text(ctx, "M2 Actual")
end

# ============================================================================
# MAIN GUI
# ============================================================================

function main()
    csv_file = "balancing_results.csv"
    initialize_csv(csv_file)
    
    # Array to store completed steps
    completed_steps = []
    
    # Storage for initial balancing masses (from Step 0)
    initial_masses = Ref{Union{Nothing, NamedTuple}}(nothing)
    
    # Create main window
    win = GtkWindow("Dynamic Balancing GUI", 1600, 700)
    
    # Apply dark theme using CSS
    cssProvider = Gtk.CssProviderLeaf(data="""
        window {
            background-color: #2b2b2b;
        }
        * {
            background-color: #2b2b2b;
            color: #ffffff;
        }
        entry {
            background-color: #3c3c3c;
            color: #ffffff;
        }
        button {
            background-color: #404040;
            color: #ffffff;
        }
        button:hover {
            background-color: #505050;
        }
        label {
            color: #ffffff;
        }
        combobox {
            background-color: #3c3c3c;
            color: #ffffff;
        }
        textview {
            background-color: #3c3c3c;
            color: #ffffff;
        }
    """)
    function set_gtk_style!(widget::Gtk.GtkWidget, value::Int)
        sc = Gtk.GAccessor.style_context(widget)
        push!(sc, Gtk.StyleProvider(cssProvider), value)
    end
    
    # Main horizontal box
    hbox = GtkBox(:h)
    push!(win, hbox)
    
    # Left panel - Controls
    vbox_controls = GtkBox(:v)
    set_gtk_property!(vbox_controls, :spacing, 5)
    set_gtk_property!(vbox_controls, :margin_start, 10)
    set_gtk_property!(vbox_controls, :margin_end, 10)
    set_gtk_property!(vbox_controls, :margin_top, 10)
    set_gtk_property!(vbox_controls, :margin_bottom, 10)
    push!(hbox, vbox_controls)
    
    # Test step selector
    lbl_step = GtkLabel("Test Step:")
    set_gtk_property!(lbl_step, :xalign, 0.0)
    push!(vbox_controls, lbl_step)
    
    combo_step = GtkComboBoxText()
    for step in TEST_STEPS
        push!(combo_step, step.desc)
    end
    set_gtk_property!(combo_step, :active, 0)
    push!(vbox_controls, combo_step)
    
    # Status label for completed steps
    lbl_status = GtkLabel("Completed: 0/5 steps")
    set_gtk_property!(lbl_status, :xalign, 0.0)
    push!(vbox_controls, lbl_status)
    
    push!(vbox_controls, GtkLabel(""))  # Spacer
    
    # M1 Controls
    lbl_m1_spec = GtkLabel("M1 Specified Mass (oz):")
    set_gtk_property!(lbl_m1_spec, :xalign, 0.0)
    push!(vbox_controls, lbl_m1_spec)
    entry_m1_spec = GtkEntry()
    set_gtk_property!(entry_m1_spec, :text, "0.0")
    push!(vbox_controls, entry_m1_spec)
    
    lbl_m1_actual = GtkLabel("M1 Actual Mass (oz):")
    set_gtk_property!(lbl_m1_actual, :xalign, 0.0)
    push!(vbox_controls, lbl_m1_actual)
    entry_m1_actual = GtkEntry()
    set_gtk_property!(entry_m1_actual, :text, "0.0")
    push!(vbox_controls, entry_m1_actual)
    
    lbl_m1_angle = GtkLabel("M1 Angle (degrees):")
    set_gtk_property!(lbl_m1_angle, :xalign, 0.0)
    push!(vbox_controls, lbl_m1_angle)
    entry_m1_angle = GtkEntry()
    set_gtk_property!(entry_m1_angle, :text, "0.0")
    push!(vbox_controls, entry_m1_angle)
    
    push!(vbox_controls, GtkLabel(""))  # Spacer
    
    # M2 Controls
    lbl_m2_spec = GtkLabel("M2 Specified Mass (oz):")
    set_gtk_property!(lbl_m2_spec, :xalign, 0.0)
    push!(vbox_controls, lbl_m2_spec)
    entry_m2_spec = GtkEntry()
    set_gtk_property!(entry_m2_spec, :text, "0.0")
    push!(vbox_controls, entry_m2_spec)
    
    lbl_m2_actual = GtkLabel("M2 Actual Mass (oz):")
    set_gtk_property!(lbl_m2_actual, :xalign, 0.0)
    push!(vbox_controls, lbl_m2_actual)
    entry_m2_actual = GtkEntry()
    set_gtk_property!(entry_m2_actual, :text, "0.0")
    push!(vbox_controls, entry_m2_actual)
    
    lbl_m2_angle = GtkLabel("M2 Angle (degrees):")
    set_gtk_property!(lbl_m2_angle, :xalign, 0.0)
    push!(vbox_controls, lbl_m2_angle)
    entry_m2_angle = GtkEntry()
    set_gtk_property!(entry_m2_angle, :text, "0.0")
    push!(vbox_controls, entry_m2_angle)
    
    push!(vbox_controls, GtkLabel(""))  # Spacer
    
    # Buttons
    btn_record = GtkButton("Update Plot & Record Step")
    push!(vbox_controls, btn_record)
    
    btn_export = GtkButton("Export All Steps to CSV")
    push!(vbox_controls, btn_export)
    
    btn_clear = GtkButton("Clear All Steps")
    push!(vbox_controls, btn_clear)
    
    # Right panel - Canvas for plotting
    canvas = GtkCanvas()
    set_gtk_property!(canvas, :expand, true)
    push!(hbox, canvas)
    
    # Far right panel - Recorded steps display
    vbox_steps = GtkBox(:v)
    set_gtk_property!(vbox_steps, :spacing, 5)
    set_gtk_property!(vbox_steps, :margin_start, 10)
    set_gtk_property!(vbox_steps, :margin_end, 10)
    set_gtk_property!(vbox_steps, :margin_top, 10)
    set_gtk_property!(vbox_steps, :margin_bottom, 10)
    
    lbl_recorded = GtkLabel("Recorded Steps:")
    set_gtk_property!(lbl_recorded, :xalign, 0.0)
    GAccessor.markup(lbl_recorded, "<b>Recorded Steps:</b>")
    push!(vbox_steps, lbl_recorded)
    
    # Scrolled window for step list
    scrolled_steps = GtkScrolledWindow()
    set_gtk_property!(scrolled_steps, :min_content_width, 300)
    set_gtk_property!(scrolled_steps, :min_content_height, 600)
    
    # TextView for displaying steps
    textview_steps = GtkTextView()
    set_gtk_property!(textview_steps, :editable, false)
    set_gtk_property!(textview_steps, :cursor_visible, false)
    set_gtk_property!(textview_steps, :wrap_mode, Gtk.GtkWrapMode.WORD)
    set_gtk_property!(textview_steps, :left_margin, 5)
    set_gtk_property!(textview_steps, :right_margin, 5)
    push!(scrolled_steps, textview_steps)
    push!(vbox_steps, scrolled_steps)
    
    push!(hbox, vbox_steps)
    
    # Function to update the step display
    function update_step_display()
        buffer = get_gtk_property(textview_steps, :buffer, GtkTextBuffer)
        text = ""
        
        if isempty(completed_steps)
            text = "No steps recorded yet.\n\nRecord steps as you complete them."
        else
            # Show initial balancing masses if Step 0 was recorded
            if !isnothing(initial_masses[])
                text *= "═══════════════════════════\n"
                text *= "INITIAL BALANCING MASSES:\n"
                text *= "═══════════════════════════\n"
                text *= "M1: $(initial_masses[].m1_spec) oz @ $(initial_masses[].m1_angle)°\n"
                text *= "M2: $(initial_masses[].m2_spec) oz @ $(initial_masses[].m2_angle)°\n"
                text *= "═══════════════════════════\n\n"
            end
            
            for (i, step) in enumerate(completed_steps)
                text *= "$(i). $(step.desc)\n"
                text *= "   M1: spec=$(step.m1_spec), actual=$(step.m1_actual), angle=$(step.m1_angle)°\n"
                text *= "   M2: spec=$(step.m2_spec), actual=$(step.m2_actual), angle=$(step.m2_angle)°\n\n"
            end
        end
        
        set_gtk_property!(buffer, :text, text)
    end
    
    # Initialize display
    update_step_display()
    
    # Current data storage
    m1_data = Ref((0.0 + 0.0im, 0.0 + 0.0im))
    m2_data = Ref((0.0 + 0.0im, 0.0 + 0.0im))
    
    # Canvas draw function
    @guarded draw(canvas) do widget
        try
            draw_target_plot(widget, m1_data[], m2_data[])
        catch e
            println("ERROR in draw callback: $e")
            println(stacktrace(catch_backtrace()))
        end
    end
    
    # Step selection callback
    signal_connect(combo_step, "changed") do widget
        idx = get_gtk_property(combo_step, :active, Int) + 1
        if idx > 0 && idx <= length(TEST_STEPS)
            step = TEST_STEPS[idx]
            
            # Set M1 fields
            if step.m1_add > 0
                set_gtk_property!(entry_m1_spec, :text, string(step.m1_add))
                set_gtk_property!(entry_m1_angle, :text, string(step.m1_angle))
            else
                set_gtk_property!(entry_m1_spec, :text, "0.0")
                set_gtk_property!(entry_m1_angle, :text, "0.0")
            end
            
            # Set M2 fields
            if step.m2_add > 0
                set_gtk_property!(entry_m2_spec, :text, string(step.m2_add))
                set_gtk_property!(entry_m2_angle, :text, string(step.m2_angle))
            else
                set_gtk_property!(entry_m2_spec, :text, "0.0")
                set_gtk_property!(entry_m2_angle, :text, "0.0")
            end
            
            # Reset actual mass fields to zero
            set_gtk_property!(entry_m1_actual, :text, "0.0")
            set_gtk_property!(entry_m2_actual, :text, "0.0")
            
            println("Selected: $(step.desc)")
        end
    end
    
    # Update button callback
    signal_connect(btn_record, "clicked") do widget
        try
            idx = get_gtk_property(combo_step, :active, Int) + 1
            step_desc = TEST_STEPS[idx].desc
            
            m1_spec = parse(Float64, get_gtk_property(entry_m1_spec, :text, String))
            m1_actual = parse(Float64, get_gtk_property(entry_m1_actual, :text, String))
            m1_angle = parse(Float64, get_gtk_property(entry_m1_angle, :text, String))
            
            m2_spec = parse(Float64, get_gtk_property(entry_m2_spec, :text, String))
            m2_actual = parse(Float64, get_gtk_property(entry_m2_actual, :text, String))
            m2_angle = parse(Float64, get_gtk_property(entry_m2_angle, :text, String))
            
            # Update plots
            m1_spec_complex = mass_angle_to_complex(m1_spec, m1_angle)
            m1_actual_complex = mass_angle_to_complex(m1_actual, m1_angle)
            m2_spec_complex = mass_angle_to_complex(m2_spec, m2_angle)
            m2_actual_complex = mass_angle_to_complex(m2_actual, m2_angle)
            
            m1_data[] = (m1_spec_complex, m1_actual_complex)
            m2_data[] = (m2_spec_complex, m2_actual_complex)
            
            # If this is Step 0, save as initial balancing masses
            if idx == 1  # Step 0 is at index 1
                initial_masses[] = (m1_spec=m1_actual, m1_angle=m1_angle, 
                                   m2_spec=m2_actual, m2_angle=m2_angle)
                println("✓ Saved initial balancing masses: M1=$(m1_actual)oz@$(m1_angle)°, M2=$(m2_actual)oz@$(m2_angle)°")
            end
            
            draw(canvas)
            
            # Add to completed steps array
            step_data = (desc=step_desc, m1_spec=m1_spec, m1_actual=m1_actual, m1_angle=m1_angle,
                        m2_spec=m2_spec, m2_actual=m2_actual, m2_angle=m2_angle)
            push!(completed_steps, step_data)
            
            # Update status label
            set_gtk_property!(lbl_status, :label, "Completed: $(length(completed_steps))/5 steps")
            
            # Update step display
            update_step_display()
            
            println("✓ Recorded & plotted: $step_desc")
            println("  M1 added: $m1_actual oz @ $(m1_angle)°, M2 added: $m2_actual oz @ $(m2_angle)°")
            println("  Total steps recorded: $(length(completed_steps))")
        catch e
            println("Error: $e")
            println(stacktrace(catch_backtrace()))
        end
    end
    
    # Export all steps button callback
    signal_connect(btn_export, "clicked") do widget
        if isempty(completed_steps)
            println("⚠ No steps recorded yet. Record steps first before exporting.")
            return
        end
        
        export_all_steps_to_csv(csv_file, completed_steps)
    end
    
    # Clear all steps button callback
    signal_connect(btn_clear, "clicked") do widget
        empty!(completed_steps)
        initial_masses[] = nothing
        
        # Reset the plot data to empty
        m1_data[] = (0.0 + 0.0im, 0.0 + 0.0im)
        m2_data[] = (0.0 + 0.0im, 0.0 + 0.0im)
        
        set_gtk_property!(lbl_status, :label, "Completed: 0/5 steps")
        update_step_display()
        draw(canvas)
        println("✓ Cleared all recorded steps, initial masses, and plot")
    end
    
    # Show window
    showall(win)
    
    println("Dynamic Balancing GUI")
    println("CSV: $csv_file")
    println("\nWorkflow:")
    println("  1. Select test step")
    println("  2. Enter actual masses (specified values auto-fill, actual resets to 0)")
    println("  3. Click 'Update Plot & Record Step'")
    println("  4. Repeat for all steps")
    println("  5. Click 'Export All Steps to CSV' when finished\n")
    
    # Run GTK main loop
    if !isinteractive()
        c = Condition()
        signal_connect(win, :destroy) do widget
            notify(c)
        end
        wait(c)
    end
end

main()