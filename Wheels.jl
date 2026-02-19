#<Filename>: <Wheels.jl>
#<Author>:   <DANIEL DESAI>
#<Updated>:  <2026-02-18>
#<Version>:  <0.0.2>

using Gtk
using Cairo
using Printf
using Dates

# ============================================================================
# TEST SEQUENCE DEFINITION
# ============================================================================

const TEST_STEPS = [
    (step=0, desc="Step 0: Both planes with initial balancing masses",
     m1_add=0.0, m1_angle=0.0,   m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=0.0, m2_angle=0.0,   m2_remove=0.0, m2_remove_angle=0.0),
    (step=1, desc="Step 1: M1 add 1 oz @ 45°",
     m1_add=1.0, m1_angle=45.0,  m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=0.0, m2_angle=0.0,   m2_remove=0.0, m2_remove_angle=0.0),
    (step=2, desc="Step 2: M2 add 1 oz @ 45°",
     m1_add=0.0, m1_angle=0.0,   m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=1.0, m2_angle=45.0,  m2_remove=0.0, m2_remove_angle=0.0),
    (step=3, desc="Step 3: M1 remove 1 oz @ 45° (transfer to M2) → M2 now 2 oz @ 45°",
     m1_add=0.0, m1_angle=0.0,   m1_remove=1.0, m1_remove_angle=45.0,
     m2_add=1.0, m2_angle=45.0,  m2_remove=0.0, m2_remove_angle=0.0),
    (step=4, desc="Step 4: M1 add 2 oz @ 225°",
     m1_add=2.0, m1_angle=225.0, m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=0.0, m2_angle=0.0,   m2_remove=0.0, m2_remove_angle=0.0),
    (step=5, desc="Step 5: M2 remove 2 oz @ 45°, M2 add 1 oz @ 135°",
     m1_add=0.0, m1_angle=0.0,   m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=1.0, m2_angle=135.0, m2_remove=2.0, m2_remove_angle=45.0)
]

const TOTAL_STEPS = count(s -> s.step > 0, TEST_STEPS)

# ============================================================================
# HELPERS
# ============================================================================

mass_angle_to_complex(m, a) = m * exp(im * deg2rad(a))
complex_to_mass(z) = abs(z)
function complex_to_angle(z)
    a = rad2deg(angle(z))
    return a < 0 ? a + 360 : a
end

# ============================================================================
# CSV
# ============================================================================

function initialize_csv(csv_file)
    isfile(csv_file) && return
    open(csv_file, "w") do io
        println(io, "Step,M1_Spec,M1_Actual,M1_Angle,M2_Spec,M2_Actual,M2_Angle," *
                    "M1_Equiv_Mass,M1_Equiv_Angle,M2_Equiv_Mass,M2_Equiv_Angle")
    end
end

function export_all_steps_to_csv(csv_file, completed_steps)
    try
        open(csv_file, "w") do io
            println(io, "Step,M1_Spec,M1_Actual,M1_Angle,M2_Spec,M2_Actual,M2_Angle," *
                        "M1_Equiv_Mass,M1_Equiv_Angle,M2_Equiv_Mass,M2_Equiv_Angle")
            for sd in completed_steps
                println(io, "\"$(sd.desc)\",$(sd.m1_spec),$(sd.m1_actual),$(sd.m1_angle)," *
                            "$(sd.m2_spec),$(sd.m2_actual),$(sd.m2_angle)," *
                            "$(sd.m1_equiv_mass),$(sd.m1_equiv_angle)," *
                            "$(sd.m2_equiv_mass),$(sd.m2_equiv_angle)")
            end
        end
        println("✓ Exported $(length(completed_steps)) steps to $csv_file")
    catch e
        @warn "Failed to export: $e"
    end
end

# ============================================================================
# ISOMETRIC DRAWING
# ============================================================================

# Convert a balancer angle (0° = top, clockwise) + radius in pixels
# to isometric screen (dx, dy) relative to plane centre.
# The wheel plane sits in 3D: Y axis = up (screen), X axis = recedes into screen.
# iso_skew_x, iso_skew_y: screen pixels per pixel of wheel-X (foreshortening).
function wheel_to_screen(r_px, angle_deg, iso_skew_x, iso_skew_y)
    # Balancer convention: 0° = top, clockwise
    # → math angle: 0° = right, CCW  => θ_math = 90° - angle_deg
    θ = deg2rad(90.0 - angle_deg)
    # Wheel-plane coords (right = X, up = Y), pixels
    wx = r_px * cos(θ)   # horizontal component in wheel plane
    wy = r_px * sin(θ)   # vertical component in wheel plane
    # Project: vertical stays vertical; horizontal is foreshortened + tilted
    sx =  wx * iso_skew_x
    sy = -wy - wx * iso_skew_y   # screen Y is inverted; horizontal recedes upward
    return sx, sy
end

function draw_plane(ctx, cx, cy, scale, iso_skew_x, iso_skew_y,
                    label, col_spec, col_actual, col_equiv,
                    spec_z, actual_z, equiv_z)

    # --- concentric rings (ellipses via polyline) ---
    for ri in 1:3
        r_px = ri * scale
        set_source_rgba(ctx, 0.55, 0.55, 0.55, 0.7)
        set_line_width(ctx, 1.0)
        n = 90
        first = true
        for k in 0:n
            a = 360.0 * k / n
            dx, dy = wheel_to_screen(r_px, a, iso_skew_x, iso_skew_y)
            if first; move_to(ctx, cx+dx, cy+dy); first=false
            else;      line_to(ctx, cx+dx, cy+dy)
            end
        end
        stroke(ctx)
    end

    # --- axis spokes ---
    set_source_rgba(ctx, 0.65, 0.65, 0.65, 0.5)
    set_line_width(ctx, 1.0)
    for a in [0.0, 90.0, 180.0, 270.0]
        dx, dy = wheel_to_screen(3.0*scale, a, iso_skew_x, iso_skew_y)
        move_to(ctx, cx, cy); line_to(ctx, cx+dx, cy+dy); stroke(ctx)
    end

    # --- angle labels ---
    select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
    set_font_size(ctx, 10)
    set_source_rgb(ctx, 0.25, 0.25, 0.25)
    for (a, lbl) in [(0.0,"0°"),(90.0,"90°"),(180.0,"180°"),(270.0,"270°")]
        dx, dy = wheel_to_screen(3.4*scale, a, iso_skew_x, iso_skew_y)
        move_to(ctx, cx+dx-8, cy+dy+4); show_text(ctx, lbl)
    end

    # --- plane label ---
    select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_BOLD)
    set_font_size(ctx, 14)
    set_source_rgb(ctx, 0.1, 0.1, 0.1)
    dx0, dy0 = wheel_to_screen(3.8*scale, 0.0, iso_skew_x, iso_skew_y)
    move_to(ctx, cx+dx0-8, cy+dy0-6); show_text(ctx, label)

    # --- vector drawing ---
    function draw_vec(z, color, style, tag)
        m = complex_to_mass(z)
        m < 0.001 && return
        deg = complex_to_angle(z)
        r_px = m * scale
        dx, dy = wheel_to_screen(r_px, deg, iso_skew_x, iso_skew_y)
        tx, ty = cx+dx, cy+dy

        set_source_rgb(ctx, color...)
        set_line_width(ctx, style == :equiv ? 3.0 : 2.5)

        if style == :dashed
            set_dash(ctx, [6.0, 4.0], 0.0)
            move_to(ctx, cx, cy); line_to(ctx, tx, ty); stroke(ctx)
            set_dash(ctx, Float64[], 0.0)
            arc(ctx, tx, ty, 6, 0, 2π); fill(ctx)
        elseif style == :solid
            move_to(ctx, cx, cy); line_to(ctx, tx, ty); stroke(ctx)
            rectangle(ctx, tx-5, ty-5, 10, 10); fill(ctx)
        elseif style == :equiv
            set_dash(ctx, [8.0, 3.0, 2.0, 3.0], 0.0)
            move_to(ctx, cx, cy); line_to(ctx, tx, ty); stroke(ctx)
            set_dash(ctx, Float64[], 0.0)
            move_to(ctx, tx, ty-8); line_to(ctx, tx+6, ty)
            line_to(ctx, tx, ty+8); line_to(ctx, tx-6, ty)
            close_path(ctx); fill(ctx)
        end

        set_source_rgb(ctx, 0.05, 0.05, 0.05)
        select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
        set_font_size(ctx, 9)
        off_y = style == :dashed ? -8 : 7
        move_to(ctx, tx+8, ty+off_y)
        show_text(ctx, @sprintf("%s: %.2f oz @ %.0f°", tag, m, deg))
    end

    draw_vec(spec_z,   col_spec,   :dashed, label * "S")
    draw_vec(actual_z, col_actual, :solid,  label * "A")
    draw_vec(equiv_z,  col_equiv,  :equiv,  label * "E")
end

function draw_wheel(canvas, m1_spec_z, m1_actual_z, m1_equiv_z,
                            m2_spec_z, m2_actual_z, m2_equiv_z)
    ctx = getgc(canvas)
    w   = width(canvas)
    h   = height(canvas)

    set_source_rgb(ctx, 0.96, 0.96, 0.96)
    rectangle(ctx, 0, 0, w, h); fill(ctx)

    scale      = min(w, h) / 10.0   # pixels per oz
    iso_skew_x = 0.45               # horizontal foreshortening factor
    iso_skew_y = 0.20               # vertical tilt per unit of horizontal

    # Plane centres — separated horizontally, same vertical
    sep  = w * 0.23
    cy   = h * 0.50
    cx_m1 = w/2 + sep/2   # M1 rear  (right)
    cx_m2 = w/2 - sep/2   # M2 front (left)

    # Axle — connect the two centres with a cylinder-like pair of lines
    set_source_rgba(ctx, 0.35, 0.35, 0.35, 0.8)
    set_line_width(ctx, 4.0)
    move_to(ctx, cx_m2, cy); line_to(ctx, cx_m1, cy); stroke(ctx)
    set_source_rgba(ctx, 0.6, 0.6, 0.6, 0.5)
    set_line_width(ctx, 1.5)
    move_to(ctx, cx_m2, cy-3); line_to(ctx, cx_m1, cy-3); stroke(ctx)

    # Axle end caps
    for cx_ in (cx_m1, cx_m2)
        set_source_rgba(ctx, 0.3, 0.3, 0.3, 0.9)
        arc(ctx, cx_, cy, 5, 0, 2π); fill(ctx)
    end

    # Draw rear plane (M1) first so front (M2) overlaps it
    draw_plane(ctx, cx_m1, cy, scale, iso_skew_x, iso_skew_y,
               "M1", (0.85,0.1,0.1), (0.85,0.1,0.1), (0.0,0.6,0.0),
               m1_spec_z, m1_actual_z, m1_equiv_z)

    draw_plane(ctx, cx_m2, cy, scale, iso_skew_x, iso_skew_y,
               "M2", (0.1,0.2,0.9), (0.1,0.2,0.9), (0.55,0.0,0.75),
               m2_spec_z, m2_actual_z, m2_equiv_z)

    # Legend
    select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
    set_font_size(ctx, 11)
    lx, ly = 18.0, h - 100.0
    for (color, shape, lbl) in [
            ((0.5,0.5,0.5), :circle,  "Specified (dashed)"),
            ((0.5,0.5,0.5), :square,  "Actual (solid)"),
            ((0.0,0.6,0.0), :diamond, "M1 Equivalent"),
            ((0.55,0.0,0.75),:diamond,"M2 Equivalent")]
        set_source_rgb(ctx, color...)
        if shape == :circle
            set_dash(ctx, [4.0,3.0], 0.0)
            arc(ctx, lx, ly, 5, 0, 2π); stroke(ctx)
            set_dash(ctx, Float64[], 0.0)
        elseif shape == :square
            rectangle(ctx, lx-5, ly-5, 10, 10); fill(ctx)
        elseif shape == :diamond
            move_to(ctx, lx, ly-7); line_to(ctx, lx+5, ly)
            line_to(ctx, lx, ly+7); line_to(ctx, lx-5, ly)
            close_path(ctx); fill(ctx)
        end
        set_source_rgb(ctx, 0.1, 0.1, 0.1)
        move_to(ctx, lx+14, ly+4); show_text(ctx, lbl)
        ly += 20
    end
end

# ============================================================================
# MAIN
# ============================================================================

function main()
    csv_file = "balancing_results.csv"
    initialize_csv(csv_file)

    completed_steps = []
    initial_masses  = Ref{Union{Nothing,NamedTuple}}(nothing)
    m1_cumulative   = Ref(0.0+0.0im)
    m2_cumulative   = Ref(0.0+0.0im)

    m1_spec_z   = Ref(0.0+0.0im);  m2_spec_z   = Ref(0.0+0.0im)
    m1_actual_z = Ref(0.0+0.0im);  m2_actual_z = Ref(0.0+0.0im)
    m1_equiv_z  = Ref(0.0+0.0im);  m2_equiv_z  = Ref(0.0+0.0im)

    win  = GtkWindow("Dynamic Wheel Balancing", 1600, 700)
    hbox = GtkBox(:h)
    push!(win, hbox)

    # ── Left panel ────────────────────────────────────────────────────────────
    vbox_controls = GtkBox(:v)
    set_gtk_property!(vbox_controls, :spacing, 5)
    for p in (:margin_start,:margin_end,:margin_top,:margin_bottom)
        set_gtk_property!(vbox_controls, p, 10)
    end
    push!(hbox, vbox_controls)

    lbl_step = GtkLabel("Test Step:")
    set_gtk_property!(lbl_step, :xalign, 0.0)
    push!(vbox_controls, lbl_step)

    combo_step = GtkComboBoxText()
    for s in TEST_STEPS; push!(combo_step, s.desc); end
    set_gtk_property!(combo_step, :active, 0)
    push!(vbox_controls, combo_step)

    lbl_status = GtkLabel("Completed: 0/$TOTAL_STEPS steps")
    set_gtk_property!(lbl_status, :xalign, 0.0)
    push!(vbox_controls, lbl_status)

    lbl_step_info = GtkLabel("")
    set_gtk_property!(lbl_step_info, :xalign, 0.0)
    set_gtk_property!(lbl_step_info, :wrap, true)
    push!(vbox_controls, lbl_step_info)

    push!(vbox_controls, GtkLabel(""))
    lbl_equiv_hdr = GtkLabel("")
    GAccessor.markup(lbl_equiv_hdr, "<b>Cumulative Equivalent Masses:</b>")
    set_gtk_property!(lbl_equiv_hdr, :xalign, 0.0)
    push!(vbox_controls, lbl_equiv_hdr)

    lbl_m1_equiv = GtkLabel("M1: —")
    lbl_m2_equiv = GtkLabel("M2: —")
    for l in (lbl_m1_equiv, lbl_m2_equiv)
        set_gtk_property!(l, :xalign, 0.0); push!(vbox_controls, l)
    end
    push!(vbox_controls, GtkLabel(""))

    function labeled_entry(box, lbl_text, default="0.0")
        lbl = GtkLabel(lbl_text); set_gtk_property!(lbl, :xalign, 0.0); push!(box, lbl)
        ent = GtkEntry(); set_gtk_property!(ent, :text, default); push!(box, ent); ent
    end

    entry_m1_spec   = labeled_entry(vbox_controls, "M1 Specified Mass (oz):")
    entry_m1_actual = labeled_entry(vbox_controls, "M1 Actual Mass (oz):")
    entry_m1_angle  = labeled_entry(vbox_controls, "M1 Angle (degrees):")
    push!(vbox_controls, GtkLabel(""))
    entry_m2_spec   = labeled_entry(vbox_controls, "M2 Specified Mass (oz):")
    entry_m2_actual = labeled_entry(vbox_controls, "M2 Actual Mass (oz):")
    entry_m2_angle  = labeled_entry(vbox_controls, "M2 Angle (degrees):")
    push!(vbox_controls, GtkLabel(""))

    btn_record = GtkButton("Update Plot & Record Step")
    btn_export = GtkButton("Export All Steps to CSV")
    btn_clear  = GtkButton("Clear All Steps")
    for b in (btn_record, btn_export, btn_clear); push!(vbox_controls, b); end

    # ── Canvas ────────────────────────────────────────────────────────────────
    canvas = GtkCanvas()
    set_gtk_property!(canvas, :expand, true)
    push!(hbox, canvas)

    # ── Right panel ───────────────────────────────────────────────────────────
    vbox_steps = GtkBox(:v)
    set_gtk_property!(vbox_steps, :spacing, 5)
    for p in (:margin_start,:margin_end,:margin_top,:margin_bottom)
        set_gtk_property!(vbox_steps, p, 10)
    end
    lbl_rec = GtkLabel("")
    GAccessor.markup(lbl_rec, "<b>Recorded Steps:</b>")
    set_gtk_property!(lbl_rec, :xalign, 0.0)
    push!(vbox_steps, lbl_rec)

    scrolled = GtkScrolledWindow()
    set_gtk_property!(scrolled, :min_content_width, 320)
    set_gtk_property!(scrolled, :min_content_height, 600)
    tv = GtkTextView()
    set_gtk_property!(tv, :editable, false)
    set_gtk_property!(tv, :cursor_visible, false)
    set_gtk_property!(tv, :wrap_mode, Gtk.GtkWrapMode.WORD)
    set_gtk_property!(tv, :left_margin, 5)
    set_gtk_property!(tv, :right_margin, 5)
    push!(scrolled, tv); push!(vbox_steps, scrolled)
    push!(hbox, vbox_steps)

    function step_info_text(s)
        lines = String[]
        s.m1_add    > 0 && push!(lines, "M1 add $(s.m1_add) oz @ $(s.m1_angle)°")
        s.m1_remove > 0 && push!(lines, "M1 remove $(s.m1_remove) oz @ $(s.m1_remove_angle)°")
        s.m2_add    > 0 && push!(lines, "M2 add $(s.m2_add) oz @ $(s.m2_angle)°")
        s.m2_remove > 0 && push!(lines, "M2 remove $(s.m2_remove) oz @ $(s.m2_remove_angle)°")
        isempty(lines) ? "No mass changes." : join(lines, "\n")
    end

    function update_step_display()
        buf = get_gtk_property(tv, :buffer, GtkTextBuffer)
        text = ""
        if isempty(completed_steps)
            text = "No steps recorded yet.\n\nRecord steps as you complete them."
        else
            if !isnothing(initial_masses[])
                im_ = initial_masses[]
                text *= "═══════════════════════════\nINITIAL BALANCING MASSES:\n═══════════════════════════\n"
                text *= "M1: $(im_.m1_actual) oz @ $(im_.m1_angle)°\n"
                text *= "M2: $(im_.m2_actual) oz @ $(im_.m2_angle)°\n═══════════════════════════\n\n"
            end
            for (i, sd) in enumerate(completed_steps)
                text *= "$i. $(sd.desc)\n"
                text *= "   M1: spec=$(sd.m1_spec), actual=$(sd.m1_actual), angle=$(sd.m1_angle)°\n"
                text *= "   M2: spec=$(sd.m2_spec), actual=$(sd.m2_actual), angle=$(sd.m2_angle)°\n"
                text *= "   ↳ M1 equiv: $(round(sd.m1_equiv_mass,digits=3)) oz @ $(round(sd.m1_equiv_angle,digits=1))°\n"
                text *= "   ↳ M2 equiv: $(round(sd.m2_equiv_mass,digits=3)) oz @ $(round(sd.m2_equiv_angle,digits=1))°\n\n"
            end
        end
        set_gtk_property!(buf, :text, text)
    end

    update_step_display()

    @guarded draw(canvas) do widget
        try
            draw_wheel(widget,
                m1_spec_z[], m1_actual_z[], m1_equiv_z[],
                m2_spec_z[], m2_actual_z[], m2_equiv_z[])
        catch e
            println("ERROR in draw: $e"); println(stacktrace(catch_backtrace()))
        end
    end

    signal_connect(combo_step, "changed") do widget
        idx = get_gtk_property(combo_step, :active, Int) + 1
        (idx < 1 || idx > length(TEST_STEPS)) && return
        s = TEST_STEPS[idx]
        if s.m1_add > 0
            set_gtk_property!(entry_m1_spec,  :text, string(s.m1_add))
            set_gtk_property!(entry_m1_angle, :text, string(s.m1_angle))
        else
            set_gtk_property!(entry_m1_spec,  :text, "0.0")
            set_gtk_property!(entry_m1_angle, :text, "0.0")
        end
        if s.m2_add > 0
            set_gtk_property!(entry_m2_spec,  :text, string(s.m2_add))
            set_gtk_property!(entry_m2_angle, :text, string(s.m2_angle))
        else
            set_gtk_property!(entry_m2_spec,  :text, "0.0")
            set_gtk_property!(entry_m2_angle, :text, "0.0")
        end
        set_gtk_property!(entry_m1_actual, :text, "0.0")
        set_gtk_property!(entry_m2_actual, :text, "0.0")
        set_gtk_property!(lbl_step_info,   :label, step_info_text(s))
    end

    set_gtk_property!(lbl_step_info, :label, step_info_text(TEST_STEPS[1]))

    signal_connect(btn_record, "clicked") do widget
        try
            idx = get_gtk_property(combo_step, :active, Int) + 1
            s   = TEST_STEPS[idx]

            m1_sv  = parse(Float64, get_gtk_property(entry_m1_spec,   :text, String))
            m1_av  = parse(Float64, get_gtk_property(entry_m1_actual, :text, String))
            m1_ang = parse(Float64, get_gtk_property(entry_m1_angle,  :text, String))
            m2_sv  = parse(Float64, get_gtk_property(entry_m2_spec,   :text, String))
            m2_av  = parse(Float64, get_gtk_property(entry_m2_actual, :text, String))
            m2_ang = parse(Float64, get_gtk_property(entry_m2_angle,  :text, String))

            m1_spec_z[]   = s.m1_add > 0 ? mass_angle_to_complex(s.m1_add, s.m1_angle) : 0.0+0.0im
            m2_spec_z[]   = s.m2_add > 0 ? mass_angle_to_complex(s.m2_add, s.m2_angle) : 0.0+0.0im
            m1_actual_z[] = mass_angle_to_complex(m1_av, m1_ang)
            m2_actual_z[] = mass_angle_to_complex(m2_av, m2_ang)

            # Net change this step = addition - removal (both at their defined angles)
            m1_add_z    = s.m1_add    > 0 ? mass_angle_to_complex(m1_av,       s.m1_angle)        : 0.0+0.0im
            m1_remove_z = s.m1_remove > 0 ? mass_angle_to_complex(s.m1_remove, s.m1_remove_angle) : 0.0+0.0im
            m2_add_z    = s.m2_add    > 0 ? mass_angle_to_complex(m2_av,       s.m2_angle)        : 0.0+0.0im
            m2_remove_z = s.m2_remove > 0 ? mass_angle_to_complex(s.m2_remove, s.m2_remove_angle) : 0.0+0.0im
            m1_net = m1_add_z - m1_remove_z
            m2_net = m2_add_z - m2_remove_z

            m1_cumulative[] += m1_net;  m2_cumulative[] += m2_net
            m1_equiv_z[]     = m1_cumulative[];  m2_equiv_z[] = m2_cumulative[]

            m1_em = complex_to_mass(m1_cumulative[]);  m1_ea = complex_to_angle(m1_cumulative[])
            m2_em = complex_to_mass(m2_cumulative[]);  m2_ea = complex_to_angle(m2_cumulative[])

            set_gtk_property!(lbl_m1_equiv, :label, @sprintf("M1: %.3f oz @ %.1f°", m1_em, m1_ea))
            set_gtk_property!(lbl_m2_equiv, :label, @sprintf("M2: %.3f oz @ %.1f°", m2_em, m2_ea))

            idx == 1 && (initial_masses[] = (m1_actual=m1_av, m1_angle=m1_ang,
                                             m2_actual=m2_av, m2_angle=m2_ang))
            draw(canvas)

            push!(completed_steps, (desc=s.desc,
                m1_spec=m1_sv, m1_actual=m1_av, m1_angle=m1_ang,
                m2_spec=m2_sv, m2_actual=m2_av, m2_angle=m2_ang,
                m1_equiv_mass=m1_em, m1_equiv_angle=m1_ea,
                m2_equiv_mass=m2_em, m2_equiv_angle=m2_ea))

            set_gtk_property!(lbl_status, :label,
                "Completed: $(length(completed_steps))/$TOTAL_STEPS steps")
            update_step_display()
            println("✓ $(s.desc)")
            println("  M1 equiv: $(round(m1_em,digits=3)) oz @ $(round(m1_ea,digits=1))°")
            println("  M2 equiv: $(round(m2_em,digits=3)) oz @ $(round(m2_ea,digits=1))°")
        catch e
            println("Error: $e"); println(stacktrace(catch_backtrace()))
        end
    end

    signal_connect(btn_export, "clicked") do widget
        isempty(completed_steps) && (println("⚠ No steps recorded."); return)
        export_all_steps_to_csv(csv_file, completed_steps)
    end

    signal_connect(btn_clear, "clicked") do widget
        empty!(completed_steps); initial_masses[] = nothing
        for r in (m1_cumulative, m2_cumulative, m1_spec_z, m2_spec_z,
                  m1_actual_z, m2_actual_z, m1_equiv_z, m2_equiv_z)
            r[] = 0.0+0.0im
        end
        set_gtk_property!(lbl_status,   :label, "Completed: 0/$TOTAL_STEPS steps")
        set_gtk_property!(lbl_m1_equiv, :label, "M1: —")
        set_gtk_property!(lbl_m2_equiv, :label, "M2: —")
        update_step_display(); draw(canvas)
        println("✓ Cleared")
    end

    showall(win)
    println("Dynamic Wheel Balancing v0.0.5")

    if !isinteractive()
        c = Condition()
        signal_connect(win, :destroy) do widget; notify(c); end
        wait(c)
    end
end

main()