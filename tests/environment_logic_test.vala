using GLib;

private int failures = 0;

private void check_true(bool condition, string message) {
    if (!condition) {
        stderr.printf("FAIL: %s\n", message);
        failures++;
    }
}

private void check_eq(string actual, string expected, string message) {
    if (actual != expected) {
        stderr.printf("FAIL: %s (actual='%s', expected='%s')\n", message, actual, expected);
        failures++;
    }
}

private string read_file_or_empty(string path) {
    try {
        string content = "";
        if (FileUtils.get_contents(path, out content)) {
            return content;
        }
    } catch (Error e) {
    }
    return "";
}

private void test_xkb_normalization(EnvironmentConfig cfg) {
    check_eq(
        cfg.normalize_csv_value(" grp:alt_shift_toggle, caps:escape,grp:alt_shift_toggle ,compose:ralt "),
        "grp:alt_shift_toggle,caps:escape,compose:ralt",
        "normalize_csv_value removes duplicates and trims spaces"
    );
}

private void test_unmanaged_roundtrip(EnvironmentConfig cfg) {
    string env_path = cfg.environment_path;
    string fixture =
        "# keep comments\n" +
        "XKB_DEFAULT_LAYOUT=us,ru\n" +
        "MOZ_ENABLE_WAYLAND=1\n" +
        "QT_QPA_PLATFORM=wayland\n" +
        "SDL_VIDEODRIVER=wayland\n" +
        "# XDG_CURRENT_DESKTOP=labwc:wlroots\n";
    try {
        FileUtils.set_contents(env_path, fixture);
    } catch (Error e) {
        check_true(false, "write environment fixture: " + e.message);
        return;
    }

    check_true(cfg.load(), "load environment fixture");

    string[] managed = {
        "XKB_DEFAULT_LAYOUT",
        "XKB_DEFAULT_OPTIONS",
        "MOZ_ENABLE_WAYLAND",
        "XDG_CURRENT_DESKTOP"
    };

    string unmanaged = cfg.export_unmanaged_assignments(managed);
    check_eq(unmanaged, "QT_QPA_PLATFORM=wayland\nSDL_VIDEODRIVER=wayland", "export_unmanaged_assignments exports only unmanaged active lines");

    cfg.apply_unmanaged_assignments(managed, "QT_QPA_PLATFORM=wayland\nWLR_DRM_DEVICES=/dev/dri/card0\n");
    check_true(cfg.save(), "save unmanaged merge result");

    string merged = read_file_or_empty(env_path);
    check_true(merged.index_of("XKB_DEFAULT_LAYOUT=us,ru") >= 0, "managed key kept in file");
    check_true(merged.index_of("MOZ_ENABLE_WAYLAND=1") >= 0, "managed key value preserved");
    check_true(merged.index_of("QT_QPA_PLATFORM=wayland") >= 0, "existing unmanaged key kept");
    check_true(merged.index_of("WLR_DRM_DEVICES=/dev/dri/card0") >= 0, "new unmanaged key added");
    check_true(merged.index_of("SDL_VIDEODRIVER=wayland") < 0, "removed unmanaged key dropped");
}

public static int main(string[] args) {
    string home = Environment.get_home_dir();
    string config_dir = Path.build_filename(home, ".config", "labwc");
    DirUtils.create_with_parents(config_dir, 0755);

    var cfg = new EnvironmentConfig();

    test_xkb_normalization(cfg);
    test_unmanaged_roundtrip(cfg);

    if (failures == 0) {
        stdout.printf("PASS: environment logic\n");
        return 0;
    }

    stderr.printf("FAILED: %d checks\n", failures);
    return 1;
}
