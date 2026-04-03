/* backup.vala - Pre-session backup */

public class Backup : Object {
    public string backup_dir { get; private set; }
    public string pre_session_dir { get; private set; }
    
    private string rc_source;
    private string settings_source;
    private string autostart_source;
    private string environment_source;
    
    public Backup() {
        backup_dir = Path.build_filename(Environment.get_home_dir(), ".config", "labwc", "backup");
        pre_session_dir = Path.build_filename(backup_dir, "pre-session");
        
        string? xdg_config_home = Environment.get_variable("XDG_CONFIG_HOME");
        string config_base = (xdg_config_home != null && xdg_config_home.strip() != "")
            ? xdg_config_home.strip()
            : Path.build_filename(Environment.get_home_dir(), ".config");

        rc_source = Path.build_filename(config_base, "labwc", "rc.xml");
        settings_source = Path.build_filename(config_base, "gtk-3.0", "settings.ini");
        autostart_source = Path.build_filename(config_base, "labwc", "autostart");
        environment_source = Path.build_filename(config_base, "labwc", "environment");
        
        DirUtils.create_with_parents(pre_session_dir, 0755);
    }
    
    public bool create_pre_session_backup() {
        string rc_backup = Path.build_filename(pre_session_dir, "rc.xml");
        if (FileUtils.test(rc_backup, FileTest.EXISTS)) {
            return true;
        }
        
        try {
            if (FileUtils.test(rc_source, FileTest.EXISTS)) {
                string content;
                FileUtils.get_contents(rc_source, out content);
                FileUtils.set_contents(rc_backup, content);
            }
            
            if (FileUtils.test(settings_source, FileTest.EXISTS)) {
                string content;
                FileUtils.get_contents(settings_source, out content);
                FileUtils.set_contents(Path.build_filename(pre_session_dir, "settings.ini"), content);
            }
            
            if (FileUtils.test(autostart_source, FileTest.EXISTS)) {
                string content;
                FileUtils.get_contents(autostart_source, out content);
                FileUtils.set_contents(Path.build_filename(pre_session_dir, "autostart"), content);
            }

            if (FileUtils.test(environment_source, FileTest.EXISTS)) {
                string content;
                FileUtils.get_contents(environment_source, out content);
                FileUtils.set_contents(Path.build_filename(pre_session_dir, "environment"), content);
            }
            
            return true;
        } catch (Error e) {
            return false;
        }
    }
    
    public bool restore_from_pre_session() {
        try {
            string rc_backup = Path.build_filename(pre_session_dir, "rc.xml");
            if (FileUtils.test(rc_backup, FileTest.EXISTS)) {
                string content;
                FileUtils.get_contents(rc_backup, out content);
                FileUtils.set_contents(rc_source, content);
            }
            
            string settings_backup = Path.build_filename(pre_session_dir, "settings.ini");
            if (FileUtils.test(settings_backup, FileTest.EXISTS)) {
                string content;
                FileUtils.get_contents(settings_backup, out content);
                FileUtils.set_contents(settings_source, content);
            }
            
            string autostart_backup = Path.build_filename(pre_session_dir, "autostart");
            if (FileUtils.test(autostart_backup, FileTest.EXISTS)) {
                string content;
                FileUtils.get_contents(autostart_backup, out content);
                FileUtils.set_contents(autostart_source, content);
            }

            string environment_backup = Path.build_filename(pre_session_dir, "environment");
            if (FileUtils.test(environment_backup, FileTest.EXISTS)) {
                string content;
                FileUtils.get_contents(environment_backup, out content);
                FileUtils.set_contents(environment_source, content);
            }
            
            return true;
        } catch (Error e) {
            return false;
        }
    }
}
