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

private string fixture_rc() {
    return "<labwc_config>\n" +
        "  <theme>\n" +
        "    <name>Greybird</name>\n" +
        "    <showTitle>yes</showTitle>\n" +
        "    <titleLayout>NLIMC</titleLayout>\n" +
        "  </theme>\n" +
        "</labwc_config>\n";
}

public static int main(string[] args) {
    string home = Environment.get_home_dir();
    string config_dir = Path.build_filename(home, ".config", "labwc");
    DirUtils.create_with_parents(config_dir, 0755);
    string rc_path = Path.build_filename(config_dir, "rc.xml");

    try {
        FileUtils.set_contents(rc_path, fixture_rc());
    } catch (Error e) {
        stderr.printf("FAIL: cannot write fixture rc.xml: %s\n", e.message);
        return 1;
    }

    var cfg = new Config();
    check_true(cfg.load(), "load layout fixture");
    cfg.set_title_layout("NIMC");
    cfg.set_show_title(false);
    check_true(cfg.save(), "save layout fixture");

    string xml = read_file_or_empty(rc_path);
    check_true(xml.index_of("<titleLayout>") < 0, "legacy titleLayout removed");
    check_true(xml.index_of("<showTitle>") < 0 || xml.index_of("<titlebar>") >= 0, "legacy showTitle migrated to titlebar section");
    check_true(xml.index_of("<layout>icon:iconify,max,close</layout>") >= 0, "titlebar layout stored in long form");
    check_true(xml.index_of("<showTitle>no</showTitle>") >= 0, "showTitle persisted under latest schema");

    if (failures == 0) {
        stdout.printf("PASS: config layout logic\n");
        return 0;
    }

    stderr.printf("FAILED: %d checks\n", failures);
    return 1;
}
