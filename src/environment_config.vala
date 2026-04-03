/* environment_config.vala - Read/write ~/.config/labwc/environment */

public class EnvironmentConfig : Object {
    public string environment_path { get; private set; }

    private string[] lines = {};

    public EnvironmentConfig() {
        string? xdg_config_home = Environment.get_variable("XDG_CONFIG_HOME");
        string config_base = (xdg_config_home != null && xdg_config_home.strip() != "")
            ? xdg_config_home.strip()
            : Path.build_filename(Environment.get_home_dir(), ".config");
        environment_path = Path.build_filename(config_base, "labwc", "environment");
    }

    private bool try_parse_assignment(string line, out bool commented, out string key, out string value) {
        commented = false;
        key = "";
        value = "";

        try {
            var regex = new Regex("^\\s*(#\\s*)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$");
            MatchInfo mi;
            if (!regex.match(line, 0, out mi) || !mi.matches()) {
                return false;
            }
            commented = mi.fetch(1) != null && mi.fetch(1) != "";
            key = mi.fetch(2).strip();
            value = mi.fetch(3).strip();
            return true;
        } catch (Error e) {
            return false;
        }
    }

    private string[] normalize_tokens(string raw) {
        string[] out = {};
        foreach (string token in raw.split(",")) {
            string t = token.strip();
            if (t == "") {
                continue;
            }
            bool dup = false;
            for (int i = 0; i < out.length; i++) {
                if (out[i] == t) {
                    dup = true;
                    break;
                }
            }
            if (!dup) {
                out += t;
            }
        }
        return out;
    }

    private bool key_in_list(string[] keys, string key) {
        for (int i = 0; i < keys.length; i++) {
            if (keys[i] == key) {
                return true;
            }
        }
        return false;
    }

    public string normalize_csv_value(string raw) {
        string[] tokens = normalize_tokens(raw);
        return string.joinv(",", tokens);
    }

    public bool load() {
        if (!FileUtils.test(environment_path, FileTest.EXISTS)) {
            lines = DEFAULT_ENVIRONMENT_TEMPLATE.split("\n");
            return true;
        }

        try {
            string content;
            FileUtils.get_contents(environment_path, out content);
            lines = content.split("\n");
            return true;
        } catch (Error e) {
            lines = DEFAULT_ENVIRONMENT_TEMPLATE.split("\n");
            return false;
        }
    }

    public bool save() {
        try {
            string? parent = Path.get_dirname(environment_path);
            if (parent != null && parent != "") {
                DirUtils.create_with_parents(parent, 0755);
            }
            string content = string.joinv("\n", lines);
            if (!content.has_suffix("\n")) {
                content += "\n";
            }
            FileUtils.set_contents(environment_path, content);
            return true;
        } catch (Error e) {
            return false;
        }
    }

    public string render_content() {
        string content = string.joinv("\n", lines);
        if (content != "" && !content.has_suffix("\n")) {
            content += "\n";
        }
        return content;
    }

    public string get_value(string key) {
        for (int i = 0; i < lines.length; i++) {
            bool commented = false;
            string parsed_key = "";
            string value = "";
            if (!try_parse_assignment(lines[i], out commented, out parsed_key, out value)) {
                continue;
            }
            if (!commented && parsed_key == key) {
                return value;
            }
        }
        return "";
    }

    public void set_value(string key, string value) {
        int commented_index = -1;
        string stripped = value.strip();
        for (int i = 0; i < lines.length; i++) {
            bool commented = false;
            string parsed_key = "";
            string current = "";
            if (!try_parse_assignment(lines[i], out commented, out parsed_key, out current)) {
                continue;
            }
            if (parsed_key != key) {
                continue;
            }
            if (!commented) {
                lines[i] = key + "=" + stripped;
                return;
            }
            if (commented_index < 0) {
                commented_index = i;
            }
        }

        if (commented_index >= 0) {
            lines[commented_index] = key + "=" + stripped;
            return;
        }

        if (lines.length > 0 && lines[lines.length - 1].strip() != "") {
            lines += "";
        }
        lines += key + "=" + stripped;
    }

    public void clear_value(string key) {
        for (int i = 0; i < lines.length; i++) {
            bool commented = false;
            string parsed_key = "";
            string value = "";
            if (!try_parse_assignment(lines[i], out commented, out parsed_key, out value)) {
                continue;
            }
            if (!commented && parsed_key == key) {
                lines[i] = "# " + key + "=" + value;
                return;
            }
        }
    }

    public void set_or_clear(string key, string value) {
        string stripped = value.strip();
        if (stripped == "") {
            clear_value(key);
            return;
        }
        set_value(key, stripped);
    }

    public string export_unmanaged_assignments(string[] managed_keys) {
        string[] result = {};
        for (int i = 0; i < lines.length; i++) {
            bool commented = false;
            string parsed_key = "";
            string value = "";
            if (!try_parse_assignment(lines[i], out commented, out parsed_key, out value)) {
                continue;
            }
            if (commented || key_in_list(managed_keys, parsed_key)) {
                continue;
            }
            result += parsed_key + "=" + value;
        }
        return string.joinv("\n", result);
    }

    public void apply_unmanaged_assignments(string[] managed_keys, string text) {
        string[] kept = {};
        for (int i = 0; i < lines.length; i++) {
            bool commented = false;
            string parsed_key = "";
            string value = "";
            if (!try_parse_assignment(lines[i], out commented, out parsed_key, out value)) {
                kept += lines[i];
                continue;
            }
            if (commented || key_in_list(managed_keys, parsed_key)) {
                kept += lines[i];
            }
        }

        string[] incoming = {};
        foreach (string raw_line in text.split("\n")) {
            string line = raw_line.strip();
            if (line == "") {
                continue;
            }
            bool commented = false;
            string parsed_key = "";
            string value = "";
            if (!try_parse_assignment(line, out commented, out parsed_key, out value)) {
                continue;
            }
            if (commented || key_in_list(managed_keys, parsed_key)) {
                continue;
            }
            incoming += parsed_key + "=" + value;
        }

        if (incoming.length > 0) {
            if (kept.length > 0 && kept[kept.length - 1].strip() != "") {
                kept += "";
            }
            foreach (string line in incoming) {
                kept += line;
            }
        }

        lines = kept;
    }

    private const string DEFAULT_ENVIRONMENT_TEMPLATE =
        "##\n" +
        "## Example ~/.config/labwc/environment file.\n" +
        "## Uncomment lines starting with one '#' to suit your needs.\n" +
        "##\n" +
        "\n" +
        "## Keyboard layout options\n" +
        "# XKB_DEFAULT_LAYOUT=se\n" +
        "# XKB_DEFAULT_LAYOUT=se,us(intl)\n" +
        "# XKB_DEFAULT_OPTIONS=grp:alt_shift_toggle\n" +
        "\n" +
        "## Cursor theme and size\n" +
        "# XCURSOR_THEME=breeze_cursors\n" +
        "# XCURSOR_SIZE=24\n" +
        "\n" +
        "## Hardware cursor fallback\n" +
        "# WLR_NO_HARDWARE_CURSORS=1\n" +
        "\n" +
        "## Java compatibility\n" +
        "# _JAVA_AWT_WM_NONREPARENTING=0\n" +
        "\n" +
        "## Desktop portal and fallback output\n" +
        "# XDG_CURRENT_DESKTOP=labwc:wlroots\n" +
        "# LABWC_FALLBACK_OUTPUT=NOOP-fallback\n";
}
