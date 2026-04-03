using GLib;

private int failures = 0;

private void check_true(bool condition, string message) {
    if (!condition) {
        stderr.printf("FAIL: %s\n", message);
        failures++;
    }
}

private void check_eq_string(string actual, string expected, string message) {
    if (actual != expected) {
        stderr.printf("FAIL: %s (actual='%s', expected='%s')\n", message, actual, expected);
        failures++;
    }
}

private void check_eq_int(int actual, int expected, string message) {
    if (actual != expected) {
        stderr.printf("FAIL: %s (actual=%d, expected=%d)\n", message, actual, expected);
        failures++;
    }
}

private string read_file_or_empty(string path) {
    string out = "";
    try {
        FileUtils.get_contents(path, out out);
    } catch (Error e) {
    }
    return out;
}

private string build_fixture_rc() {
    return "<labwc_config>\n" +
        "  <theme>\n" +
        "    <name>Greybird</name>\n" +
        "    <cornerRadius>4</cornerRadius>\n" +
        "    <keepBorder>yes</keepBorder>\n" +
        "    <showTitle>yes</showTitle>\n" +
        "    <titleLayout>NLIMC</titleLayout>\n" +
        "    <maximizedDecoration>titlebar</maximizedDecoration>\n" +
        "    <dropShadows>yes</dropShadows>\n" +
        "    <dropShadowsOnTiled>no</dropShadowsOnTiled>\n" +
        "    <font place=\"ActiveWindow\"><name>sans</name><size>10</size><slant>normal</slant><weight>normal</weight></font>\n" +
        "    <font place=\"InactiveWindow\"><name>sans</name><size>10</size><slant>normal</slant><weight>normal</weight></font>\n" +
        "    <font place=\"MenuHeader\"><name>sans</name><size>10</size><slant>normal</slant><weight>normal</weight></font>\n" +
        "    <font place=\"MenuItem\"><name>sans</name><size>10</size><slant>normal</slant><weight>normal</weight></font>\n" +
        "    <font place=\"OnScreenDisplay\"><name>sans</name><size>10</size><slant>normal</slant><weight>normal</weight></font>\n" +
        "  </theme>\n" +
        "  <focus>\n" +
        "    <followMouse>no</followMouse>\n" +
        "    <followMouseRequiresMovement>no</followMouseRequiresMovement>\n" +
        "    <raiseOnFocus>no</raiseOnFocus>\n" +
        "  </focus>\n" +
        "  <placement>\n" +
        "    <policy>center</policy>\n" +
        "  </placement>\n" +
        "  <resize>\n" +
        "    <popupShow>Never</popupShow>\n" +
        "    <drawContents>no</drawContents>\n" +
        "    <cornerRange>8</cornerRange>\n" +
        "    <minimumArea>16</minimumArea>\n" +
        "  </resize>\n" +
        "  <osd show=\"yes\" style=\"thumbnail\" />\n" +
        "  <!-- Workspaces example from docs:\n" +
        "  <desktops number=\"4\">\n" +
        "    <names><name>Workspace 1</name></names>\n" +
        "  </desktops>\n" +
        "  -->\n" +
        "  <desktops>\n" +
        "    <popupTime>500</popupTime>\n" +
        "    <names><name>D1</name><name>D2</name></names>\n" +
        "  </desktops>\n" +
        "  <!-- margin top=\"0\" bottom=\"0\" left=\"0\" right=\"0\" -->\n" +
        "  <margin top=\"0\" bottom=\"0\" left=\"0\" right=\"0\" />\n" +
        "</labwc_config>\n";
}

private void run_matrix(Config cfg, string rc_path) {
    cfg.set_theme_name("Onyx");
    cfg.set_corner_radius(7);
    cfg.set_keep_border(false);
    cfg.set_show_title(false);
    cfg.set_title_layout("NIMC");
    cfg.set_maximized_decoration(false);
    cfg.set_drop_shadows(true);
    cfg.set_drop_shadows_on_tiled(true);

    cfg.set_focus_follow_mouse(true);
    cfg.set_focus_follow_mouse_requires_movement(true);
    cfg.set_focus_delay(120);
    cfg.set_focus_raise_on_focus(true);

    cfg.set_placement_policy("automatic");
    cfg.set_placement_monitor("Active");
    cfg.set_placement_cascade_offset(12, 34);

    cfg.set_resize_popup_show_mode("Always");
    cfg.set_resize_draw_contents(true);
    cfg.set_resize_corner_range(23);
    cfg.set_resize_minimum_area(77);

    cfg.set_window_switcher_show(false);
    cfg.set_window_switcher_style("classic");
    cfg.set_window_switcher_output("current");
    cfg.set_window_switcher_thumbnail_label_format("%T [%n]");

    cfg.set_desktops_popup_time(750);
    cfg.set_desktops_number(3);
    cfg.set_desktops_prefix("Desk");
    cfg.set_desktops_names({"Work A", "Web & Docs", "Chat"});

    cfg.set_margins(3, 4, 5, 6);

    check_true(cfg.save(), "save matrix changes");

    var reload = new Config();
    check_true(reload.load(), "reload after matrix save");

    check_eq_string(reload.get_theme_name(), "Onyx", "theme name");
    check_eq_int(reload.get_corner_radius(), 7, "corner radius");
    check_true(!reload.get_keep_border(), "keep border off");
    check_true(!reload.get_show_title(), "show title off");
    check_eq_string(reload.get_title_layout(), "NIMC", "title layout");
    check_true(!reload.get_maximized_decoration(), "maximized decoration off");
    check_true(reload.get_drop_shadows(), "drop shadows on");
    check_true(reload.get_drop_shadows_on_tiled(), "drop shadows on tiled on");

    check_true(reload.get_focus_follow_mouse(), "focus follows mouse");
    check_true(reload.get_focus_follow_mouse_requires_movement(), "focus requires movement");
    check_eq_int(reload.get_focus_delay(), 120, "focus delay");
    check_true(reload.get_focus_raise_on_focus(), "raise on focus");

    check_eq_string(reload.get_placement_policy(), "automatic", "placement policy");
    check_eq_string(reload.get_placement_monitor(), "Active", "placement monitor");
    check_eq_int(reload.get_placement_cascade_offset_x(), 12, "placement cascade x");
    check_eq_int(reload.get_placement_cascade_offset_y(), 34, "placement cascade y");

    check_eq_string(reload.get_resize_popup_show_mode(), "Always", "resize popup mode");
    check_true(reload.get_resize_draw_contents(), "resize draw contents");
    check_eq_int(reload.get_resize_corner_range(), 23, "resize corner range");
    check_eq_int(reload.get_resize_minimum_area(), 77, "resize minimum area");

    check_true(!reload.get_window_switcher_show(), "osd show off");
    check_eq_string(reload.get_window_switcher_style(), "classic", "osd style");
    check_eq_string(reload.get_window_switcher_output(), "current", "osd output");
    check_eq_string(reload.get_window_switcher_thumbnail_label_format(), "%T [%n]", "osd thumbnail label format");

    check_eq_int(reload.get_desktops_popup_time(), 750, "desktops popup time");
    check_eq_int(reload.get_desktops_number(), 3, "desktops number");
    check_eq_string(reload.get_desktops_prefix(), "Desk", "desktops prefix");
    string[] names = reload.get_desktops_names();
    check_eq_int(names.length, 3, "desktops names count");
    if (names.length >= 3) {
        check_eq_string(names[0], "Work A", "desktop name 1");
        check_eq_string(names[1], "Web & Docs", "desktop name 2");
        check_eq_string(names[2], "Chat", "desktop name 3");
    }

    check_eq_int(reload.get_margin_top(), 3, "margin top");
    check_eq_int(reload.get_margin_bottom(), 4, "margin bottom");
    check_eq_int(reload.get_margin_left(), 5, "margin left");
    check_eq_int(reload.get_margin_right(), 6, "margin right");

    string xml = read_file_or_empty(rc_path);
    check_true(xml.index_of("<names><names>") < 0, "no double names nesting");
    check_true(xml.index_of("/ bottom=") < 0, "no broken margin slash formatting");
    check_true(xml.index_of("<titleLayout><layout>") < 0, "no wrong titleLayout block");
    check_true(xml.index_of("<titleLayout>") < 0, "no legacy titleLayout tag after save");
    check_true(xml.index_of("<titlebar>") >= 0, "titlebar block present after save");
    check_true(xml.index_of("<layout>icon:iconify,max,close</layout>") >= 0, "titlebar layout saved in latest schema");
    check_true(xml.index_of("Workspace 1") >= 0, "comment block preserved");
}

private void run_noop_save_check(string rc_path) {
    string before = read_file_or_empty(rc_path);
    var cfg = new Config();
    check_true(cfg.load(), "load for no-op save check");
    check_true(cfg.save(), "save with no changes");
    string after = read_file_or_empty(rc_path);
    check_true(before == after, "no-op save keeps file unchanged");
}

public static int main(string[] args) {
    string home = Environment.get_home_dir();
    string config_dir = Path.build_filename(home, ".config", "labwc");
    DirUtils.create_with_parents(config_dir, 0755);
    string rc_path = Path.build_filename(config_dir, "rc.xml");

    try {
        FileUtils.set_contents(rc_path, build_fixture_rc());
    } catch (Error e) {
        stderr.printf("FAIL: cannot write fixture rc.xml: %s\n", e.message);
        return 1;
    }

    var cfg = new Config();
    check_true(cfg.load(), "load fixture rc.xml");
    run_matrix(cfg, rc_path);
    run_noop_save_check(rc_path);

    if (failures == 0) {
        stdout.printf("PASS: config matrix\n");
        return 0;
    }

    stderr.printf("FAILED: %d checks\n", failures);
    return 1;
}
