/* themes.vala - Scan available themes */

public class ThemeInfo : Object {
    public string name { get; set; }
    public string path { get; set; }
    public bool has_openbox { get; set; }
    public bool has_gtk3 { get; set; }
    
    public ThemeInfo(string n, string p) {
        name = n;
        path = p;
    }
}

public class ThemeScanner : Object {
    public string[] themes { get; private set; }
    
    public ThemeScanner() {
        themes = {};
    }
    
    public void scan() {
        string[] names = {};

        scan_directory("/usr/share/themes", ref names);
        string home_themes = Path.build_filename(Environment.get_home_dir(), ".themes");
        scan_directory(home_themes, ref names);

        sort_names(ref names);
        themes = names;
    }

    private void scan_directory(string dir_path, ref string[] names) {
        if (!FileUtils.test(dir_path, FileTest.IS_DIR)) return;

        try {
            Dir dir = Dir.open(dir_path);
            string? name;
            while ((name = dir.read_name()) != null) {
                if (name.has_prefix(".")) continue;

                string full_path = Path.build_filename(dir_path, name);
                if (FileUtils.test(full_path, FileTest.IS_DIR) && is_theme(full_path)) {
                    if (!contains_name(names, name)) {
                        names = append_name(names, name);
                    }
                }
            }
        } catch (Error e) {}
    }

    private string[] append_name(string[] names, string value) {
        string[] out = new string[names.length + 1];
        for (int i = 0; i < names.length; i++) {
            out[i] = names[i];
        }
        out[names.length] = value;
        return out;
    }

    private bool contains_name(string[] names, string target) {
        for (int i = 0; i < names.length; i++) {
            if (names[i] == target) {
                return true;
            }
        }
        return false;
    }

    private void sort_names(ref string[] names) {
        for (int i = 0; i < names.length - 1; i++) {
            for (int j = i + 1; j < names.length; j++) {
                if (strcmp(names[i], names[j]) > 0) {
                    string tmp = names[i];
                    names[i] = names[j];
                    names[j] = tmp;
                }
            }
        }
    }
    
    private bool is_theme(string path) {
        return FileUtils.test(Path.build_filename(path, "openbox-3", "themerc"), FileTest.EXISTS);
    }
    
    public string? get_theme_path(string name) {
        string system_theme = Path.build_filename("/usr/share/themes", name);
        if (FileUtils.test(system_theme, FileTest.IS_DIR)) {
            return system_theme;
        }

        string user_theme = Path.build_filename(Environment.get_home_dir(), ".themes", name);
        if (FileUtils.test(user_theme, FileTest.IS_DIR)) {
            return user_theme;
        }
        return null;
    }
}
