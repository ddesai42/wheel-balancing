#<Filename>: <Wheels.jl>
#<Author>:   <DANIEL DESAI>
#<Updated>:  <2026-02-19>
#<Version>:  <0.0.3>

using Gtk
using Cairo
using Printf
using Dates

# ============================================================================
# TEST SEQUENCE
# ============================================================================

const TEST_STEPS = [
    (step=0, desc="Step 0: Both planes with initial balancing masses",
     m1_add=0.0, m1_angle=0.0,   m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=0.0, m2_angle=0.0,   m2_remove=0.0, m2_remove_angle=0.0),
    (step=1, desc="Step 1: M1 add 1 @ 45°",
     m1_add=1.0, m1_angle=45.0,  m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=0.0, m2_angle=0.0,   m2_remove=0.0, m2_remove_angle=0.0),
    (step=2, desc="Step 2: M2 add 1 @ 45°",
     m1_add=0.0, m1_angle=0.0,   m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=1.0, m2_angle=45.0,  m2_remove=0.0, m2_remove_angle=0.0),
    (step=3, desc="Step 3: M1 remove 1 @ 45° → transfer to M2",
     m1_add=0.0, m1_angle=0.0,   m1_remove=1.0, m1_remove_angle=45.0,
     m2_add=1.0, m2_angle=45.0,  m2_remove=0.0, m2_remove_angle=0.0),
    (step=4, desc="Step 4: M1 add 2 @ 225°",
     m1_add=2.0, m1_angle=225.0, m1_remove=0.0, m1_remove_angle=0.0,
     m2_add=0.0, m2_angle=0.0,   m2_remove=0.0, m2_remove_angle=0.0),
    (step=5, desc="Step 5: M2 remove 2 @ 45°, add 1 @ 135°",
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

const CSV_HEADER = "Step,M1_Mass,M1_Angle,M2_Mass,M2_Angle," *
                   "M1_Equiv_Mass,M1_Equiv_Angle,M2_Equiv_Mass,M2_Equiv_Angle," *
                   "Static_Moment,Static_Angle,Couple_M1,Couple_M1_Angle,Couple_M2,Couple_M2_Angle"

function initialize_csv(csv_file)
    open(csv_file, "w") do io
        println(io, CSV_HEADER)
    end
end

function export_all_steps_to_csv(csv_file, completed_steps)
    try
        open(csv_file, "w") do io
            println(io, CSV_HEADER)
            for sd in completed_steps
                println(io, "\"$(sd.desc)\",$(sd.m1_mass),$(sd.m1_angle)," *
                            "$(sd.m2_mass),$(sd.m2_angle)," *
                            "$(sd.m1_equiv_mass),$(sd.m1_equiv_angle)," *
                            "$(sd.m2_equiv_mass),$(sd.m2_equiv_angle)," *
                            "$(sd.static_moment),$(sd.static_angle)," *
                            "$(sd.couple_m1),$(sd.couple_m1_angle)," *
                            "$(sd.couple_m2),$(sd.couple_m2_angle)")
            end
        end
        println("✓ Exported $(length(completed_steps)) steps to $csv_file")
    catch e
        println("ERROR in export: $e")
        println(stacktrace(catch_backtrace()))
    end
end

# ============================================================================
# DRAWING
# ============================================================================

function wheel_to_screen(r_px, angle_deg, iso_skew_x, iso_skew_y)
    θ  = deg2rad(angle_deg - 90.0)
    wx = r_px * cos(θ)
    wy = r_px * sin(θ)
    sx =  wx * iso_skew_x
    sy = -wy - wx * iso_skew_y
    return sx, sy
end

function draw_plane(ctx, cx, cy, scale, iso_skew_x, iso_skew_y,
                    label, col_spec, col_actual, col_equiv,
                    spec_z, actual_z, equiv_z)
    # Rings
    for ri in 1:3
        r_px = ri * scale
        set_source_rgba(ctx, 0.55, 0.55, 0.55, 0.7)
        set_line_width(ctx, 1.0)
        n, first = 90, true
        for k in 0:n
            dx, dy = wheel_to_screen(r_px, 360.0*k/n, iso_skew_x, iso_skew_y)
            if first; move_to(ctx, cx+dx, cy+dy); first=false
            else;      line_to(ctx, cx+dx, cy+dy)
            end
        end
        stroke(ctx)
    end

    # Spokes
    set_source_rgba(ctx, 0.65, 0.65, 0.65, 0.5)
    set_line_width(ctx, 1.0)
    for a in [0.0, 90.0, 180.0, 270.0]
        dx, dy = wheel_to_screen(3.0*scale, a, iso_skew_x, iso_skew_y)
        move_to(ctx, cx, cy); line_to(ctx, cx+dx, cy+dy); stroke(ctx)
    end

    # Angle labels
    select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
    set_font_size(ctx, 10)
    set_source_rgb(ctx, 0.25, 0.25, 0.25)
    for (a, lbl) in [(0.0,"0°"),(90.0,"90°"),(180.0,"180°"),(270.0,"270°")]
        dx, dy = wheel_to_screen(3.4*scale, a, iso_skew_x, iso_skew_y)
        move_to(ctx, cx+dx-8, cy+dy+4); show_text(ctx, lbl)
    end

    # Plane label
    select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_BOLD)
    set_font_size(ctx, 14)
    set_source_rgb(ctx, 0.1, 0.1, 0.1)
    dx0, dy0 = wheel_to_screen(3.8*scale, 0.0, iso_skew_x, iso_skew_y)
    move_to(ctx, cx+dx0-8, cy+dy0-6); show_text(ctx, label)

    # Vector helper
    function draw_vec(z, color, style, tag)
        m = complex_to_mass(z)
        m < 0.001 && return
        deg  = complex_to_angle(z)
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
        move_to(ctx, tx+8, ty + (style == :dashed ? -8 : 7))
        show_text(ctx, @sprintf("%s: %.2f @ %.0f°", tag, m, deg))
    end

    draw_vec(spec_z,   col_spec,   :dashed, label * "S")
    draw_vec(actual_z, col_actual, :solid,  label * "A")
    draw_vec(equiv_z,  col_equiv,  :equiv,  label * "E")
end

function draw_wheel(canvas, m1_spec_z, m1_actual_z, m1_equiv_z,
                            m2_spec_z, m2_actual_z, m2_equiv_z,
                            r_m1, r_m2, r_width)
    ctx = getgc(canvas)
    w   = width(canvas)
    h   = height(canvas)

    set_source_rgb(ctx, 0.96, 0.96, 0.96)
    rectangle(ctx, 0, 0, w, h); fill(ctx)

    r_max      = max(r_m1, r_m2)
    base_scale = min(w, h) / 10.0
    scale_m1   = base_scale * (r_m1 / r_max)
    scale_m2   = base_scale * (r_m2 / r_max)
    iso_skew_x = 0.45
    iso_skew_y = 0.20

    sep_raw = (r_width / r_max) * base_scale * 3.5
    sep     = clamp(sep_raw, base_scale * 1.2, w * 0.38)
    cy      = h * 0.50
    cx_m1   = w/2 + sep/2
    cx_m2   = w/2 - sep/2

    # Axle
    set_source_rgba(ctx, 0.35, 0.35, 0.35, 0.8)
    set_line_width(ctx, 4.0)
    move_to(ctx, cx_m2, cy); line_to(ctx, cx_m1, cy); stroke(ctx)
    set_source_rgba(ctx, 0.6, 0.6, 0.6, 0.5)
    set_line_width(ctx, 1.5)
    move_to(ctx, cx_m2, cy-3); line_to(ctx, cx_m1, cy-3); stroke(ctx)
    for cx_ in (cx_m1, cx_m2)
        set_source_rgba(ctx, 0.3, 0.3, 0.3, 0.9)
        arc(ctx, cx_, cy, 5, 0, 2π); fill(ctx)
    end

    draw_plane(ctx, cx_m1, cy, scale_m1, iso_skew_x, iso_skew_y,
               "M1", (0.85,0.1,0.1), (0.85,0.1,0.1), (0.0,0.6,0.0),
               m1_spec_z, m1_actual_z, m1_equiv_z)

    draw_plane(ctx, cx_m2, cy, scale_m2, iso_skew_x, iso_skew_y,
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

    # All state refs
    m1_cumulative = Ref(0.0+0.0im)
    m2_cumulative = Ref(0.0+0.0im)
    m1_spec_z     = Ref(0.0+0.0im)
    m1_actual_z   = Ref(0.0+0.0im)
    m1_equiv_z    = Ref(0.0+0.0im)
    m2_spec_z     = Ref(0.0+0.0im)
    m2_actual_z   = Ref(0.0+0.0im)
    m2_equiv_z    = Ref(0.0+0.0im)

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

    # Entry helper — defined first so available for all fields
    function labeled_entry(box, lbl_text, default="0.0")
        lbl = GtkLabel(lbl_text); set_gtk_property!(lbl, :xalign, 0.0); push!(box, lbl)
        ent = GtkEntry(); set_gtk_property!(ent, :text, default); push!(box, ent); ent
    end

    # Step selector
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

    # Units selector
    lbl_units_hdr = GtkLabel("")
    GAccessor.markup(lbl_units_hdr, "<b>Units:</b>")
    set_gtk_property!(lbl_units_hdr, :xalign, 0.0)
    push!(vbox_controls, lbl_units_hdr)

    combo_units = GtkComboBoxText()
    push!(combo_units, "oz-in")
    push!(combo_units, "g-cm")
    set_gtk_property!(combo_units, :active, 0)
    push!(vbox_controls, combo_units)
    push!(vbox_controls, GtkLabel(""))

    # Geometry inputs
    lbl_geom_hdr = GtkLabel("")
    GAccessor.markup(lbl_geom_hdr, "<b>Wheel Geometry:</b>")
    set_gtk_property!(lbl_geom_hdr, :xalign, 0.0)
    push!(vbox_controls, lbl_geom_hdr)

    entry_r_m1    = labeled_entry(vbox_controls, "M1 Radius:", "17.5")
    entry_r_m2    = labeled_entry(vbox_controls, "M2 Radius:", "16.5")
    entry_r_width = labeled_entry(vbox_controls, "Wheel Width:", "8.5")

    lbl_ratio = GtkLabel("Ratio M2/M1: 0.943")
    set_gtk_property!(lbl_ratio, :xalign, 0.0)
    push!(vbox_controls, lbl_ratio)
    push!(vbox_controls, GtkLabel(""))

    # Mass/angle inputs
    entry_m1_mass  = labeled_entry(vbox_controls, "M1 Mass:")
    entry_m1_angle = labeled_entry(vbox_controls, "M1 Angle (degrees):")
    push!(vbox_controls, GtkLabel(""))
    entry_m2_mass  = labeled_entry(vbox_controls, "M2 Mass:")
    entry_m2_angle = labeled_entry(vbox_controls, "M2 Angle (degrees):")
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
    set_gtk_property!(scrolled, :min_content_height, 400)
    tv = GtkTextView()
    set_gtk_property!(tv, :editable, false)
    set_gtk_property!(tv, :cursor_visible, false)
    set_gtk_property!(tv, :wrap_mode, Gtk.GtkWrapMode.WORD)
    set_gtk_property!(tv, :left_margin, 5)
    set_gtk_property!(tv, :right_margin, 5)
    push!(scrolled, tv); push!(vbox_steps, scrolled)

    # Equivalent masses
    push!(vbox_steps, GtkLabel(""))
    lbl_equiv_hdr = GtkLabel("")
    GAccessor.markup(lbl_equiv_hdr, "<b>Cumulative Equivalent Masses:</b>")
    set_gtk_property!(lbl_equiv_hdr, :xalign, 0.0)
    push!(vbox_steps, lbl_equiv_hdr)

    lbl_m1_equiv = GtkLabel("M1: —")
    lbl_m2_equiv = GtkLabel("M2: —")
    for l in (lbl_m1_equiv, lbl_m2_equiv)
        set_gtk_property!(l, :xalign, 0.0); push!(vbox_steps, l)
    end

    # Moments
    push!(vbox_steps, GtkLabel(""))
    lbl_moments_hdr = GtkLabel("")
    GAccessor.markup(lbl_moments_hdr, "<b>Balance Moments:</b>")
    set_gtk_property!(lbl_moments_hdr, :xalign, 0.0)
    push!(vbox_steps, lbl_moments_hdr)

    lbl_static  = GtkLabel("Static:    —")
    lbl_couple1 = GtkLabel("Couple M1: —")
    lbl_couple2 = GtkLabel("Couple M2: —")
    for l in (lbl_static, lbl_couple1, lbl_couple2)
        set_gtk_property!(l, :xalign, 0.0); push!(vbox_steps, l)
    end

    push!(hbox, vbox_steps)

    # ── Helper functions ──────────────────────────────────────────────────────

    function get_units()
        idx = get_gtk_property(combo_units, :active, Int)
        return idx == 0 ? ("oz", "in", "oz·in", "oz·in²") :
                          ("g",  "cm", "g·cm",  "g·cm²")
    end

    function get_radii()
        r_m1 = tryparse(Float64, get_gtk_property(entry_r_m1,   :text, String))
        r_m2 = tryparse(Float64, get_gtk_property(entry_r_m2,   :text, String))
        r_w  = tryparse(Float64, get_gtk_property(entry_r_width, :text, String))
        r_m1 = (r_m1 === nothing || r_m1 <= 0) ? 17.5 : r_m1
        r_m2 = (r_m2 === nothing || r_m2 <= 0) ? 16.5 : r_m2
        r_w  = (r_w  === nothing || r_w  <= 0) ?  8.5 : r_w
        return r_m1, r_m2, r_w
    end

    function update_ratio_label()
        r_m1, r_m2, _ = get_radii()
        set_gtk_property!(lbl_ratio, :label, @sprintf("Ratio M2/M1: %.3f", r_m2 / r_m1))
    end

    # Returns (s_mom, s_ang, c1_mom, c1_ang, c2_mom, c2_ang) from current state
    function compute_moments()
        r_m1, r_m2, r_w = get_radii()
        z1       = m1_cumulative[] * r_m1
        z2       = m2_cumulative[] * r_m2
        z_static = z1 + z2
        d        = r_w / 2.0
        z_c1     =  z1 * d
        z_c2     = -z2 * d
        return (complex_to_mass(z_static), complex_to_angle(z_static),
                complex_to_mass(z_c1),    complex_to_angle(z_c1),
                complex_to_mass(z_c2),    complex_to_angle(z_c2))
    end

    function update_moments()
        _, _, static_unit, couple_unit = get_units()
        s_mom, s_ang, c1_mom, c1_ang, c2_mom, c2_ang = compute_moments()
        set_gtk_property!(lbl_static,  :label,
            @sprintf("Static:    %.3f %s @ %.1f°", s_mom, static_unit, s_ang))
        set_gtk_property!(lbl_couple1, :label,
            @sprintf("Couple M1: %.3f %s @ %.1f°", c1_mom, couple_unit, c1_ang))
        set_gtk_property!(lbl_couple2, :label,
            @sprintf("Couple M2: %.3f %s @ %.1f°", c2_mom, couple_unit, c2_ang))
    end

    function update_equiv_labels()
        m1_em = complex_to_mass(m1_cumulative[])
        m1_ea = complex_to_angle(m1_cumulative[])
        m2_em = complex_to_mass(m2_cumulative[])
        m2_ea = complex_to_angle(m2_cumulative[])
        set_gtk_property!(lbl_m1_equiv, :label, @sprintf("M1: %.3f @ %.1f°", m1_em, m1_ea))
        set_gtk_property!(lbl_m2_equiv, :label, @sprintf("M2: %.3f @ %.1f°", m2_em, m2_ea))
    end

    function step_info_text(s)
        lines = String[]
        s.m1_add    > 0 && push!(lines, "M1 add $(s.m1_add) @ $(s.m1_angle)°")
        s.m1_remove > 0 && push!(lines, "M1 remove $(s.m1_remove) @ $(s.m1_remove_angle)°")
        s.m2_add    > 0 && push!(lines, "M2 add $(s.m2_add) @ $(s.m2_angle)°")
        s.m2_remove > 0 && push!(lines, "M2 remove $(s.m2_remove) @ $(s.m2_remove_angle)°")
        isempty(lines) ? "No mass changes (enter initial masses if present)." : join(lines, "\n")
    end

    function update_step_display()
        buf  = get_gtk_property(tv, :buffer, GtkTextBuffer)
        text = ""
        if isempty(completed_steps)
            text = "No steps recorded yet.\n\nRecord steps as you complete them."
        else
            if !isnothing(initial_masses[])
                im_ = initial_masses[]
                text *= "═══════════════════════════\nINITIAL BALANCING MASSES:\n═══════════════════════════\n"
                text *= "M1: $(im_.m1_mass) @ $(im_.m1_angle)°\n"
                text *= "M2: $(im_.m2_mass) @ $(im_.m2_angle)°\n═══════════════════════════\n\n"
            end
            for (i, sd) in enumerate(completed_steps)
                text *= "$i. $(sd.desc)\n"
                text *= "   M1: mass=$(sd.m1_mass), angle=$(sd.m1_angle)°\n"
                text *= "   M2: mass=$(sd.m2_mass), angle=$(sd.m2_angle)°\n"
                text *= "   ↳ M1 equiv: $(round(sd.m1_equiv_mass,digits=3)) @ $(round(sd.m1_equiv_angle,digits=1))°\n"
                text *= "   ↳ M2 equiv: $(round(sd.m2_equiv_mass,digits=3)) @ $(round(sd.m2_equiv_angle,digits=1))°\n\n"
            end
        end
        set_gtk_property!(buf, :text, text)
    end

    update_step_display()

    # ── Canvas draw callback ──────────────────────────────────────────────────
    @guarded draw(canvas) do widget
        try
            r_m1, r_m2, r_w = get_radii()
            draw_wheel(widget,
                m1_spec_z[], m1_actual_z[], m1_equiv_z[],
                m2_spec_z[], m2_actual_z[], m2_equiv_z[],
                r_m1, r_m2, r_w)
        catch e
            println("ERROR in draw: $e"); println(stacktrace(catch_backtrace()))
        end
    end

    # ── Geometry / units callbacks ────────────────────────────────────────────
    for entry in (entry_r_m1, entry_r_m2, entry_r_width)
        signal_connect(entry, "changed") do _
            update_ratio_label()
            update_moments()
            draw(canvas)
        end
    end

    signal_connect(combo_units, "changed") do _
        update_moments()
    end

    # ── Step selector callback ────────────────────────────────────────────────
    signal_connect(combo_step, "changed") do widget
        idx = get_gtk_property(combo_step, :active, Int) + 1
        (idx < 1 || idx > length(TEST_STEPS)) && return
        s = TEST_STEPS[idx]
        set_gtk_property!(entry_m1_mass,  :text, s.m1_add > 0 ? string(s.m1_add)   : "0.0")
        set_gtk_property!(entry_m1_angle, :text, s.m1_add > 0 ? string(s.m1_angle) : "0.0")
        set_gtk_property!(entry_m2_mass,  :text, s.m2_add > 0 ? string(s.m2_add)   : "0.0")
        set_gtk_property!(entry_m2_angle, :text, s.m2_add > 0 ? string(s.m2_angle) : "0.0")
        set_gtk_property!(lbl_step_info,  :label, step_info_text(s))
    end

    set_gtk_property!(lbl_step_info, :label, step_info_text(TEST_STEPS[1]))

    # ── Record callback ───────────────────────────────────────────────────────
    signal_connect(btn_record, "clicked") do widget
        try
            idx = get_gtk_property(combo_step, :active, Int) + 1
            s   = TEST_STEPS[idx]

            m1_mass = parse(Float64, get_gtk_property(entry_m1_mass,  :text, String))
            m1_ang  = parse(Float64, get_gtk_property(entry_m1_angle, :text, String))
            m2_mass = parse(Float64, get_gtk_property(entry_m2_mass,  :text, String))
            m2_ang  = parse(Float64, get_gtk_property(entry_m2_angle, :text, String))

            # Per-step plot vectors
            if idx == 1  # Step 0: treat entries as initial condition
                m1_spec_z[]   = mass_angle_to_complex(m1_mass, m1_ang)
                m2_spec_z[]   = mass_angle_to_complex(m2_mass, m2_ang)
            else
                m1_spec_z[]   = s.m1_add > 0 ? mass_angle_to_complex(s.m1_add, s.m1_angle) : 0.0+0.0im
                m2_spec_z[]   = s.m2_add > 0 ? mass_angle_to_complex(s.m2_add, s.m2_angle) : 0.0+0.0im
            end
            m1_actual_z[] = mass_angle_to_complex(m1_mass, m1_ang)
            m2_actual_z[] = mass_angle_to_complex(m2_mass, m2_ang)

            # Cumulative update
            if idx == 1  # Step 0: direct initial addition
                m1_cumulative[] += mass_angle_to_complex(m1_mass, m1_ang)
                m2_cumulative[] += mass_angle_to_complex(m2_mass, m2_ang)
            else
                m1_add_z    = s.m1_add    > 0 ? mass_angle_to_complex(m1_mass,     s.m1_angle)        : 0.0+0.0im
                m1_remove_z = s.m1_remove > 0 ? mass_angle_to_complex(s.m1_remove, s.m1_remove_angle) : 0.0+0.0im
                m2_add_z    = s.m2_add    > 0 ? mass_angle_to_complex(m2_mass,     s.m2_angle)        : 0.0+0.0im
                m2_remove_z = s.m2_remove > 0 ? mass_angle_to_complex(s.m2_remove, s.m2_remove_angle) : 0.0+0.0im
                m1_cumulative[] += m1_add_z - m1_remove_z
                m2_cumulative[] += m2_add_z - m2_remove_z
            end

            m1_equiv_z[] = m1_cumulative[]
            m2_equiv_z[] = m2_cumulative[]

            m1_em = complex_to_mass(m1_cumulative[])
            m1_ea = complex_to_angle(m1_cumulative[])
            m2_em = complex_to_mass(m2_cumulative[])
            m2_ea = complex_to_angle(m2_cumulative[])

            update_equiv_labels()
            update_moments()

            # Compute moments for storage
            s_mom, s_ang, c1_mom, c1_ang, c2_mom, c2_ang = compute_moments()

            idx == 1 && (initial_masses[] = (m1_mass=m1_mass, m1_angle=m1_ang,
                                             m2_mass=m2_mass, m2_angle=m2_ang))
            draw(canvas)

            push!(completed_steps, (desc=s.desc,
                m1_mass=m1_mass,   m1_angle=m1_ang,
                m2_mass=m2_mass,   m2_angle=m2_ang,
                m1_equiv_mass=m1_em, m1_equiv_angle=m1_ea,
                m2_equiv_mass=m2_em, m2_equiv_angle=m2_ea,
                static_moment=s_mom,  static_angle=s_ang,
                couple_m1=c1_mom,     couple_m1_angle=c1_ang,
                couple_m2=c2_mom,     couple_m2_angle=c2_ang))

            set_gtk_property!(lbl_status, :label,
                "Completed: $(length(completed_steps))/$TOTAL_STEPS steps")
            update_step_display()
            println("✓ $(s.desc)")
            println("  M1 equiv: $(round(m1_em,digits=3)) @ $(round(m1_ea,digits=1))°")
            println("  M2 equiv: $(round(m2_em,digits=3)) @ $(round(m2_ea,digits=1))°")
        catch e
            println("Error: $e"); println(stacktrace(catch_backtrace()))
        end
    end

    # ── Export callback ───────────────────────────────────────────────────────
    signal_connect(btn_export, "clicked") do widget
        if isempty(completed_steps)
            println("⚠ No steps recorded.")
            return
        end
        export_all_steps_to_csv(csv_file, completed_steps)
    end

    # ── Clear callback ────────────────────────────────────────────────────────
    signal_connect(btn_clear, "clicked") do widget
        empty!(completed_steps); initial_masses[] = nothing
        for r in (m1_cumulative, m2_cumulative, m1_spec_z, m2_spec_z,
                  m1_actual_z, m2_actual_z, m1_equiv_z, m2_equiv_z)
            r[] = 0.0+0.0im
        end
        set_gtk_property!(lbl_status,   :label, "Completed: 0/$TOTAL_STEPS steps")
        set_gtk_property!(lbl_m1_equiv, :label, "M1: —")
        set_gtk_property!(lbl_m2_equiv, :label, "M2: —")
        set_gtk_property!(lbl_static,   :label, "Static:    —")
        set_gtk_property!(lbl_couple1,  :label, "Couple M1: —")
        set_gtk_property!(lbl_couple2,  :label, "Couple M2: —")
        update_step_display(); draw(canvas)
        println("✓ Cleared")
    end

    showall(win)
    println("Dynamic Wheel Balancing v0.0.3")

    if !isinteractive()
        c = Condition()
        signal_connect(win, :destroy) do widget; notify(c); end
        wait(c)
    end
end

main()