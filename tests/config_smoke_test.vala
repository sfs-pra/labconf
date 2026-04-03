using GLib;

private int failures = 0;

private void check_true(bool condition, string message) {
    if (!condition) {
        stderr.printf("FAIL: %s\n", message);
        failures++;
    }
}

private string read_file_or_empty(string path) {
    try {
        string out = "";
        if (FileUtils.get_contents(path, out out)) {
            return out;
        }
    } catch (Error e) {
    }
    return "";
}

private void exercise_getters(Config cfg) {
    cfg.get_theme_name();
    cfg.get_corner_radius();
    cfg.get_keep_border();
    cfg.get_show_title();
    cfg.get_title_layout();
    cfg.get_maximized_decoration();
    cfg.get_drop_shadows();
    cfg.get_drop_shadows_on_tiled();

    cfg.get_focus_follow_mouse();
    cfg.get_focus_follow_mouse_requires_movement();
    cfg.get_focus_delay();
    cfg.get_focus_raise_on_focus();

    cfg.get_mouse_double_click_time();

    cfg.get_placement_policy();
    cfg.get_placement_monitor();
    cfg.get_placement_cascade_offset_x();
    cfg.get_placement_cascade_offset_y();

    cfg.get_resize_popup_show_mode();
    cfg.get_resize_draw_contents();
    cfg.get_resize_corner_range();
    cfg.get_resize_minimum_area();

    cfg.get_window_switcher_show();
    cfg.get_window_switcher_style();
    cfg.get_window_switcher_output();
    cfg.get_window_switcher_thumbnail_label_format();

    cfg.get_desktops_popup_time();
    cfg.get_desktops_number();
    cfg.get_desktops_prefix();
    cfg.get_desktops_names();

    cfg.get_margin_top();
    cfg.get_margin_bottom();
    cfg.get_margin_left();
    cfg.get_margin_right();
}

private void run_fixture(string name, string xml, string rc_path) {
    try {
        FileUtils.set_contents(rc_path, xml);
    } catch (Error e) {
        check_true(false, "write fixture " + name + ": " + e.message);
        return;
    }

    var cfg = new Config();
    check_true(cfg.load(), "load fixture: " + name);
    exercise_getters(cfg);
    check_true(cfg.save(), "save fixture: " + name);

    var reload = new Config();
    check_true(reload.load(), "reload fixture: " + name);
    exercise_getters(reload);

    string saved = read_file_or_empty(rc_path);
    check_true(saved.index_of("<labwc_config") >= 0, "fixture keeps labwc_config root: " + name);
    check_true(saved.index_of("<titleLayout><layout>") < 0, "fixture avoids invalid titleLayout nesting: " + name);
}

private string fixture_latest_schema() {
    return "<labwc_config>\n" +
        "  <theme>\n" +
        "    <name>Arc-Dark</name>\n" +
        "    <cornerRadius>8</cornerRadius>\n" +
        "    <keepBorder>yes</keepBorder>\n" +
        "    <titlebar>\n" +
        "      <showTitle>yes</showTitle>\n" +
        "      <layout>icon:iconify,max,close</layout>\n" +
        "    </titlebar>\n" +
        "    <dropShadows>yes</dropShadows>\n" +
        "    <dropShadowsOnTiled>no</dropShadowsOnTiled>\n" +
        "  </theme>\n" +
        "  <focus><followMouse>yes</followMouse><raiseOnFocus>yes</raiseOnFocus></focus>\n" +
        "  <mouse><doubleClickTime>500</doubleClickTime></mouse>\n" +
        "  <placement><policy>cascade</policy><monitor>Active</monitor><cascadeOffset x=\"14\" y=\"20\" /></placement>\n" +
        "  <resize><popupShow>Always</popupShow><drawContents>yes</drawContents><cornerRange>12</cornerRange><minimumArea>48</minimumArea></resize>\n" +
        "  <osd>\n" +
        "    <windowSwitcher show=\"yes\" style=\"thumbnail\" output=\"current\">\n" +
        "      <thumbnailLabelFormat>%T [%n]</thumbnailLabelFormat>\n" +
        "    </windowSwitcher>\n" +
        "  </osd>\n" +
        "  <desktops><number>3</number><prefix>Desk</prefix><popupTime>700</popupTime><names><name>One</name><name>Two</name><name>Three</name></names></desktops>\n" +
        "  <margin top=\"2\" bottom=\"4\" left=\"6\" right=\"8\" />\n" +
        "</labwc_config>\n";
}

private string fixture_legacy_schema() {
    return "<labwc_config>\n" +
        "  <theme>\n" +
        "    <name>Greybird</name>\n" +
        "    <showTitle>yes</showTitle>\n" +
        "    <titleLayout>NLIMC</titleLayout>\n" +
        "    <dropShadows>yes</dropShadows>\n" +
        "  </theme>\n" +
        "  <osd show=\"yes\" style=\"thumbnail\" />\n" +
        "  <desktops>\n" +
        "    <popupTime>500</popupTime>\n" +
        "    <names><name>Workspace 1</name><name>Workspace 2</name></names>\n" +
        "  </desktops>\n" +
        "  <margin top=\"0\" bottom=\"0\" left=\"0\" right=\"0\" />\n" +
        "</labwc_config>\n";
}

private string fixture_minimal_with_comments() {
    return "<labwc_config>\n" +
        "  <!-- minimal fixture used to simulate distro defaults -->\n" +
        "  <theme><name>Default</name></theme>\n" +
        "  <!-- older docs examples kept as comments -->\n" +
        "  <!-- <desktops number=\"4\"><names><name>Workspace 1</name></names></desktops> -->\n" +
        "</labwc_config>\n";
}

public static int main(string[] args) {
    string home = Environment.get_home_dir();
    string config_dir = Path.build_filename(home, ".config", "labwc");
    DirUtils.create_with_parents(config_dir, 0755);
    string rc_path = Path.build_filename(config_dir, "rc.xml");

    run_fixture("latest-schema", fixture_latest_schema(), rc_path);
    run_fixture("legacy-schema", fixture_legacy_schema(), rc_path);
    run_fixture("minimal-with-comments", fixture_minimal_with_comments(), rc_path);

    if (failures == 0) {
        stdout.printf("PASS: config smoke fixtures\n");
        return 0;
    }

    stderr.printf("FAILED: %d checks\n", failures);
    return 1;
}
