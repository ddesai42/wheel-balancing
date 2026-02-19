#<Filename>: <Wheelz.jl>
#<Author>:   <DANIEL DESAI>
#<Updated>:  <2026-02-19>
#<Version>:  <0.0.1>

using Gtk
using Cairo
using Printf
using Dates

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
                   "Static_Moment,Static_Angle,Couple_M1,Couple_M1_Angle,Couple_M2,Couple_M2_Angle"

function export_to_csv(csv_file, rows)
    try
        open(csv_file, "w") do io
            println(io, CSV_HEADER)
            for r in rows
                println(io, "\"$(r.desc)\",$(r.m1_mass),$(r.m1_angle)," *
                            "$(r.m2_mass),$(r.m2_angle)," *
                            "$(r.static_moment),$(r.static_angle)," *
                            "$(r.couple_m1),$(r.couple_m1_angle)," *
                            "$(r.couple_m2),$(r.couple_m2_angle)")
            end
        end
        println("✓ Exported to $csv_file")
    catch e
        println("ERROR in export: $e"); println(stacktrace(catch_backtrace()))
    end
end

# ============================================================================
# DRAWING
# ============================================================================

function wheel_to_screen(r_px, angle_deg, skx, sky)
    θ = deg2rad(angle_deg - 90.0)
    wx, wy = r_px * cos(θ), r_px * sin(θ)
    return wx * skx, -wy - wx * sky
end

function draw_plane(ctx, cx, cy, scale, skx, sky, label,
                    init_z, corr_z, equiv_z, col_init, col_corr, col_equiv)

    # Rings
    for ri in 1:3
        set_source_rgba(ctx, 0.55, 0.55, 0.55, 0.7)
        set_line_width(ctx, 1.0)
        n, first = 72, true
        for k in 0:n
            dx, dy = wheel_to_screen(ri*scale, 360.0*k/n, skx, sky)
            if first; move_to(ctx, cx+dx, cy+dy); first=false
            else;      line_to(ctx, cx+dx, cy+dy)
            end
        end
        stroke(ctx)
    end

    # Spokes + angle labels
    set_source_rgba(ctx, 0.65, 0.65, 0.65, 0.5)
    set_line_width(ctx, 1.0)
    select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
    set_font_size(ctx, 9)
    for (a, lbl) in [(0.0,"0°"),(90.0,"90°"),(180.0,"180°"),(270.0,"270°")]
        dx, dy = wheel_to_screen(3.0*scale, a, skx, sky)
        move_to(ctx, cx, cy); line_to(ctx, cx+dx, cy+dy); stroke(ctx)
        set_source_rgb(ctx, 0.3, 0.3, 0.3)
        dx2, dy2 = wheel_to_screen(3.35*scale, a, skx, sky)
        move_to(ctx, cx+dx2-7, cy+dy2+3); show_text(ctx, lbl)
        set_source_rgba(ctx, 0.65, 0.65, 0.65, 0.5)
    end

    # Plane label
    select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_BOLD)
    set_font_size(ctx, 12)
    set_source_rgb(ctx, 0.1, 0.1, 0.1)
    dx0, dy0 = wheel_to_screen(3.7*scale, 0.0, skx, sky)
    move_to(ctx, cx+dx0-6, cy+dy0-5); show_text(ctx, label)

    function draw_vec(z, color, style, tag)
        m = complex_to_mass(z); m < 0.001 && return
        deg = complex_to_angle(z)
        dx, dy = wheel_to_screen(m*scale, deg, skx, sky)
        tx, ty = cx+dx, cy+dy

        set_source_rgb(ctx, color...)
        set_line_width(ctx, style == :equiv ? 3.0 : 2.0)

        if style == :solid
            move_to(ctx, cx, cy); line_to(ctx, tx, ty); stroke(ctx)
            rectangle(ctx, tx-4, ty-4, 8, 8); fill(ctx)
        elseif style == :equiv
            set_dash(ctx, [7.0,3.0,2.0,3.0], 0.0)
            move_to(ctx, cx, cy); line_to(ctx, tx, ty); stroke(ctx)
            set_dash(ctx, Float64[], 0.0)
            move_to(ctx, tx, ty-7); line_to(ctx, tx+5, ty)
            line_to(ctx, tx, ty+7); line_to(ctx, tx-5, ty)
            close_path(ctx); fill(ctx)
        end

        set_source_rgb(ctx, 0.05, 0.05, 0.05)
        select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
        set_font_size(ctx, 8)
        move_to(ctx, tx+6, ty + (style == :solid ? 6 : -6))
        show_text(ctx, @sprintf("%s: %.2f@%.0f°", tag, m, deg))
    end

    draw_vec(init_z,  col_init,  :solid, label*"i")
    draw_vec(corr_z,  col_corr,  :solid, label*"c")
    draw_vec(equiv_z, col_equiv, :equiv, label*"E")
end

function draw_wheel(canvas, init_m1, init_m2, corr_m1, corr_m2,
                    equiv_m1, equiv_m2, r_m1, r_m2, r_width)
    ctx = getgc(canvas)
    w, h = width(canvas), height(canvas)

    set_source_rgb(ctx, 0.96, 0.96, 0.96)
    rectangle(ctx, 0, 0, w, h); fill(ctx)

    r_max  = max(r_m1, r_m2)
    bscale = min(w, h) / 10.0
    sm1    = bscale * (r_m1 / r_max)
    sm2    = bscale * (r_m2 / r_max)
    skx, sky = 0.45, 0.20

    sep   = clamp((r_width/r_max)*bscale*3.5, bscale*1.2, w*0.38)
    cy    = h * 0.50
    cx_m1 = w/2 + sep/2
    cx_m2 = w/2 - sep/2

    # Axle
    set_source_rgba(ctx, 0.35,0.35,0.35,0.8); set_line_width(ctx, 4.0)
    move_to(ctx, cx_m2, cy); line_to(ctx, cx_m1, cy); stroke(ctx)
    set_source_rgba(ctx, 0.6,0.6,0.6,0.5); set_line_width(ctx, 1.5)
    move_to(ctx, cx_m2, cy-3); line_to(ctx, cx_m1, cy-3); stroke(ctx)
    for cx_ in (cx_m1, cx_m2)
        set_source_rgba(ctx, 0.3,0.3,0.3,0.9)
        arc(ctx, cx_, cy, 4, 0, 2π); fill(ctx)
    end

    draw_plane(ctx, cx_m1, cy, sm1, skx, sky, "M1",
               init_m1, corr_m1, equiv_m1,
               (0.85,0.55,0.55), (0.85,0.1,0.1), (0.0,0.6,0.0))

    draw_plane(ctx, cx_m2, cy, sm2, skx, sky, "M2",
               init_m2, corr_m2, equiv_m2,
               (0.55,0.55,0.85), (0.1,0.2,0.9), (0.55,0.0,0.75))

    # Legend — horizontal strip along the bottom
    select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_BOLD)
    set_font_size(ctx, 14)
    items = [
        ((0.85,0.55,0.55), :square,  "M1 Initial"),
        ((0.85,0.1,0.1),   :square,  "M1 Corrected"),
        ((0.0,0.6,0.0),    :diamond, "M1 Equiv"),
        ((0.55,0.55,0.85), :square,  "M2 Initial"),
        ((0.1,0.2,0.9),    :square,  "M2 Corrected"),
        ((0.55,0.0,0.75),  :diamond, "M2 Equiv"),
    ]
    n_items = length(items)
    col_w   = w / n_items
    ly      = h - 16.0
    for (i, (color, shape, lbl)) in enumerate(items)
        lx = (i - 0.5) * col_w
        set_source_rgb(ctx, color...)
        if shape == :square
            rectangle(ctx, lx-7, ly-7, 14, 14); fill(ctx)
        else
            move_to(ctx, lx, ly-10); line_to(ctx, lx+7, ly)
            line_to(ctx, lx, ly+10); line_to(ctx, lx-7, ly)
            close_path(ctx); fill(ctx)
        end
        set_source_rgb(ctx, 0.1, 0.1, 0.1)
        move_to(ctx, lx+11, ly+5); show_text(ctx, lbl)
    end
end

# ============================================================================
# MAIN
# ============================================================================

function main()
    csv_file = "balancing_results_" * Dates.format(now(), "yyyy-mm-dd_HH-MM-SS") * ".csv"
    recorded_rows = []

    init_m1  = Ref(0.0+0.0im);  init_m2  = Ref(0.0+0.0im)
    corr_m1  = Ref(0.0+0.0im);  corr_m2  = Ref(0.0+0.0im)
    equiv_m1 = Ref(0.0+0.0im);  equiv_m2 = Ref(0.0+0.0im)

    win  = GtkWindow("Dynamic Wheel Balancing", 1400, 660)
    hbox = GtkBox(:h)
    push!(win, hbox)

    # ── Left panel ────────────────────────────────────────────────────────────
    vbox = GtkBox(:v)
    set_gtk_property!(vbox, :spacing, 3)
    for p in (:margin_start,:margin_end,:margin_top,:margin_bottom)
        set_gtk_property!(vbox, p, 8)
    end
    push!(hbox, vbox)

    function lbl_entry(box, text, default="0.0")
        l = GtkLabel(text); set_gtk_property!(l, :xalign, 0.0); push!(box, l)
        e = GtkEntry()
        set_gtk_property!(e, :text, default)
        set_gtk_property!(e, :height_request, 24)
        push!(box, e); e
    end

    function section(box, text)
        l = GtkLabel(""); GAccessor.markup(l, "<b>$text</b>")
        set_gtk_property!(l, :xalign, 0.0); push!(box, l)
    end

    # Units
    section(vbox, "Units:")
    combo_units = GtkComboBoxText()
    push!(combo_units, "oz-in"); push!(combo_units, "g-cm")
    set_gtk_property!(combo_units, :active, 0)
    push!(vbox, combo_units)

    # Geometry
    section(vbox, "Wheel Geometry:")
    entry_r_m1    = lbl_entry(vbox, "M1 Radius:", "17.5")
    entry_r_m2    = lbl_entry(vbox, "M2 Radius:", "16.5")
    entry_r_width = lbl_entry(vbox, "Wheel Width:", "8.5")
    lbl_ratio = GtkLabel("Ratio M2/M1: 0.943")
    set_gtk_property!(lbl_ratio, :xalign, 0.0)
    push!(vbox, lbl_ratio)

    # Initial masses
    section(vbox, "Initial Masses:")
    entry_im1_mass  = lbl_entry(vbox, "M1 Mass:")
    entry_im1_angle = lbl_entry(vbox, "M1 Angle (°):")
    entry_im2_mass  = lbl_entry(vbox, "M2 Mass:")
    entry_im2_angle = lbl_entry(vbox, "M2 Angle (°):")

    # Corrected masses
    section(vbox, "Corrected Masses:")
    entry_cm1_mass  = lbl_entry(vbox, "M1 Mass:")
    entry_cm1_angle = lbl_entry(vbox, "M1 Angle (°):")
    entry_cm2_mass  = lbl_entry(vbox, "M2 Mass:")
    entry_cm2_angle = lbl_entry(vbox, "M2 Angle (°):")

    btn_update = GtkButton("Update Plot & Record")
    btn_export = GtkButton("Export to CSV")
    btn_clear  = GtkButton("Clear")
    for b in (btn_update, btn_export, btn_clear); push!(vbox, b); end

    # ── Canvas ────────────────────────────────────────────────────────────────
    canvas = GtkCanvas()
    set_gtk_property!(canvas, :expand, true)
    push!(hbox, canvas)

    # ── Right panel ───────────────────────────────────────────────────────────
    vbox_r = GtkBox(:v)
    set_gtk_property!(vbox_r, :spacing, 3)
    for p in (:margin_start,:margin_end,:margin_top,:margin_bottom)
        set_gtk_property!(vbox_r, p, 8)
    end

    function right_section(text)
        l = GtkLabel(""); GAccessor.markup(l, "<b>$text</b>")
        set_gtk_property!(l, :xalign, 0.0); push!(vbox_r, l)
    end

    function right_label(text="—")
        l = GtkLabel(text); set_gtk_property!(l, :xalign, 0.0)
        push!(vbox_r, l); l
    end

    right_section("Equivalent Masses:")
    lbl_m1_equiv = right_label("M1: —")
    lbl_m2_equiv = right_label("M2: —")

    right_section("Initial Moments:")
    lbl_init_static  = right_label("Static:    —")
    lbl_init_couple1 = right_label("Couple M1: —")
    lbl_init_couple2 = right_label("Couple M2: —")

    right_section("Corrected Moments:")
    lbl_corr_static  = right_label("Static:    —")
    lbl_corr_couple1 = right_label("Couple M1: —")
    lbl_corr_couple2 = right_label("Couple M2: —")

    push!(hbox, vbox_r)

    # ── Helpers ───────────────────────────────────────────────────────────────

    function get_units()
        get_gtk_property(combo_units, :active, Int) == 0 ?
            ("oz·in", "oz·in²") : ("g·cm", "g·cm²")
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

    function compute_moments(z1, z2)
        r_m1, r_m2, r_w = get_radii()
        z_static = z1*r_m1 + z2*r_m2
        d = r_w / 2.0
        z_c1 =  z1*r_m1*d;  z_c2 = -z2*r_m2*d
        return (complex_to_mass(z_static), complex_to_angle(z_static),
                complex_to_mass(z_c1),    complex_to_angle(z_c1),
                complex_to_mass(z_c2),    complex_to_angle(z_c2))
    end

    function fmt_moment(lbl_s, lbl_c1, lbl_c2, z1, z2, su, cu)
        s, sa, c1, c1a, c2, c2a = compute_moments(z1, z2)
        set_gtk_property!(lbl_s,  :label, @sprintf("Static:    %.3f %s @ %.1f°", s,  su, sa))
        set_gtk_property!(lbl_c1, :label, @sprintf("Couple M1: %.3f %s @ %.1f°", c1, cu, c1a))
        set_gtk_property!(lbl_c2, :label, @sprintf("Couple M2: %.3f %s @ %.1f°", c2, cu, c2a))
        return s, sa, c1, c1a, c2, c2a
    end

    function update_displays()
        r_m1, r_m2, _ = get_radii()
        su, cu = get_units()
        set_gtk_property!(lbl_ratio, :label, @sprintf("Ratio M2/M1: %.3f", r_m2/r_m1))
        m1e = complex_to_mass(equiv_m1[]); m1a = complex_to_angle(equiv_m1[])
        m2e = complex_to_mass(equiv_m2[]); m2a = complex_to_angle(equiv_m2[])
        set_gtk_property!(lbl_m1_equiv, :label, @sprintf("M1: %.3f @ %.1f°", m1e, m1a))
        set_gtk_property!(lbl_m2_equiv, :label, @sprintf("M2: %.3f @ %.1f°", m2e, m2a))
        fmt_moment(lbl_init_static, lbl_init_couple1, lbl_init_couple2,
                   init_m1[], init_m2[], su, cu)
        fmt_moment(lbl_corr_static, lbl_corr_couple1, lbl_corr_couple2,
                   equiv_m1[], equiv_m2[], su, cu)
    end

    @guarded draw(canvas) do widget
        try
            r_m1, r_m2, r_w = get_radii()
            draw_wheel(widget, init_m1[], init_m2[], corr_m1[], corr_m2[],
                       equiv_m1[], equiv_m2[], r_m1, r_m2, r_w)
        catch e
            println("ERROR: $e"); println(stacktrace(catch_backtrace()))
        end
    end

    for entry in (entry_r_m1, entry_r_m2, entry_r_width)
        signal_connect(entry, "changed") do _; update_displays(); draw(canvas); end
    end
    signal_connect(combo_units, "changed") do _; update_displays(); end

    # ── Update callback ───────────────────────────────────────────────────────
    signal_connect(btn_update, "clicked") do widget
        try
            im1_m = parse(Float64, get_gtk_property(entry_im1_mass,  :text, String))
            im1_a = parse(Float64, get_gtk_property(entry_im1_angle, :text, String))
            im2_m = parse(Float64, get_gtk_property(entry_im2_mass,  :text, String))
            im2_a = parse(Float64, get_gtk_property(entry_im2_angle, :text, String))
            cm1_m = parse(Float64, get_gtk_property(entry_cm1_mass,  :text, String))
            cm1_a = parse(Float64, get_gtk_property(entry_cm1_angle, :text, String))
            cm2_m = parse(Float64, get_gtk_property(entry_cm2_mass,  :text, String))
            cm2_a = parse(Float64, get_gtk_property(entry_cm2_angle, :text, String))

            init_m1[]  = mass_angle_to_complex(im1_m, im1_a)
            init_m2[]  = mass_angle_to_complex(im2_m, im2_a)
            corr_m1[]  = mass_angle_to_complex(cm1_m, cm1_a)
            corr_m2[]  = mass_angle_to_complex(cm2_m, cm2_a)
            equiv_m1[] = init_m1[] + corr_m1[]
            equiv_m2[] = init_m2[] + corr_m2[]

            update_displays()
            draw(canvas)

            su, cu = get_units()
            i_s, i_sa, i_c1, i_c1a, i_c2, i_c2a =
                compute_moments(init_m1[], init_m2[])
            c_s, c_sa, c_c1, c_c1a, c_c2, c_c2a =
                compute_moments(equiv_m1[], equiv_m2[])

            push!(recorded_rows, (desc="Initial",
                m1_mass=im1_m, m1_angle=im1_a, m2_mass=im2_m, m2_angle=im2_a,
                static_moment=i_s,  static_angle=i_sa,
                couple_m1=i_c1, couple_m1_angle=i_c1a,
                couple_m2=i_c2, couple_m2_angle=i_c2a))
            push!(recorded_rows, (desc="Corrected",
                m1_mass=cm1_m, m1_angle=cm1_a, m2_mass=cm2_m, m2_angle=cm2_a,
                static_moment=c_s,  static_angle=c_sa,
                couple_m1=c_c1, couple_m1_angle=c_c1a,
                couple_m2=c_c2, couple_m2_angle=c_c2a))

            println("✓ Updated")
        catch e
            println("Error: $e"); println(stacktrace(catch_backtrace()))
        end
    end

    signal_connect(btn_export, "clicked") do widget
        isempty(recorded_rows) && (println("⚠ Nothing recorded."); return)
        export_to_csv(csv_file, recorded_rows)
    end

    signal_connect(btn_clear, "clicked") do widget
        empty!(recorded_rows)
        for r in (init_m1, init_m2, corr_m1, corr_m2, equiv_m1, equiv_m2)
            r[] = 0.0+0.0im
        end
        for l in (lbl_m1_equiv, lbl_m2_equiv,
                  lbl_init_static, lbl_init_couple1, lbl_init_couple2,
                  lbl_corr_static, lbl_corr_couple1, lbl_corr_couple2)
            set_gtk_property!(l, :label, replace(get_gtk_property(l, :label, String),
                                                  r"[0-9e.+\-@°].*" => "—"))
        end
        draw(canvas); println("✓ Cleared")
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