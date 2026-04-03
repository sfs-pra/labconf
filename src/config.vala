/* config.vala - Read/write labwc configuration */

public class Config : Object {
    public string rc_path { get; private set; }
    public string settings_path { get; private set; }
    public string autostart_path { get; private set; }
    
    private string content = "";

    private string build_labwc_path_from_home(string home_dir, string rel) {
        return Path.build_filename(home_dir, ".config", "labwc", rel);
    }

    private string build_labwc_path_from_config_base(string config_base, string rel) {
        return Path.build_filename(config_base, "labwc", rel);
    }

    private string? passwd_home_for_user(string username) {
        try {
            string passwd;
            if (!FileUtils.get_contents("/etc/passwd", out passwd)) {
                return null;
            }
            foreach (string line in passwd.split("\n")) {
                if (line == "" || line.has_prefix("#")) {
                    continue;
                }
                string[] parts = line.split(":");
                if (parts.length >= 6 && parts[0] == username && parts[5] != "") {
                    return parts[5];
                }
            }
        } catch (Error e) {
        }
        return null;
    }

    private string? passwd_home_for_uid(string uid_text) {
        try {
            string passwd;
            if (!FileUtils.get_contents("/etc/passwd", out passwd)) {
                return null;
            }
            foreach (string line in passwd.split("\n")) {
                if (line == "" || line.has_prefix("#")) {
                    continue;
                }
                string[] parts = line.split(":");
                if (parts.length >= 6 && parts[2] == uid_text && parts[5] != "") {
                    return parts[5];
                }
            }
        } catch (Error e) {
        }
        return null;
    }

    private string? home_from_labwc_pid() {
        string? pid = Environment.get_variable("LABWC_PID");
        if (pid == null || pid.strip() == "") {
            return null;
        }

        try {
            string status;
            string proc_status = Path.build_filename("/proc", pid.strip(), "status");
            if (!FileUtils.get_contents(proc_status, out status)) {
                return null;
            }

            foreach (string line in status.split("\n")) {
                if (!line.has_prefix("Uid:")) {
                    continue;
                }
                string[] parts = line.split("\t");
                if (parts.length >= 2) {
                    string uid = parts[1].strip();
                    return passwd_home_for_uid(uid);
                }
            }
        } catch (Error e) {
        }

        return null;
    }

    private string[] collect_home_rc_candidates() {
        string[] out = {};
        try {
            var dir = Dir.open("/home", 0);
            string? name;
            while ((name = dir.read_name()) != null) {
                if (name == "." || name == "..") {
                    continue;
                }
                string candidate = build_labwc_path_from_home(Path.build_filename("/home", name), "rc.xml");
                if (FileUtils.test(candidate, FileTest.EXISTS)) {
                    out += candidate;
                }
            }
        } catch (Error e) {
        }
        return out;
    }

    private string[] push_candidate(string[] list, string path) {
        if (path == "") {
            return list;
        }
        for (int i = 0; i < list.length; i++) {
            if (list[i] == path) {
                return list;
            }
        }
        string[] out = {};
        for (int i = 0; i < list.length; i++) {
            out += list[i];
        }
        out += path;
        return out;
    }

    private int parse_int_or_default(string? text, int fallback) {
        if (text == null) {
            return fallback;
        }

        int parsed = 0;
        if (!int.try_parse(text.strip(), out parsed)) {
            return fallback;
        }
        return parsed;
    }
    
    public Config() {
        string? rc_override = Environment.get_variable("LABCONF_RC_PATH");
        string? settings_override = Environment.get_variable("LABCONF_SETTINGS_PATH");

        string? xdg_config_home = Environment.get_variable("XDG_CONFIG_HOME");
        string home = Environment.get_home_dir();
        bool is_root = Environment.get_user_name() == "root";

        if (rc_override != null && rc_override.strip() != "") {
            rc_path = rc_override.strip();
        } else {
            string[] candidates = {};

            if (!is_root) {
                if (xdg_config_home != null && xdg_config_home.strip() != "") {
                    candidates = push_candidate(candidates, build_labwc_path_from_config_base(xdg_config_home.strip(), "rc.xml"));
                }
                candidates = push_candidate(candidates, build_labwc_path_from_home(home, "rc.xml"));
            }

            string? labwc_home = home_from_labwc_pid();
            if (labwc_home != null) {
                candidates = push_candidate(candidates, build_labwc_path_from_home(labwc_home, "rc.xml"));
            }

            string? sudo_user = Environment.get_variable("SUDO_USER");
            if (sudo_user != null && sudo_user != "" && sudo_user != "root") {
                string? sudo_home = passwd_home_for_user(sudo_user);
                if (sudo_home != null) {
                    candidates = push_candidate(candidates, build_labwc_path_from_home(sudo_home, "rc.xml"));
                }
            }

            candidates = push_candidate(candidates, build_labwc_path_from_home("/home/live", "rc.xml"));

            string[] found = collect_home_rc_candidates();
            for (int i = 0; i < found.length; i++) {
                candidates = push_candidate(candidates, found[i]);
            }

            if (is_root) {
                if (xdg_config_home != null && xdg_config_home.strip() != "") {
                    candidates = push_candidate(candidates, build_labwc_path_from_config_base(xdg_config_home.strip(), "rc.xml"));
                }
                candidates = push_candidate(candidates, build_labwc_path_from_home(home, "rc.xml"));
            }

            rc_path = build_labwc_path_from_home(home, "rc.xml");
            for (int i = 0; i < candidates.length; i++) {
                if (FileUtils.test(candidates[i], FileTest.EXISTS)) {
                    rc_path = candidates[i];
                    break;
                }
            }
        }

        if (settings_override != null && settings_override.strip() != "") {
            settings_path = settings_override.strip();
        } else {
            settings_path = Path.build_filename(home, ".config", "gtk-3.0", "settings.ini");
            string rc_dir = Path.get_dirname(rc_path);
            string rc_home_guess = Path.get_dirname(Path.get_dirname(rc_dir));
            if (rc_home_guess != null && rc_home_guess != "") {
                settings_path = Path.build_filename(rc_home_guess, ".config", "gtk-3.0", "settings.ini");
            }
        }

        autostart_path = build_labwc_path_from_home(home, "autostart");
        string rc_dir_final = Path.get_dirname(rc_path);
        if (rc_dir_final != null && rc_dir_final != "") {
            autostart_path = Path.build_filename(rc_dir_final, "autostart");
        }
    }
    
    public bool load() {
        try {
            if (!FileUtils.test(rc_path, FileTest.EXISTS)) {
                return false;
            }
            string data = "";
            if (!FileUtils.get_contents(rc_path, out data)) {
                return false;
            }
            content = data;
            return true;
        } catch (Error e) {
            return false;
        }
    }
    
    public bool save() {
        try {
            if (content == null) {
                return false;
            }
            FileUtils.set_contents(rc_path, content);
            return true;
        } catch (Error e) {
            return false;
        }
    }

    public string render_content() {
        string out = content;
        if (out != "" && !out.has_suffix("\n")) {
            out += "\n";
        }
        return out;
    }

    private string xml_unescape(string value) {
        string v = value;
        v = v.replace("&lt;", "<");
        v = v.replace("&gt;", ">");
        v = v.replace("&quot;", "\"");
        v = v.replace("&apos;", "'");
        v = v.replace("&amp;", "&");
        return v;
    }

    private bool is_inside_xml_comment(int pos) {
        int scan = 0;
        while (true) {
            int open = content.index_of("<!--", scan);
            if (open < 0 || open > pos) {
                return false;
            }

            int close = content.index_of("-->", open + 4);
            if (close < 0) {
                return pos >= open;
            }

            if (pos >= open && pos < close + 3) {
                return true;
            }

            scan = close + 3;
        }
    }

    private bool has_active_section(string section_tag) {
        int body_start = 0;
        int body_end = 0;
        return get_active_section_body_bounds(section_tag, out body_start, out body_end);
    }

    private bool find_active_section_bounds(string section_tag, out int section_start, out int section_end, out int body_start, out int body_end) {
        section_start = -1;
        section_end = -1;
        body_start = -1;
        body_end = -1;

        string open_token = "<" + section_tag;
        string close_token = "</" + section_tag + ">";
        int search = 0;

        while (true) {
            int open = content.index_of(open_token, search);
            if (open < 0) {
                return false;
            }

            int after = open + open_token.length;
            if (after < content.length) {
                unichar boundary = content.get_char(after);
                if (!(boundary == ' ' || boundary == '\t' || boundary == '\n' || boundary == '\r' || boundary == '>' || boundary == '/')) {
                    search = after;
                    continue;
                }
            }

            if (is_inside_xml_comment(open)) {
                search = after;
                continue;
            }

            int open_end = content.index_of(">", after);
            if (open_end < 0) {
                return false;
            }

            section_start = open;

            bool self_closing = open_end > open && content.get_char(open_end - 1) == '/';
            if (self_closing) {
                section_end = open_end + 1;
                body_start = open_end;
                body_end = open_end;
                return true;
            }

            int close = content.index_of(close_token, open_end + 1);
            while (close >= 0 && is_inside_xml_comment(close)) {
                close = content.index_of(close_token, close + close_token.length);
            }
            if (close < 0) {
                return false;
            }

            section_end = close + close_token.length;
            body_start = open_end + 1;
            body_end = close;
            return true;
        }
    }

    private bool get_active_section_body_bounds(string section_tag, out int body_start, out int body_end) {
        int section_start = 0;
        int section_end = 0;
        return find_active_section_bounds(section_tag, out section_start, out section_end, out body_start, out body_end);
    }

    private bool get_theme_titlebar_body_bounds(out int body_start, out int body_end) {
        body_start = -1;
        body_end = -1;

        int theme_body_start = 0;
        int theme_body_end = 0;
        if (!get_active_section_body_bounds("theme", out theme_body_start, out theme_body_end)) {
            return false;
        }

        string theme_body = content.substring(theme_body_start, theme_body_end - theme_body_start);
        try {
            var regex = new Regex("(?s)<titlebar[^>]*>(.*?)</titlebar>");
            MatchInfo mi;
            if (regex.match(theme_body, 0, out mi) && mi.matches()) {
                do {
                    int section_start_rel = 0;
                    int section_end_rel = 0;
                    int body_start_rel = 0;
                    int body_end_rel = 0;
                    if (!mi.fetch_pos(0, out section_start_rel, out section_end_rel)) {
                        continue;
                    }
                    if (is_inside_xml_comment(theme_body_start + section_start_rel)) {
                        continue;
                    }
                    if (!mi.fetch_pos(1, out body_start_rel, out body_end_rel)) {
                        continue;
                    }

                    body_start = theme_body_start + body_start_rel;
                    body_end = theme_body_start + body_end_rel;
                    return true;
                } while (mi.next());
            }
        } catch (Error e) {
        }

        return false;
    }

    private void ensure_theme_titlebar_block() {
        int section_start = 0;
        int section_end = 0;
        int theme_body_start = 0;
        int theme_body_end = 0;
        if (!find_active_section_bounds("theme", out section_start, out section_end, out theme_body_start, out theme_body_end)) {
            ensure_section_block("theme");
            if (!find_active_section_bounds("theme", out section_start, out section_end, out theme_body_start, out theme_body_end)) {
                return;
            }
        }

        int titlebar_body_start = 0;
        int titlebar_body_end = 0;
        if (get_theme_titlebar_body_bounds(out titlebar_body_start, out titlebar_body_end)) {
            return;
        }

        string insertion = "<titlebar></titlebar>";
        content = content.substring(0, theme_body_end) + insertion + content.substring(theme_body_end);
    }

    private string? get_xml_value_in_theme_titlebar(string tag) {
        int body_start = 0;
        int body_end = 0;
        if (!get_theme_titlebar_body_bounds(out body_start, out body_end)) {
            return null;
        }

        string body = content.substring(body_start, body_end - body_start);
        try {
            var regex = new Regex("<" + tag + ">([^<]*)</" + tag + ">");
            MatchInfo mi;
            if (regex.match(body, 0, out mi) && mi.matches()) {
                return xml_unescape(mi.fetch(1));
            }
        } catch (Error e) {
        }
        return null;
    }

    private void set_xml_value_in_theme_titlebar(string tag, string value) {
        ensure_theme_titlebar_block();
        int body_start = 0;
        int body_end = 0;
        if (!get_theme_titlebar_body_bounds(out body_start, out body_end)) {
            return;
        }

        string body = content.substring(body_start, body_end - body_start);
        string replacement = "<" + tag + ">" + Markup.escape_text(value, -1) + "</" + tag + ">";
        try {
            var regex = new Regex("<" + tag + ">[^<]*</" + tag + ">");
            MatchInfo mi;
            if (regex.match(body, 0, out mi) && mi.matches()) {
                int start = 0;
                int end = 0;
                if (mi.fetch_pos(0, out start, out end)) {
                    body = body.substring(0, start) + replacement + body.substring(end);
                }
            } else {
                body += replacement;
            }
        } catch (Error e) {
            body += replacement;
        }

        content = content.substring(0, body_start) + body + content.substring(body_end);
    }

    private string titlebar_layout_to_shorthand(string layout) {
        string v = layout.down();

        bool has_icon = v.index_of("icon") >= 0;
        bool has_iconify = v.index_of("iconify") >= 0;
        bool has_max = v.index_of("max") >= 0;
        bool has_close = v.index_of("close") >= 0;
        bool has_shade = v.index_of("shade") >= 0;
        bool has_desk = v.index_of("desk") >= 0;

        var out = new StringBuilder();
        if (has_icon) {
            out.append("N");
        }
        if (has_iconify) {
            out.append("I");
        }
        if (has_max) {
            out.append("M");
        }
        if (has_close) {
            out.append("C");
        }
        if (has_shade) {
            out.append("S");
        }
        if (has_desk) {
            out.append("D");
        }
        return out.str;
    }

    private string shorthand_to_titlebar_layout(string shorthand) {
        string v = shorthand.strip().up();
        bool has_n = v.index_of("N") >= 0;
        bool has_i = v.index_of("I") >= 0;
        bool has_m = v.index_of("M") >= 0;
        bool has_c = v.index_of("C") >= 0;
        bool has_s = v.index_of("S") >= 0;
        bool has_d = v.index_of("D") >= 0;

        string left = has_n ? "icon" : "";
        string[] right = {};
        if (has_i) right += "iconify";
        if (has_m) right += "max";
        if (has_c) right += "close";
        if (has_s) right += "shade";
        if (has_d) right += "desk";

        string right_joined = string.joinv(",", right);
        return left + ":" + right_joined;
    }

    private string? get_xml_value_in_section(string section_tag, string tag) {
        int body_start = 0;
        int body_end = 0;
        if (get_active_section_body_bounds(section_tag, out body_start, out body_end)) {
            string body = content.substring(body_start, body_end - body_start);
            try {
                var value_regex = new Regex("<" + tag + ">([^<]*)</" + tag + ">");
                MatchInfo mi;
                if (value_regex.match(body, 0, out mi) && mi.matches()) {
                    return xml_unescape(mi.fetch(1));
                }
            } catch (Error e) {
            }
        }

        string? attr = get_xml_attribute_in_section(section_tag, tag);
        if (attr != null) {
            return attr;
        }
        return null;
    }

    private void set_xml_value_in_section(string section_tag, string tag, string value) {
        ensure_section_block(section_tag);
        try {
            var self_closing = new Regex("<" + section_tag + "([^>]*)/>");
            MatchInfo sc;
            if (self_closing.match(content, 0, out sc) && sc.matches()) {
                do {
                    int start = 0;
                    int end = 0;
                    if (!sc.fetch_pos(0, out start, out end) || is_inside_xml_comment(start)) {
                        continue;
                    }
                    string attrs = sc.fetch(1).strip();
                    string replacement = "<" + section_tag;
                    if (attrs != "") {
                        replacement += " " + attrs;
                    }
                    replacement += "></" + section_tag + ">";
                    content = content.substring(0, start) + replacement + content.substring(end);
                    break;
                } while (sc.next());
            }
        } catch (Error e) {
        }

        if (get_xml_attribute_in_section(section_tag, tag) != null) {
            set_xml_attribute_in_section(section_tag, tag, value);
            return;
        }
        int body_start = 0;
        int body_end = 0;
        if (!get_active_section_body_bounds(section_tag, out body_start, out body_end)) {
            return;
        }

        string body = content.substring(body_start, body_end - body_start);
        string replacement = "<" + tag + ">" + Markup.escape_text(value, -1) + "</" + tag + ">";
        try {
            var value_regex = new Regex("<" + tag + ">[^<]*</" + tag + ">");
            MatchInfo mi;
            if (value_regex.match(body, 0, out mi) && mi.matches()) {
                int start = 0;
                int end = 0;
                if (mi.fetch_pos(0, out start, out end)) {
                    body = body.substring(0, start) + replacement + body.substring(end);
                }
            } else {
                body += replacement;
            }
        } catch (Error e) {
            body += replacement;
        }

        content = content.substring(0, body_start) + body + content.substring(body_end);
    }

    private void remove_xml_values_in_section(string section_tag, string tag) {
        int body_start = 0;
        int body_end = 0;
        if (!get_active_section_body_bounds(section_tag, out body_start, out body_end)) {
            return;
        }

        string body = content.substring(body_start, body_end - body_start);
        try {
            var value_regex = new Regex("<" + tag + ">[^<]*</" + tag + ">");
            MatchInfo mi;
            while (value_regex.match(body, 0, out mi) && mi.matches()) {
                int start = 0;
                int end = 0;
                if (!mi.fetch_pos(0, out start, out end)) {
                    break;
                }
                body = body.substring(0, start) + body.substring(end);
            }
        } catch (Error e) {
        }

        content = content.substring(0, body_start) + body + content.substring(body_end);
    }

    private void ensure_section_block(string section_tag) {
        if (!has_active_section(section_tag)) {
            string insertion = "<" + section_tag + "></" + section_tag + ">";
            if (content.index_of("</labwc_config>") >= 0) {
                content = content.replace("</labwc_config>", insertion + "\n</labwc_config>");
            } else {
                content += "\n" + insertion + "\n";
            }
        }
    }

    private string? get_xml_attribute_in_section(string section_tag, string attr_name) {
        try {
            var regex = new Regex("<" + section_tag + "[^>]*\\b" + attr_name + "=\"([^\"]*)\"");
            MatchInfo mi;
            if (regex.match(content, 0, out mi) && mi.matches()) {
                do {
                    int start = 0;
                    int end = 0;
                    if (mi.fetch_pos(0, out start, out end) && !is_inside_xml_comment(start)) {
                        return mi.fetch(1);
                    }
                } while (mi.next());
            }
        } catch (Error e) {
        }
        return null;
    }

    private void set_xml_attribute_in_section(string section_tag, string attr_name, string attr_value) {
        ensure_section_block(section_tag);
        try {
            var section_regex = new Regex("<" + section_tag + "([^>]*)>");
            MatchInfo mi;
            if (!section_regex.match(content, 0, out mi) || !mi.matches()) {
                return;
            }

            bool found_active = false;
            do {
                int section_start = 0;
                int section_end = 0;
                if (mi.fetch_pos(0, out section_start, out section_end) && !is_inside_xml_comment(section_start)) {
                    found_active = true;
                    break;
                }
            } while (mi.next());
            if (!found_active) {
                return;
            }

            string attrs = mi.fetch(1);
            bool self_closing = attrs.strip().has_suffix("/");
            attrs = attrs.replace("\r", "");
            var slash_tail_regex = new Regex("\\s*/\\s*$");
            attrs = slash_tail_regex.replace(attrs, attrs.length, 0, "");
            string replacement_attrs = attrs;
            var attr_regex = new Regex("\\b" + attr_name + "=\"[^\"]*\"");
            if (attr_regex.match(attrs)) {
                replacement_attrs = attr_regex.replace(attrs, attrs.length, 0, attr_name + "=\"" + attr_value + "\"");
            } else {
                replacement_attrs = attrs + " " + attr_name + "=\"" + attr_value + "\"";
            }
            replacement_attrs = replacement_attrs.strip();

            int start = 0;
            int end = 0;
            if (!mi.fetch_pos(0, out start, out end)) {
                return;
            }

            string new_tag = "<" + section_tag;
            if (replacement_attrs != "") {
                new_tag += " " + replacement_attrs;
            }
            new_tag += self_closing ? " />" : ">";
            content = content.substring(0, start) + new_tag + content.substring(end);
        } catch (Error e) {
        }
    }

    private string get_margin_attr(string attr, string fallback) {
        try {
            var regex = new Regex("<margin\\b([^>]*)>");
            MatchInfo mi;
            if (!regex.match(content, 0, out mi) || !mi.matches()) {
                return fallback;
            }

            do {
                int start = 0;
                int end = 0;
                if (!mi.fetch_pos(0, out start, out end) || is_inside_xml_comment(start)) {
                    continue;
                }

                string attrs = mi.fetch(1);
                var attr_regex = new Regex("\\b" + attr + "=\"([^\"]*)\"");
                MatchInfo ami;
                if (attr_regex.match(attrs, 0, out ami) && ami.matches()) {
                    return ami.fetch(1);
                }
                return fallback;
            } while (mi.next());
        } catch (Error e) {
        }
        return fallback;
    }

    private void ensure_margin_tag() {
        try {
            var regex = new Regex("<margin\\b");
            MatchInfo mi;
            if (regex.match(content, 0, out mi) && mi.matches()) {
                do {
                    int start = 0;
                    int end = 0;
                    if (mi.fetch_pos(0, out start, out end) && !is_inside_xml_comment(start)) {
                        return;
                    }
                } while (mi.next());
            }
        } catch (Error e) {
        }

        string block = "<margin top=\"0\" bottom=\"0\" left=\"0\" right=\"0\" />";
        if (content.index_of("</labwc_config>") >= 0) {
            content = content.replace("</labwc_config>", block + "\n</labwc_config>");
        } else {
            content += "\n" + block + "\n";
        }
    }

    private void set_xml_attribute(string tag, string attr_name, string attr_value) {
        try {
            var regex = new Regex("<" + tag + "([^>]*)>");
            MatchInfo match_info;
            if (regex.match(content, 0, out match_info) && match_info.matches()) {
                bool found_active = false;
                do {
                    int tag_start = 0;
                    int tag_end = 0;
                    if (!match_info.fetch_pos(0, out tag_start, out tag_end)) {
                        continue;
                    }
                    if (is_inside_xml_comment(tag_start)) {
                        continue;
                    }

                    string attrs = match_info.fetch(1);
                    bool self_closing = attrs.strip().has_suffix("/");
                    var slash_tail_regex = new Regex("\\s*/\\s*$");
                    attrs = slash_tail_regex.replace(attrs, attrs.length, 0, "");
                    var attr_regex = new Regex("\\b" + attr_name + "=\"[^\"]*\"");
                    if (attr_regex.match(attrs)) {
                        attrs = attr_regex.replace(attrs, attrs.length, 0, attr_name + "=\"" + attr_value + "\"");
                    } else {
                        attrs += " " + attr_name + "=\"" + attr_value + "\"";
                    }
                    attrs = attrs.strip();

                    string replacement = "<" + tag;
                    if (attrs != "") {
                        replacement += " " + attrs;
                    }
                    replacement += self_closing ? " />" : ">";
                    content = content.substring(0, tag_start) + replacement + content.substring(tag_end);
                    found_active = true;
                    break;
                } while (match_info.next());

                if (found_active) {
                    return;
                }
            }

            string insertion = "<" + tag + " " + attr_name + "=\"" + attr_value + "\" />";
            if (content.index_of("</labwc_config>") >= 0) {
                content = content.replace("</labwc_config>", insertion + "\n</labwc_config>");
            } else {
                content += "\n" + insertion + "\n";
            }
        } catch (Error e) {}
    }
    
    public string get_theme_name() {
        string? v = get_xml_value_in_section("theme", "name");
        return v ?? "Greybird";
    }
    
    public void set_theme_name(string name) {
        set_xml_value_in_section("theme", "name", name);
    }
    
    public int get_corner_radius() {
        string? v = get_xml_value_in_section("theme", "cornerRadius");
        return v != null ? int.parse(v) : 4;
    }
    
    public void set_corner_radius(int r) {
        set_xml_value_in_section("theme", "cornerRadius", r.to_string());
    }
    
    public bool get_keep_border() {
        string? v = get_xml_value_in_section("theme", "keepBorder");
        return v == null || v.down() == "yes";
    }
    
    public void set_keep_border(bool v) {
        set_xml_value_in_section("theme", "keepBorder", v ? "yes" : "no");
    }
    
    public bool get_show_title() {
        string? v = get_xml_value_in_theme_titlebar("showTitle");
        if (v == null) {
            v = get_xml_value_in_section("theme", "showTitle");
        }
        return v == null || v.down() == "yes";
    }
    
    public void set_show_title(bool v) {
        remove_xml_values_in_section("theme", "showTitle");
        set_xml_value_in_theme_titlebar("showTitle", v ? "yes" : "no");
    }
    
    public string get_title_layout() {
        string? raw = get_xml_value_in_theme_titlebar("layout");
        if (raw != null && raw.strip() != "") {
            return titlebar_layout_to_shorthand(raw);
        }

        string? legacy = get_xml_value_in_section("theme", "titleLayout");
        if (legacy != null && legacy.strip() != "") {
            return legacy;
        }

        return "NLIMC";
    }
    
    public void set_title_layout(string v) {
        remove_xml_values_in_section("theme", "titleLayout");
        set_xml_value_in_theme_titlebar("layout", shorthand_to_titlebar_layout(v));
    }
    
    public bool get_maximized_decoration() {
        string? v = get_xml_value_in_section("theme", "maximizedDecoration");
        return v == null || v.down() != "none";
    }
    
    public void set_maximized_decoration(bool v) {
        set_xml_value_in_section("theme", "maximizedDecoration", v ? "titlebar" : "none");
    }
    
    public bool get_drop_shadows() {
        string? v = get_xml_value_in_section("theme", "dropShadows");
        return v != null && v.down() == "yes";
    }
    
    public void set_drop_shadows(bool v) {
        set_xml_value_in_section("theme", "dropShadows", v ? "yes" : "no");
    }

    public bool get_drop_shadows_on_tiled() {
        string? v = get_xml_value_in_section("theme", "dropShadowsOnTiled");
        return v != null && v.down() == "yes";
    }

    public void set_drop_shadows_on_tiled(bool v) {
        set_xml_value_in_section("theme", "dropShadowsOnTiled", v ? "yes" : "no");
    }
    
    public FontConfig get_font(string place) {
        var font = new FontConfig();
        string pattern = "<font[^>]*place=\"" + place + "\"[^>]*>([\\s\\S]*?)</font>";
        try {
            var regex = new Regex(pattern);
            MatchInfo mi;
            if (regex.match(content, 0, out mi) && mi.matches()) {
                string fc = mi.fetch(0);
                MatchInfo ni;
                if (new Regex("<name>([^<]*)</name>").match(fc, 0, out ni) && ni.matches()) {
                    font.name = ni.fetch(1);
                }
                if (new Regex("<size>([^<]*)</size>").match(fc, 0, out ni) && ni.matches()) {
                    font.size = int.parse(ni.fetch(1));
                }
            }
        } catch (Error e) {}
        return font;
    }
    
    public void set_font(string place, FontConfig font) {
        var current = get_font(place);
        if (current.name.down() == font.name.down() && current.size == font.size) {
            return;
        }

        string pattern = "<font[^>]*place=\"" + place + "\"[^>]*>[\\s\\S]*?</font>";
        string new_font =
            "<font place=\"" + place + "\">" +
            "<name>" + font.name + "</name>" +
            "<size>" + font.size.to_string() + "</size>" +
            "<slant>normal</slant>" +
            "<weight>normal</weight>" +
            "</font>";
        try {
            var regex = new Regex(pattern);
            if (regex.match(content)) {
                content = regex.replace(content, content.length, 0, new_font);
            } else {
                content = content.replace("</theme>", new_font + "</theme>");
            }
        } catch (Error e) {}
    }
    
    public bool get_focus_follow_mouse() {
        string? v = get_xml_value_in_section("focus", "followMouse");
        return v != null && v.down() == "yes";
    }
    
    public void set_focus_follow_mouse(bool v) {
        set_xml_value_in_section("focus", "followMouse", v ? "yes" : "no");
    }
    
    public int get_focus_delay() {
        string? v = get_xml_value_in_section("focus", "focusDelay");
        return v != null ? int.parse(v) : 0;
    }
    
    public void set_focus_delay(int v) {
        if (get_focus_delay() == v) {
            return;
        }
        set_xml_value_in_section("focus", "focusDelay", v.to_string());
    }
    
    public bool get_focus_raise_on_focus() {
        string? v = get_xml_value_in_section("focus", "raiseOnFocus");
        return v != null && v.down() == "yes";
    }
    
    public void set_focus_raise_on_focus(bool v) {
        set_xml_value_in_section("focus", "raiseOnFocus", v ? "yes" : "no");
    }

    public bool get_focus_follow_mouse_requires_movement() {
        string? v = get_xml_value_in_section("focus", "followMouseRequiresMovement");
        return v != null && v.down() == "yes";
    }

    public void set_focus_follow_mouse_requires_movement(bool v) {
        set_xml_value_in_section("focus", "followMouseRequiresMovement", v ? "yes" : "no");
    }
    
    public bool get_focus_focus_last() {
        string? v = get_xml_value_in_section("focus", "focusLast");
        return v == null || v.down() == "yes";
    }
    
    public void set_focus_focus_last(bool v) {
        set_xml_value_in_section("focus", "focusLast", v ? "yes" : "no");
    }
    
    public bool get_focus_focus_new() {
        string? v = get_xml_value_in_section("focus", "focusNew");
        return v == null || v.down() == "yes";
    }
    
    public void set_focus_focus_new(bool v) {
        set_xml_value_in_section("focus", "focusNew", v ? "yes" : "no");
    }
    
    public int get_mouse_double_click_time() {
        string? v = get_xml_value_in_section("mouse", "doubleClickTime");
        return v != null ? int.parse(v) : 500;
    }
    
    public void set_mouse_double_click_time(int v) {
        set_xml_value_in_section("mouse", "doubleClickTime", v.to_string());
    }
    
    public string get_placement_policy() {
        string? v = get_xml_value_in_section("placement", "policy");
        if (v == null || v == "") {
            return "cascade";
        }
        return v.down();
    }
    
    public void set_placement_policy(string v) {
        set_xml_value_in_section("placement", "policy", v.down());
    }

    public string get_placement_monitor() {
        string? v = get_xml_value_in_section("placement", "monitor");
        return v ?? "Any";
    }

    public void set_placement_monitor(string v) {
        string? raw = get_xml_value_in_section("placement", "monitor");
        if ((raw == null || raw == "") && v == "Any") {
            return;
        }
        if (raw != null && raw == v) {
            return;
        }
        set_xml_value_in_section("placement", "monitor", v);
    }

    public int get_placement_cascade_offset_x() {
        int body_start = 0;
        int body_end = 0;
        if (!get_active_section_body_bounds("placement", out body_start, out body_end)) {
            return 0;
        }

        string body = content.substring(body_start, body_end - body_start);
        try {
            var regex = new Regex("(?s)<cascadeOffset>.*?<x>([^<]*)</x>.*?</cascadeOffset>");
            MatchInfo mi;
            if (regex.match(body, 0, out mi) && mi.matches()) {
                return int.parse(mi.fetch(1));
            }
        } catch (Error e) {
        }
        return 0;
    }

    public int get_placement_cascade_offset_y() {
        int body_start = 0;
        int body_end = 0;
        if (!get_active_section_body_bounds("placement", out body_start, out body_end)) {
            return 0;
        }

        string body = content.substring(body_start, body_end - body_start);
        try {
            var regex = new Regex("(?s)<cascadeOffset>.*?<y>([^<]*)</y>.*?</cascadeOffset>");
            MatchInfo mi;
            if (regex.match(body, 0, out mi) && mi.matches()) {
                return int.parse(mi.fetch(1));
            }
        } catch (Error e) {
        }
        return 0;
    }

    public void set_placement_cascade_offset(int x, int y) {
        if (x < -5000) x = -5000;
        if (x > 5000) x = 5000;
        if (y < -5000) y = -5000;
        if (y > 5000) y = 5000;

        if (get_placement_cascade_offset_x() == x && get_placement_cascade_offset_y() == y) {
            return;
        }

        ensure_section_block("placement");
        int body_start = 0;
        int body_end = 0;
        if (!get_active_section_body_bounds("placement", out body_start, out body_end)) {
            return;
        }

        string body = content.substring(body_start, body_end - body_start);
        string replacement = "<cascadeOffset><x>" + x.to_string() + "</x><y>" + y.to_string() + "</y></cascadeOffset>";
        try {
            var regex = new Regex("(?s)<cascadeOffset>.*?</cascadeOffset>");
            if (regex.match(body)) {
                body = regex.replace(body, body.length, 0, replacement);
            } else {
                body += replacement;
            }
        } catch (Error e) {
            body += replacement;
        }

        content = content.substring(0, body_start) + body + content.substring(body_end);
    }
    
    public bool get_window_switcher_show() {
        string pattern = "<osd[^>]*show=\"([^\"]*)\"";
        try {
            var regex = new Regex(pattern);
            MatchInfo mi;
            if (regex.match(content, 0, out mi) && mi.matches()) {
                do {
                    int start = 0;
                    int end = 0;
                    if (mi.fetch_pos(0, out start, out end) && !is_inside_xml_comment(start)) {
                        return mi.fetch(1) != "no";
                    }
                } while (mi.next());
            }
        } catch (Error e) {}
        return true;
    }
    
    public void set_window_switcher_show(bool v) {
        set_xml_attribute("osd", "show", v ? "yes" : "no");
    }
    
    public string get_window_switcher_style() {
        string pattern = "<osd[^>]*style=\"([^\"]*)\"";
        try {
            var regex = new Regex(pattern);
            MatchInfo mi;
            if (regex.match(content, 0, out mi) && mi.matches()) {
                do {
                    int start = 0;
                    int end = 0;
                    if (mi.fetch_pos(0, out start, out end) && !is_inside_xml_comment(start)) {
                        return mi.fetch(1);
                    }
                } while (mi.next());
            }
        } catch (Error e) {}
        return "thumbnail";
    }
    
    public void set_window_switcher_style(string v) {
        set_xml_attribute("osd", "style", v);
    }

    public string get_window_switcher_output() {
        string pattern = "<osd[^>]*output=\"([^\"]*)\"";
        try {
            var regex = new Regex(pattern);
            MatchInfo mi;
            if (regex.match(content, 0, out mi) && mi.matches()) {
                do {
                    int start = 0;
                    int end = 0;
                    if (mi.fetch_pos(0, out start, out end) && !is_inside_xml_comment(start)) {
                        return mi.fetch(1);
                    }
                } while (mi.next());
            }
        } catch (Error e) {
        }
        return "all";
    }

    public void set_window_switcher_output(string v) {
        set_xml_attribute("osd", "output", v);
    }

    public string get_window_switcher_thumbnail_label_format() {
        string pattern = "<osd[^>]*thumbnailLabelFormat=\"([^\"]*)\"";
        try {
            var regex = new Regex(pattern);
            MatchInfo mi;
            if (regex.match(content, 0, out mi) && mi.matches()) {
                do {
                    int start = 0;
                    int end = 0;
                    if (mi.fetch_pos(0, out start, out end) && !is_inside_xml_comment(start)) {
                        return mi.fetch(1);
                    }
                } while (mi.next());
            }
        } catch (Error e) {
        }
        return "%T";
    }

    public void set_window_switcher_thumbnail_label_format(string v) {
        string value = v.strip();
        if (value == "") {
            value = "%T";
        }
        set_xml_attribute("osd", "thumbnailLabelFormat", value);
    }
    
    public bool get_resize_popup_show() {
        string? v = get_xml_value_in_section("resize", "popupShow");
        return v != null && v.down() != "never";
    }
    
    public void set_resize_popup_show(bool v) {
        set_xml_value_in_section("resize", "popupShow", v ? "Always" : "Never");
    }

    public string get_resize_popup_show_mode() {
        string? v = get_xml_value_in_section("resize", "popupShow");
        if (v == null || v == "") {
            return "Never";
        }
        string mode = v.down();
        if (mode == "always") {
            return "Always";
        }
        if (mode == "nonpixel") {
            return "Nonpixel";
        }
        return "Never";
    }

    public void set_resize_popup_show_mode(string mode) {
        string m = mode.down();
        if (m != "always" && m != "nonpixel") {
            m = "never";
        }
        if (m == "always") {
            set_xml_value_in_section("resize", "popupShow", "Always");
        } else if (m == "nonpixel") {
            set_xml_value_in_section("resize", "popupShow", "Nonpixel");
        } else {
            set_xml_value_in_section("resize", "popupShow", "Never");
        }
    }

    public bool get_resize_draw_contents() {
        string? v = get_xml_value_in_section("resize", "drawContents");
        return v == null || v.down() == "yes";
    }

    public void set_resize_draw_contents(bool v) {
        set_xml_value_in_section("resize", "drawContents", v ? "yes" : "no");
    }

    public int get_resize_corner_range() {
        string? v = get_xml_value_in_section("resize", "cornerRange");
        if (v == null || v == "") {
            return 20;
        }
        return parse_int_or_default(v, 20);
    }

    public void set_resize_corner_range(int value) {
        if (value < 1) {
            value = 1;
        }
        set_xml_value_in_section("resize", "cornerRange", value.to_string());
    }

    public int get_resize_minimum_area() {
        string? v = get_xml_value_in_section("resize", "minimumArea");
        if (v == null || v == "") {
            return 64;
        }
        return parse_int_or_default(v, 64);
    }

    public void set_resize_minimum_area(int value) {
        if (value < 1) {
            value = 1;
        }
        set_xml_value_in_section("resize", "minimumArea", value.to_string());
    }

    public int get_desktops_number() {
        string? v = get_xml_attribute_in_section("desktops", "number");
        if (v == null || v == "") {
            string[] names = get_desktops_names();
            if (names.length > 0) {
                return names.length;
            }
            return 1;
        }
        int parsed = parse_int_or_default(v, 1);
        if (parsed < 1) {
            parsed = 1;
        }
        string[] names = get_desktops_names();
        if (names.length > parsed) {
            return names.length;
        }
        return parsed;
    }

    public void set_desktops_number(int number) {
        if (number < 1) {
            number = 1;
        }
        if (get_desktops_number() == number) {
            return;
        }
        set_xml_attribute_in_section("desktops", "number", number.to_string());
    }

    public int get_desktops_popup_time() {
        string? v = get_xml_value_in_section("desktops", "popupTime");
        if (v == null || v == "") {
            return 1000;
        }
        return parse_int_or_default(v, 1000);
    }

    public void set_desktops_popup_time(int ms) {
        if (ms < 0) {
            ms = 0;
        }
        if (get_desktops_popup_time() == ms) {
            return;
        }
        set_xml_value_in_section("desktops", "popupTime", ms.to_string());
    }

    public string get_desktops_prefix() {
        string? v = get_xml_value_in_section("desktops", "prefix");
        return (v == null || v == "") ? "Workspace" : v;
    }

    public void set_desktops_prefix(string prefix) {
        string p = prefix.strip();
        if (p == "") {
            p = "Workspace";
        }
        set_xml_value_in_section("desktops", "prefix", p);
    }

    public string[] get_desktops_names() {
        string[] out = {};
        try {
            var names_regex = new Regex("(?s)<desktops[^>]*>.*?<names>(.*?)</names>.*?</desktops>");
            MatchInfo mi;
            if (names_regex.match(content, 0, out mi) && mi.matches()) {
                string body = mi.fetch(1);
                do {
                    int start = 0;
                    int end = 0;
                    if (!mi.fetch_pos(0, out start, out end) || is_inside_xml_comment(start)) {
                        continue;
                    }

                    body = mi.fetch(1);
                    var item_regex = new Regex("<name>([^<]*)</name>");
                    MatchInfo item;
                    if (item_regex.match(body, 0, out item) && item.matches()) {
                        do {
                            out += xml_unescape(item.fetch(1));
                        } while (item.next());
                    }
                    return out;
                } while (mi.next());
            }

            var desktops_regex = new Regex("(?s)<desktops[^>]*>(.*?)</desktops>");
            MatchInfo di;
            if (!desktops_regex.match(content, 0, out di) || !di.matches()) {
                return out;
            }

            do {
                int start = 0;
                int end = 0;
                if (!di.fetch_pos(0, out start, out end) || is_inside_xml_comment(start)) {
                    continue;
                }

                string desktops_body = di.fetch(1);
                var direct_name_regex = new Regex("<name>([^<]*)</name>");
                MatchInfo direct_item;
                if (direct_name_regex.match(desktops_body, 0, out direct_item) && direct_item.matches()) {
                    do {
                        out += xml_unescape(direct_item.fetch(1));
                    } while (direct_item.next());
                }
                return out;
            } while (di.next());
        } catch (Error e) {
        }
        return out;
    }

    public void set_desktops_names(string[] names) {
        ensure_section_block("desktops");

        var sb = new StringBuilder();
        for (int i = 0; i < names.length; i++) {
            string n = names[i].strip();
            if (n != "") {
                sb.append("<name>").append(Markup.escape_text(n, -1)).append("</name>");
            }
        }

        string replacement = "<names>" + sb.str + "</names>";
        try {
            var section_regex = new Regex("(?s)(<desktops[^>]*>)(.*?)(</desktops>)");
            MatchInfo si;
            if (!section_regex.match(content, 0, out si) || !si.matches()) {
                return;
            }

            bool found_active = false;
            do {
                int section_start = 0;
                int section_end = 0;
                if (si.fetch_pos(0, out section_start, out section_end) && !is_inside_xml_comment(section_start)) {
                    found_active = true;
                    break;
                }
            } while (si.next());
            if (!found_active) {
                return;
            }

            int body_start = 0;
            int body_end = 0;
            if (!si.fetch_pos(2, out body_start, out body_end)) {
                return;
            }

            string body = content.substring(body_start, body_end - body_start);
            bool replaced = false;
            var names_regex = new Regex("(?s)<names>.*?</names>");
            MatchInfo nmi;
            if (names_regex.match(body, 0, out nmi) && nmi.matches()) {
                do {
                    int ns = 0;
                    int ne = 0;
                    if (!nmi.fetch_pos(0, out ns, out ne) || is_inside_xml_comment(body_start + ns)) {
                        continue;
                    }
                    body = body.substring(0, ns) + replacement + body.substring(ne);
                    replaced = true;
                    break;
                } while (nmi.next());
            }

            if (!replaced) {
                var direct_names_regex = new Regex("(?s)(<name>[^<]*</name>\\s*)+");
                MatchInfo dmi;
                if (direct_names_regex.match(body, 0, out dmi) && dmi.matches()) {
                    do {
                        int ds = 0;
                        int de = 0;
                        if (!dmi.fetch_pos(0, out ds, out de) || is_inside_xml_comment(body_start + ds)) {
                            continue;
                        }
                        body = body.substring(0, ds) + replacement + body.substring(de);
                        replaced = true;
                        break;
                    } while (dmi.next());
                }
            }

            if (!replaced) {
                body += replacement;
            }

            content = content.substring(0, body_start) + body + content.substring(body_end);
        } catch (Error e) {
        }
    }

    public int get_margin_top() {
        return parse_int_or_default(get_margin_attr("top", "0"), 0);
    }

    public int get_margin_bottom() {
        return parse_int_or_default(get_margin_attr("bottom", "0"), 0);
    }

    public int get_margin_left() {
        return parse_int_or_default(get_margin_attr("left", "0"), 0);
    }

    public int get_margin_right() {
        return parse_int_or_default(get_margin_attr("right", "0"), 0);
    }

    public void set_margins(int top, int bottom, int left, int right) {
        if (top < 0) top = 0;
        if (bottom < 0) bottom = 0;
        if (left < 0) left = 0;
        if (right < 0) right = 0;

        if (get_margin_top() == top && get_margin_bottom() == bottom && get_margin_left() == left && get_margin_right() == right) {
            return;
        }

        ensure_margin_tag();
        string replacement = "<margin top=\"" + top.to_string() + "\" bottom=\"" + bottom.to_string() + "\" left=\"" + left.to_string() + "\" right=\"" + right.to_string() + "\" />";
        try {
            var regex = new Regex("<margin\\b[^>]*>");
            MatchInfo mi;
            if (regex.match(content, 0, out mi) && mi.matches()) {
                int start = 0;
                int end = 0;
                if (mi.fetch_pos(0, out start, out end)) {
                    content = content.substring(0, start) + replacement + content.substring(end);
                }
            }
        } catch (Error e) {
        }
    }
    
    public string get_gtk_theme_name() {
        if (!FileUtils.test(settings_path, FileTest.EXISTS)) return "Greybird";
        try {
            string c;
            FileUtils.get_contents(settings_path, out c);
            foreach (string line in c.split("\n")) {
                if (line.has_prefix("gtk-theme-name=")) {
                    return line.substring("gtk-theme-name=".length).strip();
                }
            }
        } catch (Error e) {}
        return "Greybird";
    }
    
    public void set_gtk_theme_name(string name) {
        try {
            string c = "";
            if (FileUtils.test(settings_path, FileTest.EXISTS)) {
                FileUtils.get_contents(settings_path, out c);
            }

            bool has_settings_group = false;
            bool found_key = false;
            string[] lines = c.split("\n");
            var sb = new StringBuilder();

            for (int i = 0; i < lines.length; i++) {
                string line = lines[i];
                string stripped = line.strip();

                if (stripped == "[Settings]") {
                    has_settings_group = true;
                    sb.append(line).append("\n");
                    continue;
                }

                if (stripped.has_prefix("[") && stripped.has_suffix("]") && has_settings_group && !found_key) {
                    sb.append("gtk-theme-name=").append(name).append("\n");
                    found_key = true;
                }

                if (stripped.has_prefix("gtk-theme-name=")) {
                    sb.append("gtk-theme-name=").append(name).append("\n");
                    found_key = true;
                } else {
                    sb.append(line).append("\n");
                }
            }

            if (!has_settings_group) {
                if (sb.len > 0 && !sb.str.has_suffix("\n")) {
                    sb.append("\n");
                }
                sb.append("[Settings]\n");
            }

            if (!found_key) {
                if (sb.len > 0 && !sb.str.has_suffix("\n")) {
                    sb.append("\n");
                }
                sb.append("gtk-theme-name=").append(name).append("\n");
            }

            FileUtils.set_contents(settings_path, sb.str);
        } catch (Error e) {}
    }
}

public class FontConfig : Object {
    public string name { get; set; }
    public int size { get; set; }
    
    public FontConfig() {
        name = "DejaVu Sans";
        size = 10;
    }
}
