/* theme_parser.vala - Openbox/labwc theme parser */
public class ThemeConfig : Object {
    public string theme_path { get; private set; }
    public string openbox_dir { get; private set; }

    private string[] entry_keys;
    private string[] entry_values;

    public ThemeConfig(string theme_path, string openbox_dir) {
        this.theme_path = theme_path;
        this.openbox_dir = openbox_dir;
        entry_keys = {};
        entry_values = {};
    }

    public void set_entry(string key, string value) {
        entry_keys += key.down();
        entry_values += value.strip();
    }

    public string get_title_bg(bool active) {
        string state = active ? "active" : "inactive";
        return resolve_color({
            "window.%s.title.bg.color".printf(state),
            "window.*.title.bg.color",
            "*.title.bg.color",
            "window.title.bg.color"
        }, active ? "#e8e8e8" : "#f0f0f0");
    }

    public string get_title_bg_to(bool active) {
        string state = active ? "active" : "inactive";
        return resolve_color({
            "window.%s.title.bg.colorto".printf(state),
            "window.%s.title.bg.color.splitto".printf(state),
            "window.*.title.bg.colorto",
            "window.*.title.bg.color.splitto",
            "*.title.bg.colorto",
            "*.title.bg.color.splitto",
            "window.title.bg.colorto"
        }, get_title_bg(active));
    }

    public string get_title_bg_split_to(bool active) {
        string state = active ? "active" : "inactive";
        return resolve_color({
            "window.%s.title.bg.color.splitto".printf(state),
            "window.*.title.bg.color.splitto",
            "*.title.bg.color.splitto",
            "window.title.bg.color.splitto"
        }, get_title_bg(active));
    }

    public string get_title_bg_to_split_to(bool active) {
        string state = active ? "active" : "inactive";
        return resolve_color({
            "window.%s.title.bg.colorto.splitto".printf(state),
            "window.%s.title.bg.colorTo.splitto".printf(state),
            "window.*.title.bg.colorto.splitto",
            "window.*.title.bg.colorTo.splitto",
            "*.title.bg.colorto.splitto",
            "*.title.bg.colorTo.splitto",
            "window.title.bg.colorto.splitto"
        }, get_title_bg_to(active));
    }

    public string get_title_border(bool active) {
        string state = active ? "active" : "inactive";
        return resolve_color({
            "window.%s.title.bg.border.color".printf(state),
            "window.%s.title.separator.color".printf(state),
            "window.%s.border.color".printf(state),
            "window.*.title.bg.border.color",
            "window.*.title.separator.color",
            "window.*.border.color",
            "*.title.bg.border.color",
            "*.border.color",
            "border.color"
        }, "");
    }

    public string get_window_border(bool active) {
        string state = active ? "active" : "inactive";
        return resolve_color({
            "window.%s.border.color".printf(state),
            "window.%s.client.color".printf(state),
            "window.*.border.color",
            "window.*.client.color",
            "border.color"
        }, "");
    }

    public bool title_is_gradient(bool active) {
        string state = active ? "active" : "inactive";
        return has_mode_token({
            "window.%s.title.bg".printf(state),
            "window.*.title.bg",
            "*.title.bg",
            "window.title.bg"
        }, "gradient");
    }

    public string get_title_bg_mode(bool active) {
        string state = active ? "active" : "inactive";
        return resolve_mode({
            "window.%s.title.bg".printf(state),
            "window.*.title.bg",
            "*.title.bg",
            "window.title.bg"
        });
    }

    public string get_title_gradient_kind(bool active) {
        string mode = get_title_bg_mode(active).down();
        if (!mode.contains("gradient")) {
            return "none";
        }
        if (mode.contains("splitvertical")) {
            return "splitvertical";
        }
        if (mode.contains("vertical")) {
            return "vertical";
        }
        return "none";
    }

    public string get_title_fg(bool active) {
        string state = active ? "active" : "inactive";
        return resolve_color({
            "window.%s.label.text.color".printf(state),
            "window.%s.text.color".printf(state),
            "window.*.label.text.color",
            "window.label.text.color",
            "*.label.text.color"
        }, active ? "#202020" : "#808080");
    }

    public string get_button_bg(bool active, bool is_close, string btn_state) {
        string state = active ? "active" : "inactive";

        if (is_close) {
            string close_color = resolve_color(button_candidates(state, "close", btn_state, "bg"), "");
            if (close_color != "") {
                return close_color;
            }
            if (has_parentrelative(button_bg_mode_candidates(state, "close", btn_state))) {
                return get_title_bg(active);
            }
        }

        string fallback = active ? "#f0f0f0" : "#f8f8f8";
        string normal_color = resolve_color(button_candidates(state, "*", btn_state, "bg"), fallback);
        if (normal_color == fallback && has_parentrelative(button_bg_mode_candidates(state, "*", btn_state))) {
            return get_title_bg(active);
        }
        if (normal_color == "") {
            return get_title_bg(active);
        }
        return normal_color;
    }

    public string get_button_bg_to(bool active, bool is_close, string btn_state) {
        string state = active ? "active" : "inactive";

        if (is_close) {
            string close_color = resolve_color(button_bg_to_candidates(state, "close", btn_state), "");
            if (close_color != "") {
                return close_color;
            }
        }

        string normal_color = resolve_color(button_bg_to_candidates(state, "*", btn_state), "");
        if (normal_color != "") {
            return normal_color;
        }
        return get_button_bg(active, is_close, btn_state);
    }

    public string get_button_border(bool active, bool is_close, string btn_state) {
        string state = active ? "active" : "inactive";

        if (is_close) {
            string close_color = resolve_color(button_border_candidates(state, "close", btn_state), "");
            if (close_color != "") {
                return close_color;
            }
        }

        return resolve_color(button_border_candidates(state, "*", btn_state), "");
    }

    public bool button_is_parentrelative(bool active, bool is_close, string btn_state) {
        string state = active ? "active" : "inactive";
        if (is_close && has_parentrelative(button_bg_mode_candidates(state, "close", btn_state))) {
            return true;
        }
        return has_parentrelative(button_bg_mode_candidates(state, "*", btn_state));
    }

    public bool button_is_gradient(bool active, bool is_close, string btn_state) {
        string state = active ? "active" : "inactive";
        if (is_close && has_mode_token(button_bg_mode_candidates(state, "close", btn_state), "gradient")) {
            return true;
        }
        return has_mode_token(button_bg_mode_candidates(state, "*", btn_state), "gradient");
    }

    public string get_button_fg(bool active, bool is_close, string btn_state) {
        string state = active ? "active" : "inactive";

        if (is_close) {
            string close_color = resolve_color(button_candidates(state, "close", btn_state, "image"), "");
            if (close_color != "") {
                return close_color;
            }
        }

        string fallback = active ? "#404040" : "#808080";
        return resolve_color(button_candidates(state, "*", btn_state, "image"), fallback);
    }

    public int get_button_width() {
        return resolve_int({"window.button.width"}, 18);
    }

    public int get_button_height() {
        return resolve_int({"window.button.height"}, 18);
    }

    public int get_button_spacing() {
        return resolve_int({"window.button.spacing"}, 1);
    }

    private string[] button_candidates(string active_state, string button_name, string button_state, string part) {
        if (button_state == "hover") {
            return {
                "window.%s.button.%s.hover.%s.color".printf(active_state, button_name, part),
                "window.%s.button.%s.toggled.%s.color".printf(active_state, button_name, part),
                "window.%s.button.%s.%s.color".printf(active_state, button_name, part),
                "window.*.button.%s.hover.%s.color".printf(button_name, part),
                "window.*.button.%s.toggled.%s.color".printf(button_name, part),
                "window.*.button.%s.%s.color".printf(button_name, part),
                "window.%s.button.hover.%s.color".printf(active_state, part),
                "window.%s.button.toggled.%s.color".printf(active_state, part),
                "window.%s.button.unpressed.%s.color".printf(active_state, part),
                "window.%s.button.%s.hover.%s.color".printf(active_state, "*", part),
                "window.%s.button.%s.toggled.%s.color".printf(active_state, "*", part),
                "window.%s.button.%s.unpressed.%s.color".printf(active_state, "*", part),
                "window.%s.button.%s.%s.color".printf(active_state, "*", part),
                "window.*.button.%s.hover.%s.color".printf("*", part),
                "window.*.button.%s.toggled.%s.color".printf("*", part),
                "window.*.button.%s.unpressed.%s.color".printf("*", part),
                "window.*.button.%s.%s.color".printf("*", part),
                "window.*.button.%s.color".printf(part),
                "window.%s.button.%s.color".printf(active_state, part)
            };
        }

        if (button_state == "pressed") {
            return {
                "window.%s.button.%s.pressed.%s.color".printf(active_state, button_name, part),
                "window.%s.button.%s.%s.color".printf(active_state, button_name, part),
                "window.*.button.%s.pressed.%s.color".printf(button_name, part),
                "window.*.button.%s.%s.color".printf(button_name, part),
                "window.%s.button.pressed.%s.color".printf(active_state, part),
                "window.%s.button.unpressed.%s.color".printf(active_state, part),
                "window.%s.button.%s.pressed.%s.color".printf(active_state, "*", part),
                "window.%s.button.%s.unpressed.%s.color".printf(active_state, "*", part),
                "window.%s.button.%s.%s.color".printf(active_state, "*", part),
                "window.*.button.%s.pressed.%s.color".printf("*", part),
                "window.*.button.%s.unpressed.%s.color".printf("*", part),
                "window.*.button.%s.%s.color".printf("*", part),
                "window.*.button.%s.color".printf(part),
                "window.%s.button.%s.color".printf(active_state, part)
            };
        }

        if (button_state == "disabled") {
            return {
                "window.%s.button.%s.disabled.%s.color".printf(active_state, button_name, part),
                "window.%s.button.%s.%s.color".printf(active_state, button_name, part),
                "window.*.button.%s.disabled.%s.color".printf(button_name, part),
                "window.*.button.%s.%s.color".printf(button_name, part),
                "window.%s.button.disabled.%s.color".printf(active_state, part),
                "window.%s.button.unpressed.%s.color".printf(active_state, part),
                "window.%s.button.%s.disabled.%s.color".printf(active_state, "*", part),
                "window.%s.button.%s.unpressed.%s.color".printf(active_state, "*", part),
                "window.%s.button.%s.%s.color".printf(active_state, "*", part),
                "window.*.button.%s.disabled.%s.color".printf("*", part),
                "window.*.button.%s.unpressed.%s.color".printf("*", part),
                "window.*.button.%s.%s.color".printf("*", part),
                "window.*.button.%s.color".printf(part),
                "window.%s.button.%s.color".printf(active_state, part)
            };
        }

        return {
            "window.%s.button.%s.unpressed.%s.color".printf(active_state, button_name, part),
            "window.%s.button.%s.%s.color".printf(active_state, button_name, part),
            "window.*.button.%s.unpressed.%s.color".printf(button_name, part),
            "window.*.button.%s.%s.color".printf(button_name, part),
            "window.%s.button.unpressed.%s.color".printf(active_state, part),
            "window.%s.button.%s.unpressed.%s.color".printf(active_state, "*", part),
            "window.%s.button.%s.%s.color".printf(active_state, "*", part),
            "window.*.button.%s.unpressed.%s.color".printf("*", part),
            "window.*.button.%s.%s.color".printf("*", part),
            "window.*.button.%s.color".printf(part),
            "window.%s.button.%s.color".printf(active_state, part)
        };
    }

    private string[] button_bg_mode_candidates(string active_state, string button_name, string button_state) {
        if (button_state == "hover") {
            return {
                "window.%s.button.%s.hover.bg".printf(active_state, button_name),
                "window.%s.button.%s.toggled.bg".printf(active_state, button_name),
                "window.%s.button.%s.bg".printf(active_state, button_name),
                "window.*.button.%s.hover.bg".printf(button_name),
                "window.*.button.%s.toggled.bg".printf(button_name),
                "window.*.button.%s.bg".printf(button_name),
                "window.%s.button.hover.bg".printf(active_state),
                "window.%s.button.toggled.bg".printf(active_state),
                "window.%s.button.unpressed.bg".printf(active_state),
                "window.%s.button.%s.hover.bg".printf(active_state, "*"),
                "window.%s.button.%s.toggled.bg".printf(active_state, "*"),
                "window.%s.button.%s.unpressed.bg".printf(active_state, "*"),
                "window.%s.button.%s.bg".printf(active_state, "*"),
                "window.*.button.%s.hover.bg".printf("*"),
                "window.*.button.%s.toggled.bg".printf("*"),
                "window.*.button.%s.unpressed.bg".printf("*"),
                "window.*.button.%s.bg".printf("*")
            };
        }

        if (button_state == "pressed") {
            return {
                "window.%s.button.%s.pressed.bg".printf(active_state, button_name),
                "window.%s.button.%s.bg".printf(active_state, button_name),
                "window.*.button.%s.pressed.bg".printf(button_name),
                "window.*.button.%s.bg".printf(button_name),
                "window.%s.button.pressed.bg".printf(active_state),
                "window.%s.button.unpressed.bg".printf(active_state),
                "window.%s.button.%s.pressed.bg".printf(active_state, "*"),
                "window.%s.button.%s.unpressed.bg".printf(active_state, "*"),
                "window.%s.button.%s.bg".printf(active_state, "*"),
                "window.*.button.%s.pressed.bg".printf("*"),
                "window.*.button.%s.unpressed.bg".printf("*"),
                "window.*.button.%s.bg".printf("*")
            };
        }

        if (button_state == "disabled") {
            return {
                "window.%s.button.%s.disabled.bg".printf(active_state, button_name),
                "window.%s.button.%s.bg".printf(active_state, button_name),
                "window.*.button.%s.disabled.bg".printf(button_name),
                "window.*.button.%s.bg".printf(button_name),
                "window.%s.button.disabled.bg".printf(active_state),
                "window.%s.button.unpressed.bg".printf(active_state),
                "window.%s.button.%s.disabled.bg".printf(active_state, "*"),
                "window.%s.button.%s.unpressed.bg".printf(active_state, "*"),
                "window.%s.button.%s.bg".printf(active_state, "*"),
                "window.*.button.%s.disabled.bg".printf("*"),
                "window.*.button.%s.unpressed.bg".printf("*"),
                "window.*.button.%s.bg".printf("*")
            };
        }

        return {
            "window.%s.button.%s.unpressed.bg".printf(active_state, button_name),
            "window.%s.button.%s.bg".printf(active_state, button_name),
            "window.*.button.%s.unpressed.bg".printf(button_name),
            "window.*.button.%s.bg".printf(button_name),
            "window.%s.button.unpressed.bg".printf(active_state),
            "window.%s.button.%s.unpressed.bg".printf(active_state, "*"),
            "window.%s.button.%s.bg".printf(active_state, "*"),
            "window.*.button.%s.unpressed.bg".printf("*"),
            "window.*.button.%s.bg".printf("*")
        };
    }

    private string[] button_bg_to_candidates(string active_state, string button_name, string button_state) {
        if (button_state == "hover") {
            return {
                "window.%s.button.%s.hover.bg.colorto".printf(active_state, button_name),
                "window.%s.button.%s.hover.bg.color.splitto".printf(active_state, button_name),
                "window.%s.button.%s.toggled.bg.colorto".printf(active_state, button_name),
                "window.%s.button.%s.bg.colorto".printf(active_state, button_name),
                "window.*.button.%s.hover.bg.colorto".printf(button_name),
                "window.*.button.%s.bg.colorto".printf(button_name),
                "window.%s.button.hover.bg.colorto".printf(active_state),
                "window.%s.button.unpressed.bg.colorto".printf(active_state),
                "window.%s.button.%s.hover.bg.colorto".printf(active_state, "*"),
                "window.%s.button.%s.bg.colorto".printf(active_state, "*"),
                "window.*.button.%s.hover.bg.colorto".printf("*"),
                "window.*.button.%s.bg.colorto".printf("*")
            };
        }

        if (button_state == "pressed") {
            return {
                "window.%s.button.%s.pressed.bg.colorto".printf(active_state, button_name),
                "window.%s.button.%s.pressed.bg.color.splitto".printf(active_state, button_name),
                "window.%s.button.%s.bg.colorto".printf(active_state, button_name),
                "window.*.button.%s.pressed.bg.colorto".printf(button_name),
                "window.*.button.%s.bg.colorto".printf(button_name),
                "window.%s.button.pressed.bg.colorto".printf(active_state),
                "window.%s.button.unpressed.bg.colorto".printf(active_state),
                "window.%s.button.%s.pressed.bg.colorto".printf(active_state, "*"),
                "window.%s.button.%s.bg.colorto".printf(active_state, "*"),
                "window.*.button.%s.pressed.bg.colorto".printf("*"),
                "window.*.button.%s.bg.colorto".printf("*")
            };
        }

        if (button_state == "disabled") {
            return {
                "window.%s.button.%s.disabled.bg.colorto".printf(active_state, button_name),
                "window.%s.button.%s.bg.colorto".printf(active_state, button_name),
                "window.*.button.%s.disabled.bg.colorto".printf(button_name),
                "window.*.button.%s.bg.colorto".printf(button_name),
                "window.%s.button.disabled.bg.colorto".printf(active_state),
                "window.%s.button.unpressed.bg.colorto".printf(active_state),
                "window.%s.button.%s.disabled.bg.colorto".printf(active_state, "*"),
                "window.%s.button.%s.bg.colorto".printf(active_state, "*"),
                "window.*.button.%s.disabled.bg.colorto".printf("*"),
                "window.*.button.%s.bg.colorto".printf("*")
            };
        }

        return {
            "window.%s.button.%s.unpressed.bg.colorto".printf(active_state, button_name),
            "window.%s.button.%s.unpressed.bg.color.splitto".printf(active_state, button_name),
            "window.%s.button.%s.bg.colorto".printf(active_state, button_name),
            "window.*.button.%s.unpressed.bg.colorto".printf(button_name),
            "window.*.button.%s.bg.colorto".printf(button_name),
            "window.%s.button.unpressed.bg.colorto".printf(active_state),
            "window.%s.button.%s.unpressed.bg.colorto".printf(active_state, "*"),
            "window.%s.button.%s.bg.colorto".printf(active_state, "*"),
            "window.*.button.%s.unpressed.bg.colorto".printf("*"),
            "window.*.button.%s.bg.colorto".printf("*")
        };
    }

    private string[] button_border_candidates(string active_state, string button_name, string button_state) {
        if (button_state == "hover") {
            return {
                "window.%s.button.%s.hover.bg.border.color".printf(active_state, button_name),
                "window.%s.button.%s.bg.border.color".printf(active_state, button_name),
                "window.*.button.%s.hover.bg.border.color".printf(button_name),
                "window.*.button.%s.bg.border.color".printf(button_name),
                "window.%s.button.hover.bg.border.color".printf(active_state),
                "window.%s.button.%s.hover.bg.border.color".printf(active_state, "*"),
                "window.%s.button.%s.bg.border.color".printf(active_state, "*"),
                "window.*.button.%s.hover.bg.border.color".printf("*"),
                "window.*.button.%s.bg.border.color".printf("*")
            };
        }

        if (button_state == "pressed") {
            return {
                "window.%s.button.%s.pressed.bg.border.color".printf(active_state, button_name),
                "window.%s.button.%s.bg.border.color".printf(active_state, button_name),
                "window.*.button.%s.pressed.bg.border.color".printf(button_name),
                "window.*.button.%s.bg.border.color".printf(button_name),
                "window.%s.button.pressed.bg.border.color".printf(active_state),
                "window.%s.button.%s.pressed.bg.border.color".printf(active_state, "*"),
                "window.%s.button.%s.bg.border.color".printf(active_state, "*"),
                "window.*.button.%s.pressed.bg.border.color".printf("*"),
                "window.*.button.%s.bg.border.color".printf("*")
            };
        }

        if (button_state == "disabled") {
            return {
                "window.%s.button.%s.disabled.bg.border.color".printf(active_state, button_name),
                "window.%s.button.%s.bg.border.color".printf(active_state, button_name),
                "window.*.button.%s.disabled.bg.border.color".printf(button_name),
                "window.*.button.%s.bg.border.color".printf(button_name),
                "window.%s.button.disabled.bg.border.color".printf(active_state),
                "window.%s.button.%s.disabled.bg.border.color".printf(active_state, "*"),
                "window.%s.button.%s.bg.border.color".printf(active_state, "*"),
                "window.*.button.%s.disabled.bg.border.color".printf("*"),
                "window.*.button.%s.bg.border.color".printf("*")
            };
        }

        return {
            "window.%s.button.%s.unpressed.bg.border.color".printf(active_state, button_name),
            "window.%s.button.%s.bg.border.color".printf(active_state, button_name),
            "window.*.button.%s.unpressed.bg.border.color".printf(button_name),
            "window.*.button.%s.bg.border.color".printf(button_name),
            "window.%s.button.unpressed.bg.border.color".printf(active_state),
            "window.%s.button.%s.unpressed.bg.border.color".printf(active_state, "*"),
            "window.%s.button.%s.bg.border.color".printf(active_state, "*"),
            "window.*.button.%s.unpressed.bg.border.color".printf("*"),
            "window.*.button.%s.bg.border.color".printf("*")
        };
    }

    private bool has_parentrelative(string[] keys) {
        for (int i = 0; i < keys.length; i++) {
            string value = lookup_raw(keys[i]);
            if (value.down().contains("parentrelative")) {
                return true;
            }
        }
        return false;
    }

    private bool has_mode_token(string[] keys, string token) {
        string needle = token.down();
        for (int i = 0; i < keys.length; i++) {
            string value = lookup_raw(keys[i]);
            if (value.down().contains(needle)) {
                return true;
            }
        }
        return false;
    }

    private string resolve_color(string[] keys, string fallback) {
        foreach (string key in keys) {
            string color = lookup_color(key);
            if (color != "") {
                return color;
            }
        }
        return fallback;
    }

    private int resolve_int(string[] keys, int fallback) {
        foreach (string key in keys) {
            string value = lookup_raw(key).strip();
            if (value == "") {
                continue;
            }
            int parsed = 0;
            if (int.try_parse(value, out parsed) && parsed >= 0) {
                return parsed;
            }
        }
        return fallback;
    }

    private string resolve_mode(string[] keys) {
        foreach (string key in keys) {
            string value = lookup_raw(key).strip().down();
            if (value != "") {
                return value;
            }
        }
        return "";
    }

    private string lookup_color(string key) {
        return normalize_color(lookup_raw(key));
    }

    private string lookup_raw(string key) {
        string target = key.down();
        string found = "";

        for (int i = 0; i < entry_keys.length; i++) {
            string pattern = entry_keys[i];
            if (glob_match(pattern, target)) {
                found = entry_values[i];
            }
        }

        return found;
    }

    private static bool glob_match(string pattern, string text) {
        string regex = "^" + Regex.escape_string(pattern).replace("\\*", ".*") + "$";
        return Regex.match_simple(regex, text);
    }

    private static string normalize_color(string value) {
        string text = value.strip();
        if (text == "") {
            return "";
        }

        string[] parts = text.split(" ");
        foreach (string token_raw in parts) {
            string token = token_raw.strip();
            if (token == "") {
                continue;
            }
            if (token.has_prefix("#") && token.length >= 7 && is_hex(token.substring(1, 6))) {
                return token.substring(0, 7).down();
            }
            if ((token.has_prefix("0x") || token.has_prefix("0X")) && token.length >= 8 && is_hex(token.substring(2, 6))) {
                return "#" + token.substring(2, 6).down();
            }

            string parsed = parse_named_color(token);
            if (parsed != "") {
                return parsed;
            }
        }

        string whole = parse_named_color(text);
        if (whole != "") {
            return whole;
        }

        return "";
    }

    private static string parse_named_color(string token) {
        string t = token.strip().down();
        if (t.has_prefix("gray") || t.has_prefix("grey")) {
            int offset = t.has_prefix("gray") ? 4 : 4;
            if (t.length > offset) {
                string suffix = t.substring(offset);
                int level = 0;
                if (int.try_parse(suffix, out level)) {
                    if (level < 0) {
                        level = 0;
                    }
                    if (level > 100) {
                        level = 100;
                    }
                    int v = (int)Math.round((double)level * 255.0 / 100.0);
                    return "#%02x%02x%02x".printf(v, v, v);
                }
            }
        }

        Gdk.RGBA rgba = Gdk.RGBA();
        if (!rgba.parse(token)) {
            return "";
        }

        int r = (int)(rgba.red * 255.0);
        int g = (int)(rgba.green * 255.0);
        int b = (int)(rgba.blue * 255.0);
        return "#%02x%02x%02x".printf(r, g, b);
    }

    private static bool is_hex(string text) {
        if (text.length != 6) {
            return false;
        }
        for (int i = 0; i < text.length; i++) {
            unichar c = text.get_char(i);
            bool digit = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
            if (!digit) {
                return false;
            }
        }
        return true;
    }
}

public class ThemeParser : Object {
    public static ThemeConfig parse_theme(string theme_path) {
        string openbox_dir = resolve_openbox_dir(theme_path);
        var config = new ThemeConfig(theme_path, openbox_dir);
        string themerc_path = resolve_themerc_path(theme_path, openbox_dir);

        if (!FileUtils.test(themerc_path, FileTest.EXISTS)) {
            return config;
        }

        try {
            string content;
            FileUtils.get_contents(themerc_path, out content);
            string[] lines = content.split("\n");

            foreach (string line_raw in lines) {
                string line = line_raw.strip();
                if (line == "" || line.has_prefix("#") || line.has_prefix("!")) {
                    continue;
                }

                int split_at = line.index_of(":");
                if (split_at <= 0) {
                    continue;
                }

                string key = line.substring(0, split_at).strip().down();
                string value = line.substring(split_at + 1).strip();
                if (key == "" || value == "") {
                    continue;
                }

                config.set_entry(key, value);
            }
        } catch (Error e) {
            warning("Error parsing themerc: %s", e.message);
        }

        return config;
    }

    public static string darken_color(string color, double factor = 0.75) {
        Gdk.RGBA c = Gdk.RGBA();
        if (!c.parse(color)) {
            return color;
        }

        double r = clamp01(c.red * factor);
        double g = clamp01(c.green * factor);
        double b = clamp01(c.blue * factor);

        return "#%02x%02x%02x".printf((int)(r * 255.0), (int)(g * 255.0), (int)(b * 255.0));
    }

    private static double clamp01(double v) {
        if (v < 0.0) {
            return 0.0;
        }
        if (v > 1.0) {
            return 1.0;
        }
        return v;
    }

    private static string resolve_openbox_dir(string theme_path) {
        string candidate = Path.build_filename(theme_path, "openbox-3");

        if (FileUtils.test(candidate, FileTest.IS_DIR)) {
            return candidate;
        }

        if (FileUtils.test(candidate, FileTest.IS_SYMLINK)) {
            try {
                File file = File.new_for_path(candidate);
                FileInfo info = file.query_info("standard::symlink-target", FileQueryInfoFlags.NONE);
                string? target = info.get_symlink_target();
                if (target != null && target != "") {
                    if (!Path.is_absolute(target)) {
                        target = Path.build_filename(Path.get_dirname(candidate), target);
                    }
                    if (FileUtils.test(target, FileTest.IS_DIR)) {
                        return target;
                    }
                }
            } catch (Error e) {
            }
        }

        return candidate;
    }

    private static string resolve_themerc_path(string theme_path, string openbox_dir) {
        string in_openbox = Path.build_filename(openbox_dir, "themerc");
        if (FileUtils.test(in_openbox, FileTest.EXISTS)) {
            return in_openbox;
        }

        string root_themerc = Path.build_filename(theme_path, "themerc");
        if (FileUtils.test(root_themerc, FileTest.EXISTS)) {
            return root_themerc;
        }

        return in_openbox;
    }
}
