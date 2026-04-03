/* main.vala - Labconf */
using Gtk;

private string tr(string s) {
    return GLib.dgettext("labconf", s);
}

public class ThemeSelector : Window {
    public enum StartupTab {
        DEFAULT,
        KEYBOARD
    }

    private class FormSnapshot : Object {
        public int corner_radius = 0;
        public bool keep_border = false;
        public bool show_title = false;
        public bool drop_shadows = false;
        public bool drop_shadows_on_tiled = false;
        public string title_layout = "";
        public string[] font_names = {};
        public int focus_delay = 0;
        public bool follow_mouse = false;
        public bool follow_mouse_requires_movement = false;
        public bool raise_on_focus = false;
        public int double_click_time = 0;
        public bool window_switcher_show = false;
        public string window_switcher_style = "";
        public string window_switcher_output = "";
        public string window_switcher_thumbnail_label = "";
        public string resize_popup_show = "";
        public bool resize_draw_contents = false;
        public int resize_corner_range = 0;
        public int resize_minimum_area = 0;
        public bool desktops_popup = false;
        public int desktops_popup_time = 0;
        public int desktops_number = 0;
        public string desktops_prefix = "";
        public string desktops_names_text_norm = "";
        public int margin_top = 0;
        public int margin_bottom = 0;
        public int margin_left = 0;
        public int margin_right = 0;
        public string placement_policy = "";
        public string placement_monitor = "";
        public int placement_cascade_x = 0;
        public int placement_cascade_y = 0;
        public string xkb_layout = "";
        public string xkb_options = "";
        public string xcursor_size = "";
        public bool wlr_no_hardware_cursors = false;
        public bool java_nonreparenting_zero = false;
        public bool moz_enable_wayland = false;
        public string xdg_current_desktop = "";
        public string fallback_output = "";
        public string custom_environment = "";
    }

    private Config config;
    private EnvironmentConfig environment_config;
    private ThemeScanner theme_scanner;
    private Backup backup;
    private Notebook notebook;
    private Widget? keyboard_tab_page = null;
    private ListBox theme_list;
    private ScrolledWindow theme_list_scrolled;
    private SpinButton corner_radius_spin;
    private CheckButton keep_border_check;
    private CheckButton show_title_check;
    private Entry title_layout_entry;
    private FontButton[] font_buttons;
    private SpinButton focus_delay_spin;
    private CheckButton follow_mouse_check;
    private CheckButton follow_mouse_requires_movement_check;
    private CheckButton raise_on_focus_check;
    private SpinButton double_click_time_spin;
    private ComboBoxText placement_policy_combo;
    private ComboBoxText placement_monitor_combo;
    private SpinButton placement_cascade_x_spin;
    private SpinButton placement_cascade_y_spin;
    private CheckButton window_switcher_show_check;
    private ComboBoxText window_switcher_style_combo;
    private ComboBoxText window_switcher_output_combo;
    private Entry window_switcher_thumbnail_label_entry;
    private ComboBoxText resize_popup_show_combo;
    private CheckButton resize_draw_contents_check;
    private SpinButton resize_corner_range_spin;
    private SpinButton resize_minimum_area_spin;
    private CheckButton drop_shadows_check;
    private CheckButton drop_shadows_on_tiled_check;
    private CheckButton desktops_popup_check;
    private SpinButton desktops_popup_time_spin;
    private SpinButton desktops_number_spin;
    private Entry desktops_prefix_entry;
    private TextView desktops_names_view;
    private SpinButton margin_top_spin;
    private SpinButton margin_bottom_spin;
    private SpinButton margin_left_spin;
    private SpinButton margin_right_spin;
    private Button preview_btn;
    private Button ok_btn;
    private Label status_label;
    private Entry xkb_layout_entry;
    private ComboBoxText xkb_options_combo;
    private Entry xkb_options_entry;
    private Entry xcursor_size_entry;
    private CheckButton wlr_no_hardware_cursors_check;
    private CheckButton java_nonreparenting_disable_check;
    private CheckButton moz_enable_wayland_check;
    private Entry xdg_current_desktop_entry;
    private Entry fallback_output_entry;
    private TextView custom_environment_view;
    private ScrolledWindow custom_environment_scrolled;
    private Frame custom_environment_frame;
    private Button reset_custom_btn;
    private bool has_changes = false;
    private bool is_loading_settings = false;
    private bool is_exiting = false;
    private bool save_confirmed = false;
    private string initial_theme_name = "Greybird";
    private string live_applied_theme_name = "";
    private string selected_theme_name = "";
    private bool title_layout_dirty = false;
    private FormSnapshot initial_state = new FormSnapshot();
    private bool debug_enabled = false;
    private uint apply_font_popover_timeout_id = 0;
    private bool syncing_xkb_options = false;
    private StartupTab startup_tab = StartupTab.DEFAULT;
    private bool preview_applied = false;
    private string initial_rc_content = "";
    private string initial_env_content = "";
    private bool initial_env_exists = false;

    private void debug_log(string msg) {
        if (!debug_enabled) {
            return;
        }
        string line = "[" + (new DateTime.now_local()).format("%F %T") + "] " + msg + "\n";
        FileStream? f = FileStream.open("/tmp/labconf-debug.log", "a");
        if (f != null) {
            f.puts(line);
        }
    }

    private const int ROW_LABEL_CHARS = 18;
    private const int CONTROL_WIDTH_SHORT = 170;
    private const int CONTROL_WIDTH_WIDE = 250;

    public ThemeSelector(bool debug = false, StartupTab start_tab = StartupTab.DEFAULT) {
        Object(title: tr("Labwc Configuration Manager"), default_width: 792, default_height: 655, border_width: 8, resizable: true);
        debug_enabled = debug;
        startup_tab = start_tab;
        destroy.connect(Gtk.main_quit);
        delete_event.connect((event) => {
            if (!save_confirmed) {
                revert_session();
            }
            return false;
        });
        config = new Config();
        environment_config = new EnvironmentConfig();
        backup = new Backup();
        theme_scanner = new ThemeScanner();
        if (!backup.create_pre_session_backup()) {
            debug_log("pre-session backup creation failed");
        }
        config.load();
        environment_config.load();
        theme_scanner.scan();
        apply_lxde_style();
        create_ui();
        load_settings();
        capture_initial_state();
        apply_startup_tab();
    }

    private void apply_startup_tab() {
        if (notebook == null) {
            return;
        }
        if (startup_tab == StartupTab.KEYBOARD) {
            Idle.add(() => {
                int idx = -1;
                if (keyboard_tab_page != null) {
                    idx = notebook.page_num(keyboard_tab_page);
                }
                if (idx < 0) {
                    idx = 8;
                }
                notebook.set_current_page(idx);
                return Source.REMOVE;
            });
        }
    }

    private void apply_lxde_style() {
        try {
            var provider = new CssProvider();
            provider.load_from_data(
                ".labconf-window {\n" +
                "  background: shade(@theme_bg_color, 1.01);\n" +
                "}\n" +
                ".labconf-tab-label {\n" +
                "  padding: 3px 8px;\n" +
                "}\n" +
                ".labconf-section-title {\n" +
                "  font-weight: bold;\n" +
                "  margin-top: 2px;\n" +
                "}\n" +
                ".labconf-intro {\n" +
                "  color: alpha(@theme_fg_color, 0.8);\n" +
                "  font-size: 0.95em;\n" +
                "}\n" +
                ".labconf-status {\n" +
                "  color: alpha(@theme_fg_color, 0.8);\n" +
                "  font-size: 0.95em;\n" +
                "  padding: 2px 4px;\n" +
                "}\n" +
                ".labconf-changed {\n" +
                "  background-color: alpha(@theme_selected_bg_color, 0.32);\n" +
                "  border: 1px solid alpha(@theme_selected_bg_color, 0.95);\n" +
                "  border-radius: 4px;\n" +
                "}\n" +
                "scrolledwindow.labconf-changed,\n" +
                "scrolledwindow.labconf-changed > viewport,\n" +
                "textview.labconf-changed,\n" +
                "textview.labconf-changed text,\n" +
                "entry.labconf-changed,\n" +
                "spinbutton.labconf-changed,\n" +
                "combobox.labconf-changed,\n" +
                "button.labconf-changed,\n" +
                "checkbutton.labconf-changed,\n" +
                "frame.labconf-changed {\n" +
                "  background-color: alpha(@theme_selected_bg_color, 0.22);\n" +
                "  border-color: alpha(@theme_selected_bg_color, 0.85);\n" +
                "}\n"
            );
            StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                provider,
                STYLE_PROVIDER_PRIORITY_APPLICATION
            );
            get_style_context().add_class("labconf-window");
        } catch (Error e) {
        }
    }

    private Widget create_tab_label(string text) {
        var label = new Label(text);
        label.xalign = 0;
        label.get_style_context().add_class("labconf-tab-label");
        return label;
    }

    private string sanitize_title_layout(string raw) {
        string value = raw.strip().up();

        // Normalize common Cyrillic lookalikes to ASCII latin letters.
        value = value.replace("А", "A");
        value = value.replace("В", "B");
        value = value.replace("С", "C");
        value = value.replace("Е", "E");
        value = value.replace("Н", "H");
        value = value.replace("К", "K");
        value = value.replace("М", "M");
        value = value.replace("О", "O");
        value = value.replace("Р", "P");
        value = value.replace("Т", "T");
        value = value.replace("Х", "X");
        value = value.replace("І", "I");

        string cleaned = value;
        try {
            var invalid = new Regex("[^NLIMCSD]");
            cleaned = invalid.replace(value, value.length, 0, "");
        } catch (Error e) {
            cleaned = value;
        }

        if (cleaned == "") {
            return "NLIMC";
        }
        return cleaned;
    }

    private void on_change() {
        has_changes = true;
        update_field_states();
        update_action_buttons();
        update_status();
    }

    private void update_action_buttons() {
        if (ok_btn != null) {
            ok_btn.set_sensitive(has_changes || preview_applied);
        }
        if (preview_btn != null) {
            preview_btn.set_sensitive(has_changes);
        }
    }

    private void capture_initial_state() {
        initial_rc_content = read_file_or_empty(config.rc_path);
        initial_env_exists = FileUtils.test(environment_config.environment_path, FileTest.EXISTS);
        initial_env_content = read_file_or_empty(environment_config.environment_path);
    }

    private void set_changed_style(Widget widget, bool changed) {
        var ctx = widget.get_style_context();
        if (changed) {
            ctx.add_class("labconf-changed");
        } else {
            ctx.remove_class("labconf-changed");
        }
    }

    private Button create_reset_button() {
        var btn = new Button.with_label(tr("Reset"));
        btn.halign = Align.START;
        btn.set_tooltip_text(tr("Reset this variable to the loaded value."));
        return btn;
    }

    private void update_field_states() {
        if (theme_list_scrolled != null) {
            set_changed_style(theme_list_scrolled, get_selected_theme() != initial_theme_name);
        }

        if (corner_radius_spin != null) {
            set_changed_style(corner_radius_spin, (int)corner_radius_spin.get_value() != initial_state.corner_radius);
        }
        if (keep_border_check != null) {
            set_changed_style(keep_border_check, keep_border_check.get_active() != initial_state.keep_border);
        }
        if (show_title_check != null) {
            set_changed_style(show_title_check, show_title_check.get_active() != initial_state.show_title);
        }
        if (drop_shadows_check != null) {
            set_changed_style(drop_shadows_check, drop_shadows_check.get_active() != initial_state.drop_shadows);
        }
        if (drop_shadows_on_tiled_check != null) {
            set_changed_style(drop_shadows_on_tiled_check, drop_shadows_on_tiled_check.get_active() != initial_state.drop_shadows_on_tiled);
        }
        if (title_layout_entry != null) {
            set_changed_style(title_layout_entry, sanitize_title_layout(title_layout_entry.get_text()) != initial_state.title_layout);
        }
        if (font_buttons != null && initial_state.font_names.length == font_buttons.length) {
            for (int i = 0; i < font_buttons.length; i++) {
                set_changed_style(font_buttons[i], font_buttons[i].get_font() != initial_state.font_names[i]);
            }
        }

        if (focus_delay_spin != null) {
            set_changed_style(focus_delay_spin, (int)focus_delay_spin.get_value() != initial_state.focus_delay);
        }
        if (follow_mouse_check != null) {
            set_changed_style(follow_mouse_check, follow_mouse_check.get_active() != initial_state.follow_mouse);
        }
        if (follow_mouse_requires_movement_check != null) {
            set_changed_style(follow_mouse_requires_movement_check, follow_mouse_requires_movement_check.get_active() != initial_state.follow_mouse_requires_movement);
        }
        if (raise_on_focus_check != null) {
            set_changed_style(raise_on_focus_check, raise_on_focus_check.get_active() != initial_state.raise_on_focus);
        }

        if (double_click_time_spin != null) {
            set_changed_style(double_click_time_spin, (int)double_click_time_spin.get_value() != initial_state.double_click_time);
        }

        if (placement_policy_combo != null) {
            string policy = placement_policy_combo.get_active_id() ?? "";
            set_changed_style(placement_policy_combo, policy != initial_state.placement_policy);
        }
        if (placement_monitor_combo != null) {
            string monitor = placement_monitor_combo.get_active_id() ?? "";
            set_changed_style(placement_monitor_combo, monitor != initial_state.placement_monitor);
        }
        if (placement_cascade_x_spin != null) {
            set_changed_style(placement_cascade_x_spin, (int)placement_cascade_x_spin.get_value() != initial_state.placement_cascade_x);
        }
        if (placement_cascade_y_spin != null) {
            set_changed_style(placement_cascade_y_spin, (int)placement_cascade_y_spin.get_value() != initial_state.placement_cascade_y);
        }

        if (resize_popup_show_combo != null) {
            string popup = resize_popup_show_combo.get_active_id() ?? "";
            set_changed_style(resize_popup_show_combo, popup != initial_state.resize_popup_show);
        }
        if (resize_draw_contents_check != null) {
            set_changed_style(resize_draw_contents_check, resize_draw_contents_check.get_active() != initial_state.resize_draw_contents);
        }
        if (resize_corner_range_spin != null) {
            set_changed_style(resize_corner_range_spin, (int)resize_corner_range_spin.get_value() != initial_state.resize_corner_range);
        }
        if (resize_minimum_area_spin != null) {
            set_changed_style(resize_minimum_area_spin, (int)resize_minimum_area_spin.get_value() != initial_state.resize_minimum_area);
        }

        if (window_switcher_show_check != null) {
            set_changed_style(window_switcher_show_check, window_switcher_show_check.get_active() != initial_state.window_switcher_show);
        }
        if (window_switcher_style_combo != null) {
            string style = window_switcher_style_combo.get_active_id() ?? "";
            set_changed_style(window_switcher_style_combo, style != initial_state.window_switcher_style);
        }
        if (window_switcher_output_combo != null) {
            string output = window_switcher_output_combo.get_active_id() ?? "";
            set_changed_style(window_switcher_output_combo, output != initial_state.window_switcher_output);
        }
        if (window_switcher_thumbnail_label_entry != null) {
            set_changed_style(window_switcher_thumbnail_label_entry, window_switcher_thumbnail_label_entry.get_text().strip() != initial_state.window_switcher_thumbnail_label);
        }

        if (desktops_popup_check != null) {
            set_changed_style(desktops_popup_check, desktops_popup_check.get_active() != initial_state.desktops_popup);
        }
        if (desktops_popup_time_spin != null) {
            set_changed_style(desktops_popup_time_spin, (int)desktops_popup_time_spin.get_value() != initial_state.desktops_popup_time);
        }
        if (desktops_number_spin != null) {
            set_changed_style(desktops_number_spin, (int)desktops_number_spin.get_value() != initial_state.desktops_number);
        }
        if (desktops_prefix_entry != null) {
            set_changed_style(desktops_prefix_entry, desktops_prefix_entry.get_text().strip() != initial_state.desktops_prefix);
        }
        if (desktops_names_view != null) {
            set_changed_style(desktops_names_view, normalize_desktop_names_text() != initial_state.desktops_names_text_norm);
        }

        if (margin_top_spin != null) {
            set_changed_style(margin_top_spin, (int)margin_top_spin.get_value() != initial_state.margin_top);
        }
        if (margin_bottom_spin != null) {
            set_changed_style(margin_bottom_spin, (int)margin_bottom_spin.get_value() != initial_state.margin_bottom);
        }
        if (margin_left_spin != null) {
            set_changed_style(margin_left_spin, (int)margin_left_spin.get_value() != initial_state.margin_left);
        }
        if (margin_right_spin != null) {
            set_changed_style(margin_right_spin, (int)margin_right_spin.get_value() != initial_state.margin_right);
        }

        if (xkb_layout_entry != null) {
            set_changed_style(xkb_layout_entry, xkb_layout_entry.get_text().strip() != initial_state.xkb_layout);
        }

        if (xkb_options_entry != null) {
            string current_options = environment_config.normalize_csv_value(xkb_options_entry.get_text());
            set_changed_style(xkb_options_entry, current_options != initial_state.xkb_options);
        }

        if (xcursor_size_entry != null) {
            set_changed_style(xcursor_size_entry, xcursor_size_entry.get_text().strip() != initial_state.xcursor_size);
        }

        if (wlr_no_hardware_cursors_check != null) {
            set_changed_style(wlr_no_hardware_cursors_check, wlr_no_hardware_cursors_check.get_active() != initial_state.wlr_no_hardware_cursors);
        }

        if (java_nonreparenting_disable_check != null) {
            set_changed_style(java_nonreparenting_disable_check, java_nonreparenting_disable_check.get_active() != initial_state.java_nonreparenting_zero);
        }

        if (moz_enable_wayland_check != null) {
            set_changed_style(moz_enable_wayland_check, moz_enable_wayland_check.get_active() != initial_state.moz_enable_wayland);
        }

        if (xdg_current_desktop_entry != null) {
            set_changed_style(xdg_current_desktop_entry, xdg_current_desktop_entry.get_text().strip() != initial_state.xdg_current_desktop);
        }

        if (fallback_output_entry != null) {
            set_changed_style(fallback_output_entry, fallback_output_entry.get_text().strip() != initial_state.fallback_output);
        }

        if (custom_environment_view != null) {
            TextIter start;
            TextIter end;
            custom_environment_view.get_buffer().get_bounds(out start, out end);
            string text = custom_environment_view.get_buffer().get_text(start, end, false);
            bool changed = text != initial_state.custom_environment;
            set_changed_style(custom_environment_view, changed);
            if (custom_environment_scrolled != null) {
                set_changed_style(custom_environment_scrolled, changed);
            }
            if (custom_environment_frame != null) {
                set_changed_style(custom_environment_frame, changed);
            }
            if (reset_custom_btn != null) {
                reset_custom_btn.set_sensitive(changed);
            }
        }
    }

    private void create_ui() {
        var root = new Box(Orientation.VERTICAL, 6);
        add(root);

        notebook = new Notebook();
        notebook.set_tab_pos(PositionType.LEFT);
        notebook.set_scrollable(true);
        notebook.set_show_border(true);
        notebook.set_border_width(0);
        notebook.append_page(create_theme_tab(), create_tab_label(tr("Theme")));
        notebook.append_page(create_fonts_tab(), create_tab_label(tr("Appearance")));
        notebook.append_page(create_focus_tab(), create_tab_label(tr("Focus")));
        notebook.append_page(create_placement_tab(), create_tab_label(tr("Windows")));
        notebook.append_page(create_mouse_tab(), create_tab_label(tr("Mouse")));
        notebook.append_page(create_desktops_tab(), create_tab_label(tr("Desktops")));
        notebook.append_page(create_margins_tab(), create_tab_label(tr("Margins")));
        notebook.append_page(create_osd_tab(), create_tab_label(tr("Window switcher")));
        keyboard_tab_page = create_environment_keyboard_tab();
        notebook.append_page(keyboard_tab_page, create_tab_label(tr("Keyboard")));
        notebook.append_page(create_environment_cursor_tab(), create_tab_label(tr("Mouse cursor")));
        notebook.append_page(create_environment_compatibility_tab(), create_tab_label(tr("Compatibility")));
        notebook.append_page(create_environment_desktop_tab(), create_tab_label(tr("Desktop / Portal")));
        notebook.append_page(create_environment_output_tab(), create_tab_label(tr("Virtual output")));
        notebook.append_page(create_environment_custom_tab(), create_tab_label(tr("Custom")));

        root.pack_start(notebook, true, true, 0);

        status_label = new Label("");
        status_label.xalign = 1;
        status_label.halign = Align.FILL;
        status_label.get_style_context().add_class("labconf-status");
        root.pack_start(status_label, false, false, 0);

        var buttons = new ButtonBox(Orientation.HORIZONTAL);
        buttons.set_layout(ButtonBoxStyle.END);
        buttons.set_spacing(4);
        root.pack_start(buttons, false, false, 0);

        var button_sizes = new SizeGroup(SizeGroupMode.HORIZONTAL);

        var cancel_btn = new Button.with_label(tr("Cancel"));
        cancel_btn.set_image(new Image.from_icon_name("window-close", IconSize.BUTTON));
        cancel_btn.set_always_show_image(true);
        cancel_btn.clicked.connect((b) => {
            if (preview_applied) {
                restore_initial_state();
                config.load();
                environment_config.load();
                load_settings();
                status_label.set_text(tr("Preview reverted. Continue editing or press OK to save new changes."));
                return;
            }
            revert_session();
            Gtk.main_quit();
        });
        button_sizes.add_widget(cancel_btn);
        buttons.add(cancel_btn);

        preview_btn = new Button.with_label(tr("Preview"));
        preview_btn.set_image(new Image.from_icon_name("system-run-symbolic", IconSize.BUTTON));
        preview_btn.set_always_show_image(true);
        preview_btn.set_tooltip_text(tr("Apply current unsaved settings temporarily. Use OK to keep or Cancel to revert."));
        preview_btn.clicked.connect((b) => apply_preview_changes());
        button_sizes.add_widget(preview_btn);
        buttons.add(preview_btn);

        ok_btn = new Button.with_label(tr("OK"));
        ok_btn.set_image(new Image.from_icon_name("dialog-ok", IconSize.BUTTON));
        ok_btn.set_always_show_image(true);
        ok_btn.set_sensitive(false);
        ok_btn.clicked.connect((b) => {
            save_settings();
            config.save();
            environment_config.save();
            run_labwc_reconfigure();
            save_confirmed = true;
            Gtk.main_quit();
        });
        button_sizes.add_widget(ok_btn);
        buttons.add(ok_btn);

        update_action_buttons();
        update_status();
    }

    private void update_status() {
        if (status_label == null) {
            return;
        }

        if (preview_applied) {
            if (has_changes) {
                status_label.set_text(tr("Preview outdated. Press Preview to apply current changes."));
            } else {
                status_label.set_text(tr("Preview active. Press OK to keep changes or Cancel to revert."));
            }
            return;
        }

        string selected = get_selected_theme();
        if (selected == "") {
            status_label.set_text(tr("Select a theme."));
            return;
        }

        if (selected == initial_theme_name) {
            status_label.set_text(tr("Current theme") + ": " + selected);
        } else {
            status_label.set_text(tr("Temporarily applied") + ": " + selected + " (" + tr("OK saves, Cancel restores") + " " + initial_theme_name + ")");
        }
    }

    private void run_labwc_reconfigure() {
        bool run_cmd(string cmd) {
            try {
                string out_text;
                string err_text;
                int status = 1;
                Process.spawn_command_line_sync(cmd, out out_text, out err_text, out status);
                debug_log("reconfigure cmd='" + cmd + "' status=" + status.to_string());
                return status == 0;
            } catch (Error e) {
                debug_log("reconfigure cmd='" + cmd + "' exception=" + e.message);
                return false;
            }
        }

        string? cmd = Environment.get_variable("LABCONF_RECONFIGURE_CMD");
        if (cmd != null && cmd.strip() != "") {
            run_cmd(cmd.strip());
            return;
        }

        string? pid = Environment.get_variable("LABWC_PID");
        if (pid != null && pid.strip() != "") {
            if (run_cmd("kill -HUP " + pid.strip())) {
                return;
            }
        }

        if (run_cmd("labwc -r")) {
            return;
        }

        if (run_cmd("labwc --reconfigure")) {
            return;
        }

        run_cmd("pkill -HUP -x labwc");
    }

    private void revert_session() {
        if (is_exiting) {
            return;
        }
        is_exiting = true;
        restore_initial_state();
    }

    private void restore_initial_state() {
        bool changed = false;
        string current_rc = read_file_or_empty(config.rc_path);
        if (current_rc != initial_rc_content) {
            try {
                FileUtils.set_contents(config.rc_path, initial_rc_content);
                changed = true;
            } catch (Error e) {
                debug_log("restore_initial_state rc failed: " + e.message);
            }
        }

        string env_path = environment_config.environment_path;
        bool env_exists_now = FileUtils.test(env_path, FileTest.EXISTS);
        if (initial_env_exists) {
            string current_env = read_file_or_empty(env_path);
            if (!env_exists_now || current_env != initial_env_content) {
                try {
                    FileUtils.set_contents(env_path, initial_env_content);
                    changed = true;
                } catch (Error e) {
                    debug_log("restore_initial_state environment write failed: " + e.message);
                }
            }
        } else if (env_exists_now) {
            FileUtils.remove(env_path);
            changed = true;
        }

        if (changed) {
            run_labwc_reconfigure();
        }
    }

    private bool write_theme_to_rc(string theme_name) {
        if (!config.load()) {
            debug_log("write_theme_to_rc: load failed rc=" + config.rc_path);
            return false;
        }
        debug_log("write_theme_to_rc: rc=" + config.rc_path + " theme=" + theme_name);
        config.set_theme_name(theme_name);
        bool ok = config.save();
        debug_log("write_theme_to_rc: save=" + (ok ? "ok" : "fail"));
        return ok;
    }

    private void on_theme_selection_changed() {
        var row = theme_list.get_selected_row();
        if (row == null) {
            return;
        }
        var label = (Label)((ListBoxRow)row).get_child();
        string theme_name = label.get_text();
        selected_theme_name = theme_name;
        if (!is_loading_settings) {
            apply_live_theme(theme_name);
        }
        on_change();
    }

    private void apply_live_theme(string theme_name) {
        if (is_loading_settings || is_exiting) {
            return;
        }
        if (theme_name == "" || theme_name == live_applied_theme_name) {
            return;
        }
        if (write_theme_to_rc(theme_name)) {
            live_applied_theme_name = theme_name;
            debug_log("apply_live_theme: applied=" + theme_name);
            run_labwc_reconfigure();
            update_status();
        } else {
            debug_log("apply_live_theme: failed=" + theme_name);
        }
    }

    private string get_selected_theme() {
        var row = theme_list.get_selected_row();
        if (row != null) {
            var label = (Label)((ListBoxRow)row).get_child();
            return label.get_text();
        }

        Widget? focus = theme_list.get_focus_child();
        if (focus is ListBoxRow) {
            var focus_label = (Label)((ListBoxRow)focus).get_child();
            return focus_label.get_text();
        }

        if (selected_theme_name != "") {
            return selected_theme_name;
        }
        return initial_theme_name;
    }

    private Label make_row_label(string text) {
        var label = new Label(text);
        label.xalign = 0;
        label.halign = Align.START;
        label.margin_start = 14;
        label.width_chars = ROW_LABEL_CHARS;
        return label;
    }

    private Label make_section_header(string text) {
        var header = new Label("<b>" + text + "</b>");
        header.use_markup = true;
        header.xalign = 0;
        header.margin_bottom = 1;
        header.get_style_context().add_class("labconf-section-title");
        return header;
    }

    private Label make_section_intro(string text) {
        var intro = new Label(text);
        intro.xalign = 0;
        intro.margin_start = 14;
        intro.margin_bottom = 6;
        intro.set_line_wrap(true);
        intro.get_style_context().add_class("labconf-intro");
        return intro;
    }

    private void tune_control_width(Widget w) {
        if (w is SpinButton || w is ComboBoxText) {
            w.set_size_request(CONTROL_WIDTH_SHORT, -1);
        } else if (w is Entry || w is FontButton) {
            w.set_size_request(CONTROL_WIDTH_WIDE, -1);
        }
        w.halign = Align.START;
    }

    private void attach_separator(Grid grid, int row, int columns) {
        var sep = new Separator(Orientation.HORIZONTAL);
        sep.margin_top = 2;
        sep.margin_bottom = 2;
        grid.attach(sep, 0, row, columns, 1);
    }

    private void normalize_checkbutton(CheckButton cb) {
        cb.margin_start = 14;
        cb.halign = Align.START;
    }

    private Grid create_tab_grid() {
        var grid = new Grid();
        grid.set_row_spacing(5);
        grid.set_column_spacing(10);
        grid.set_margin_start(10);
        grid.set_margin_end(10);
        grid.set_margin_top(10);
        grid.set_margin_bottom(10);
        return grid;
    }

    private string[] get_desktop_names_from_view() {
        TextIter start_iter;
        TextIter end_iter;
        desktops_names_view.get_buffer().get_bounds(out start_iter, out end_iter);
        string names_text = desktops_names_view.get_buffer().get_text(start_iter, end_iter, false);
        return names_text.split("\n");
    }

    private string normalize_desktop_names_text() {
        string[] lines = get_desktop_names_from_view();
        var sb = new StringBuilder();
        for (int i = 0; i < lines.length; i++) {
            string v = lines[i].strip();
            if (v == "") {
                continue;
            }
            if (sb.len > 0) {
                sb.append("\n");
            }
            sb.append(v);
        }
        return sb.str;
    }

    private void set_desktop_names_to_view(string[] names) {
        var sb = new StringBuilder();
        for (int i = 0; i < names.length; i++) {
            string n = names[i].strip();
            if (n == "") {
                continue;
            }
            if (sb.len > 0) {
                sb.append("\n");
            }
            sb.append(n);
        }
        desktops_names_view.get_buffer().set_text(sb.str);
    }

    private void sync_desktop_names_with_count(int count) {
        if (count < 1) {
            count = 1;
        }
        string prefix = tr("Desktop");
        if (desktops_prefix_entry != null) {
            string custom = desktops_prefix_entry.get_text().strip();
            if (custom != "") {
                prefix = custom;
            }
        }
        string[] current = get_desktop_names_from_view();
        string[] names_out = {};
        for (int i = 0; i < count; i++) {
            if (i < current.length && current[i].strip() != "") {
                names_out += current[i].strip();
            } else {
                names_out += prefix + " " + (i + 1).to_string();
            }
        }
        set_desktop_names_to_view(names_out);
    }

    private Widget create_theme_tab() {
        var box = new Box(Orientation.VERTICAL, 6);
        box.margin_start = 8;
        box.margin_end = 8;
        box.margin_top = 8;
        box.margin_bottom = 8;

        var heading = make_section_header(tr("Theme"));
        box.pack_start(heading, false, false, 0);

        var intro = make_section_intro(tr("Select a theme from the list below."));
        box.pack_start(intro, false, false, 0);

        var subheading = new Label(tr("Available themes"));
        subheading.get_style_context().add_class("dim-label");
        subheading.xalign = 0;
        subheading.margin_start = 14;
        box.pack_start(subheading, false, false, 0);

        theme_list_scrolled = new ScrolledWindow(null, null);
        theme_list_scrolled.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        theme_list_scrolled.set_min_content_width(350);
        theme_list_scrolled.set_size_request(350, -1);
        theme_list_scrolled.margin_start = 14;
        theme_list_scrolled.halign = Align.START;
        theme_list_scrolled.vexpand = true;
        box.pack_start(theme_list_scrolled, true, true, 0);

        theme_list = new ListBox();
        theme_list.set_selection_mode(SelectionMode.SINGLE);
        theme_list.set_size_request(350, -1);
        theme_list_scrolled.add(theme_list);

        foreach (string theme_name in theme_scanner.themes) {
            var row = new ListBoxRow();
            var label = new Label(theme_name);
            label.xalign = 0;
            label.margin_start = 6;
            label.margin_top = 4;
            label.margin_bottom = 4;
            row.add(label);
            row.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
            string row_theme = theme_name;
            row.button_press_event.connect((event) => {
                selected_theme_name = row_theme;
                theme_list.select_row(row);
                if (!is_loading_settings) {
                    apply_live_theme(row_theme);
                }
                on_change();
                return false;
            });
            theme_list.add(row);
        }

        theme_list.row_selected.connect((row) => on_theme_selection_changed());
        theme_list.row_activated.connect((row) => on_theme_selection_changed());
        theme_list.selected_rows_changed.connect(() => on_theme_selection_changed());

        return create_scrolled(box);
    }

    private Widget create_fonts_tab() {
        var grid = create_tab_grid();

        var section = make_section_header(tr("Windows"));
        grid.attach(section, 0, 0, 3, 1);

        var intro = make_section_intro(tr("Configure window decorations and fonts."));
        grid.attach(intro, 0, 1, 3, 1);

        var label = make_row_label(tr("Corner radius:"));
        grid.attach(label, 0, 2, 1, 1);
        corner_radius_spin = new SpinButton.with_range(0, 50, 1);
        corner_radius_spin.value_changed.connect((s) => on_change());
        tune_control_width(corner_radius_spin);
        grid.attach(corner_radius_spin, 1, 2, 2, 1);

        keep_border_check = new CheckButton.with_label(tr("Keep border when maximized"));
        normalize_checkbutton(keep_border_check);
        keep_border_check.toggled.connect((s) => on_change());
        grid.attach(keep_border_check, 0, 3, 3, 1);

        show_title_check = new CheckButton.with_label(tr("Show titlebar when maximized"));
        normalize_checkbutton(show_title_check);
        show_title_check.toggled.connect((s) => on_change());
        grid.attach(show_title_check, 0, 4, 3, 1);

        label = make_row_label(tr("Title layout:"));
        grid.attach(label, 0, 5, 1, 1);
        title_layout_entry = new Entry();
        title_layout_entry.set_max_length(16);
        title_layout_entry.set_tooltip_text(tr("Use latin button codes like NIMC. Invalid characters are removed on save."));
        title_layout_entry.changed.connect((s) => {
            if (!is_loading_settings && title_layout_entry.has_focus) {
                title_layout_dirty = true;
            }
            on_change();
        });
        tune_control_width(title_layout_entry);
        grid.attach(title_layout_entry, 1, 5, 2, 1);

        drop_shadows_check = new CheckButton.with_label(tr("Drop shadows"));
        normalize_checkbutton(drop_shadows_check);
        drop_shadows_check.toggled.connect((s) => on_change());
        grid.attach(drop_shadows_check, 0, 6, 3, 1);

        drop_shadows_on_tiled_check = new CheckButton.with_label(tr("Drop shadows on tiled windows"));
        normalize_checkbutton(drop_shadows_on_tiled_check);
        drop_shadows_on_tiled_check.toggled.connect((s) => on_change());
        grid.attach(drop_shadows_on_tiled_check, 0, 7, 3, 1);

        var legend = new Label(
            "N: " + tr("Window icon") + "    I: " + tr("Iconify") + "    M: " + tr("Maximize") + "\n" +
            "L: " + tr("Window label") + "   C: " + tr("Close") + "    S: " + tr("Shade") + "    D: " + tr("All desktops")
        );
        legend.xalign = 0;
        legend.set_line_wrap(true);
        legend.margin_start = 14;
        grid.attach(legend, 0, 8, 3, 1);

        attach_separator(grid, 9, 3);

        var fonts_section = make_section_header(tr("Fonts"));
        grid.attach(fonts_section, 0, 10, 3, 1);

        font_buttons = new FontButton[5];
        string[] labels = {
            tr("Active window:"),
            tr("Inactive window:"),
            tr("Menu header:"),
            tr("Menu item:"),
            tr("On-screen display:")
        };
        for (int i = 0; i < 5; i++) {
            var row_label = make_row_label(labels[i]);
            int row = (i == 0) ? 11 : (i + 12);
            grid.attach(row_label, 0, row, 1, 1);
            font_buttons[i] = new FontButton();
            font_buttons[i].font_set.connect((s) => on_change());
            tune_control_width(font_buttons[i]);
            grid.attach(font_buttons[i], 1, row, 2, 1);
        }
        var btn = new Button.with_label(tr("Apply font to all"));
        btn.set_tooltip_text(tr("Copies the Active window font to Inactive window, Menu header, Menu item, and On-screen display."));
        btn.set_size_request(CONTROL_WIDTH_WIDE, -1);
        btn.halign = Align.START;

        var apply_popover = new Popover(btn);
        var popover_text = new Label(tr("Active window font was applied to all places."));
        popover_text.xalign = 0;
        popover_text.set_line_wrap(true);
        popover_text.set_max_width_chars(44);
        popover_text.margin_start = 8;
        popover_text.margin_end = 8;
        popover_text.margin_top = 8;
        popover_text.margin_bottom = 8;
        apply_popover.add(popover_text);
        apply_popover.set_position(PositionType.TOP);

        btn.clicked.connect(() => {
            string font = font_buttons[0].get_font();
            for (int i = 1; i < 5; i++) {
                font_buttons[i].set_font(font);
            }
            on_change();

            if (apply_font_popover_timeout_id != 0) {
                Source.remove(apply_font_popover_timeout_id);
                apply_font_popover_timeout_id = 0;
            }

            apply_popover.show_all();
            apply_font_popover_timeout_id = Timeout.add(1600, () => {
                apply_popover.hide();
                apply_font_popover_timeout_id = 0;
                return Source.REMOVE;
            });
        });
        grid.attach(btn, 1, 12, 2, 1);
        return create_scrolled(grid);
    }

    private Widget create_focus_tab() {
        var grid = create_tab_grid();

        var focus_label = make_section_header(tr("Focus"));
        grid.attach(focus_label, 0, 0, 2, 1);

        var intro = make_section_intro(tr("Configure how windows receive and raise focus."));
        grid.attach(intro, 0, 1, 2, 1);

        follow_mouse_check = new CheckButton.with_label(tr("Focus follows mouse"));
        normalize_checkbutton(follow_mouse_check);
        follow_mouse_check.toggled.connect((s) => on_change());
        grid.attach(follow_mouse_check, 0, 2, 2, 1);

        follow_mouse_requires_movement_check = new CheckButton.with_label(tr("Require cursor movement for focus"));
        normalize_checkbutton(follow_mouse_requires_movement_check);
        follow_mouse_requires_movement_check.toggled.connect((s) => on_change());
        grid.attach(follow_mouse_requires_movement_check, 0, 3, 2, 1);

        var label = make_row_label(tr("Focus delay (ms):"));
        grid.attach(label, 0, 4, 1, 1);
        focus_delay_spin = new SpinButton.with_range(0, 1000, 50);
        focus_delay_spin.value_changed.connect((s) => on_change());
        tune_control_width(focus_delay_spin);
        grid.attach(focus_delay_spin, 1, 4, 1, 1);

        raise_on_focus_check = new CheckButton.with_label(tr("Raise on focus"));
        normalize_checkbutton(raise_on_focus_check);
        raise_on_focus_check.toggled.connect((s) => on_change());
        grid.attach(raise_on_focus_check, 0, 5, 2, 1);
        return create_scrolled(grid);
    }

    private Widget create_mouse_tab() {
        var grid = create_tab_grid();

        var header = make_section_header(tr("Mouse"));
        grid.attach(header, 0, 0, 2, 1);

        var intro = make_section_intro(tr("Set mouse-related timing options."));
        grid.attach(intro, 0, 1, 2, 1);

        var label = make_row_label(tr("Double click time (ms):"));
        grid.attach(label, 0, 2, 1, 1);
        double_click_time_spin = new SpinButton.with_range(100, 1000, 50);
        double_click_time_spin.value_changed.connect((s) => on_change());
        tune_control_width(double_click_time_spin);
        grid.attach(double_click_time_spin, 1, 2, 1, 1);
        return create_scrolled(grid);
    }

    private Widget create_desktops_tab() {
        var grid = create_tab_grid();

        var header = make_section_header(tr("Desktops"));
        grid.attach(header, 0, 0, 3, 1);

        var intro = make_section_intro(tr("Configure desktop count and names."));
        grid.attach(intro, 0, 1, 3, 1);

        desktops_popup_check = new CheckButton.with_label(tr("Show notification when switching desktops"));
        normalize_checkbutton(desktops_popup_check);
        desktops_popup_check.set_tooltip_text(tr("Shows an on-screen notification when moving between desktops."));
        desktops_popup_check.toggled.connect((s) => {
            desktops_popup_time_spin.set_sensitive(desktops_popup_check.get_active());
            on_change();
        });
        grid.attach(desktops_popup_check, 0, 2, 3, 1);

        var label = make_row_label(tr("Notification time (ms):"));
        grid.attach(label, 0, 3, 1, 1);
        desktops_popup_time_spin = new SpinButton.with_range(0, 60000, 50);
        desktops_popup_time_spin.value_changed.connect((s) => on_change());
        desktops_popup_time_spin.set_tooltip_text(tr("Duration in milliseconds for the desktop switch popup."));
        tune_control_width(desktops_popup_time_spin);
        grid.attach(desktops_popup_time_spin, 1, 3, 1, 1);

        label = make_row_label(tr("Number of desktops:"));
        grid.attach(label, 0, 4, 1, 1);
        desktops_number_spin = new SpinButton.with_range(1, 20, 1);
        desktops_number_spin.value_changed.connect((s) => {
            sync_desktop_names_with_count((int)desktops_number_spin.get_value());
            on_change();
        });
        desktops_number_spin.set_tooltip_text(tr("Total number of desktops managed by labwc."));
        tune_control_width(desktops_number_spin);
        grid.attach(desktops_number_spin, 1, 4, 1, 1);

        label = make_row_label(tr("Desktop name prefix:"));
        grid.attach(label, 0, 5, 1, 1);
        desktops_prefix_entry = new Entry();
        desktops_prefix_entry.changed.connect((s) => on_change());
        desktops_prefix_entry.set_tooltip_text(tr("Used when creating default desktop names after increasing desktop count."));
        tune_control_width(desktops_prefix_entry);
        grid.attach(desktops_prefix_entry, 1, 5, 2, 1);

        attach_separator(grid, 6, 3);

        var desktop_names_label = new Label(tr("Desktop names:"));
        desktop_names_label.xalign = 0;
        desktop_names_label.margin_start = 14;
        grid.attach(desktop_names_label, 0, 7, 3, 1);

        var names_scrolled = new ScrolledWindow(null, null);
        names_scrolled.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        names_scrolled.set_min_content_height(220);
        desktops_names_view = new TextView();
        desktops_names_view.set_wrap_mode(WrapMode.NONE);
        desktops_names_view.get_buffer().changed.connect(() => on_change());
        names_scrolled.add(desktops_names_view);
        grid.attach(names_scrolled, 0, 8, 3, 1);

        return create_scrolled(grid);
    }

    private Widget create_margins_tab() {
        var grid = create_tab_grid();

        var header = make_section_header(tr("Margins"));
        grid.attach(header, 0, 0, 2, 1);

        var help = make_section_intro(tr("Reserved screen edges in pixels"));
        grid.attach(help, 0, 1, 2, 1);

        var help_details = new Label(
            tr("Margins define an area near each screen edge where normal windows should not be placed.") + "\n" +
            tr("This is useful for panels. Values are in pixels and applied per output.")
        );
        help_details.xalign = 0;
        help_details.margin_start = 14;
        help_details.set_line_wrap(true);
        grid.attach(help_details, 0, 2, 2, 1);

        var label = make_row_label(tr("Top:"));
        grid.attach(label, 0, 3, 1, 1);
        margin_top_spin = new SpinButton.with_range(0, 500, 1);
        margin_top_spin.value_changed.connect((s) => on_change());
        margin_top_spin.set_tooltip_text(tr("Top reserved margin in pixels."));
        tune_control_width(margin_top_spin);
        grid.attach(margin_top_spin, 1, 3, 1, 1);

        label = make_row_label(tr("Bottom:"));
        grid.attach(label, 0, 4, 1, 1);
        margin_bottom_spin = new SpinButton.with_range(0, 500, 1);
        margin_bottom_spin.value_changed.connect((s) => on_change());
        margin_bottom_spin.set_tooltip_text(tr("Bottom reserved margin in pixels."));
        tune_control_width(margin_bottom_spin);
        grid.attach(margin_bottom_spin, 1, 4, 1, 1);

        label = make_row_label(tr("Left:"));
        grid.attach(label, 0, 5, 1, 1);
        margin_left_spin = new SpinButton.with_range(0, 500, 1);
        margin_left_spin.value_changed.connect((s) => on_change());
        margin_left_spin.set_tooltip_text(tr("Left reserved margin in pixels."));
        tune_control_width(margin_left_spin);
        grid.attach(margin_left_spin, 1, 5, 1, 1);

        label = make_row_label(tr("Right:"));
        grid.attach(label, 0, 6, 1, 1);
        margin_right_spin = new SpinButton.with_range(0, 500, 1);
        margin_right_spin.value_changed.connect((s) => on_change());
        margin_right_spin.set_tooltip_text(tr("Right reserved margin in pixels."));
        tune_control_width(margin_right_spin);
        grid.attach(margin_right_spin, 1, 6, 1, 1);

        return create_scrolled(grid);
    }

    private Widget create_placement_tab() {
        var grid = create_tab_grid();

        var header = make_section_header(tr("Window placement"));
        grid.attach(header, 0, 0, 2, 1);

        var intro = make_section_intro(tr("Configure placement and resize behavior."));
        grid.attach(intro, 0, 1, 2, 1);

        var label = make_row_label(tr("Placement policy:"));
        grid.attach(label, 0, 2, 1, 1);
        placement_policy_combo = new ComboBoxText();
        placement_policy_combo.changed.connect((s) => {
            bool cascade = placement_policy_combo.get_active_id() == "cascade";
            placement_cascade_x_spin.set_sensitive(cascade);
            placement_cascade_y_spin.set_sensitive(cascade);
            on_change();
        });
        placement_policy_combo.append("center", tr("Center"));
        placement_policy_combo.append("automatic", tr("Automatic"));
        placement_policy_combo.append("cursor", tr("Mouse cursor"));
        placement_policy_combo.append("cascade", tr("Cascade"));
        placement_policy_combo.set_tooltip_text(tr("Policy for placing newly opened windows."));
        tune_control_width(placement_policy_combo);
        grid.attach(placement_policy_combo, 1, 2, 1, 1);

        label = make_row_label(tr("Placement monitor:"));
        grid.attach(label, 0, 3, 1, 1);
        placement_monitor_combo = new ComboBoxText();
        placement_monitor_combo.changed.connect((s) => on_change());
        placement_monitor_combo.append("Any", tr("Any"));
        placement_monitor_combo.append("Active", tr("Active"));
        placement_monitor_combo.append("Mouse", tr("Mouse"));
        placement_monitor_combo.set_tooltip_text(tr("Select which output is used for placement decisions."));
        tune_control_width(placement_monitor_combo);
        grid.attach(placement_monitor_combo, 1, 3, 1, 1);

        label = make_row_label(tr("Cascade offset X:"));
        grid.attach(label, 0, 4, 1, 1);
        placement_cascade_x_spin = new SpinButton.with_range(-5000, 5000, 1);
        placement_cascade_x_spin.value_changed.connect((s) => on_change());
        placement_cascade_x_spin.set_tooltip_text(tr("Horizontal offset between windows when policy is Cascade."));
        tune_control_width(placement_cascade_x_spin);
        grid.attach(placement_cascade_x_spin, 1, 4, 1, 1);

        label = make_row_label(tr("Cascade offset Y:"));
        grid.attach(label, 0, 5, 1, 1);
        placement_cascade_y_spin = new SpinButton.with_range(-5000, 5000, 1);
        placement_cascade_y_spin.value_changed.connect((s) => on_change());
        placement_cascade_y_spin.set_tooltip_text(tr("Vertical offset between windows when policy is Cascade."));
        tune_control_width(placement_cascade_y_spin);
        grid.attach(placement_cascade_y_spin, 1, 5, 1, 1);

        attach_separator(grid, 6, 2);

        var resize_header = make_section_header(tr("Resize"));
        grid.attach(resize_header, 0, 7, 2, 1);

        label = make_row_label(tr("Resize popup:"));
        grid.attach(label, 0, 8, 1, 1);
        resize_popup_show_combo = new ComboBoxText();
        resize_popup_show_combo.changed.connect((s) => on_change());
        resize_popup_show_combo.append("Never", tr("Never"));
        resize_popup_show_combo.append("Always", tr("Always"));
        resize_popup_show_combo.append("Nonpixel", tr("Nonpixel"));
        resize_popup_show_combo.set_tooltip_text(tr("Controls when resize dimensions are shown in an OSD popup."));
        tune_control_width(resize_popup_show_combo);
        grid.attach(resize_popup_show_combo, 1, 8, 1, 1);

        resize_draw_contents_check = new CheckButton.with_label(tr("Draw window contents while resizing"));
        normalize_checkbutton(resize_draw_contents_check);
        resize_draw_contents_check.set_tooltip_text(tr("When disabled, only an outline is shown during resize."));
        resize_draw_contents_check.toggled.connect((s) => on_change());
        grid.attach(resize_draw_contents_check, 0, 9, 2, 1);

        label = make_row_label(tr("Corner range:"));
        grid.attach(label, 0, 10, 1, 1);
        resize_corner_range_spin = new SpinButton.with_range(1, 1000, 1);
        resize_corner_range_spin.value_changed.connect((s) => on_change());
        resize_corner_range_spin.set_tooltip_text(tr("Pixel range near window corners used for corner resize behavior."));
        tune_control_width(resize_corner_range_spin);
        grid.attach(resize_corner_range_spin, 1, 10, 1, 1);

        label = make_row_label(tr("Minimum area:"));
        grid.attach(label, 0, 11, 1, 1);
        resize_minimum_area_spin = new SpinButton.with_range(1, 1000000, 1);
        resize_minimum_area_spin.value_changed.connect((s) => on_change());
        resize_minimum_area_spin.set_tooltip_text(tr("Smallest allowed window area in square pixels."));
        tune_control_width(resize_minimum_area_spin);
        grid.attach(resize_minimum_area_spin, 1, 11, 1, 1);

        return create_scrolled(grid);
    }

    private Widget create_osd_tab() {
        var grid = create_tab_grid();
        var header = make_section_header(tr("Window switcher"));
        grid.attach(header, 0, 0, 2, 1);

        var intro = make_section_intro(tr("Configure window switcher OSD."));
        grid.attach(intro, 0, 1, 2, 1);

        window_switcher_show_check = new CheckButton.with_label(tr("Show OSD"));
        normalize_checkbutton(window_switcher_show_check);
        window_switcher_show_check.toggled.connect((s) => on_change());
        grid.attach(window_switcher_show_check, 0, 2, 2, 1);
        var label = make_row_label(tr("OSD style:"));
        grid.attach(label, 0, 3, 1, 1);
        window_switcher_style_combo = new ComboBoxText();
        window_switcher_style_combo.changed.connect((s) => on_change());
        window_switcher_style_combo.append("classic", tr("Classic"));
        window_switcher_style_combo.append("thumbnail", tr("Thumbnail"));
        window_switcher_style_combo.set_active_id("thumbnail");
        window_switcher_style_combo.set_tooltip_text(tr("Choose classic list or thumbnail switcher style."));
        tune_control_width(window_switcher_style_combo);
        grid.attach(window_switcher_style_combo, 1, 3, 1, 1);

        label = make_row_label(tr("OSD output:"));
        grid.attach(label, 0, 4, 1, 1);
        window_switcher_output_combo = new ComboBoxText();
        window_switcher_output_combo.changed.connect((s) => on_change());
        window_switcher_output_combo.append("all", tr("All outputs"));
        window_switcher_output_combo.append("current", tr("Current output"));
        window_switcher_output_combo.append("active", tr("Active output"));
        window_switcher_output_combo.set_tooltip_text(tr("Select where the window switcher OSD is shown."));
        tune_control_width(window_switcher_output_combo);
        grid.attach(window_switcher_output_combo, 1, 4, 1, 1);

        label = make_row_label(tr("Thumbnail label format:"));
        grid.attach(label, 0, 5, 1, 1);
        window_switcher_thumbnail_label_entry = new Entry();
        window_switcher_thumbnail_label_entry.changed.connect((s) => on_change());
        window_switcher_thumbnail_label_entry.set_tooltip_text(tr("Format string for thumbnail labels, for example %T (title)."));
        tune_control_width(window_switcher_thumbnail_label_entry);
        grid.attach(window_switcher_thumbnail_label_entry, 1, 5, 1, 1);

        var hint = make_section_intro(tr("Common placeholders include %T (title), %a (application id), and %n (window index)."));
        grid.attach(hint, 0, 6, 2, 1);
        return create_scrolled(grid);
    }

    private string[] parse_csv_unique(string raw) {
        string[] tokens = {};
        foreach (string token in raw.split(",")) {
            string t = token.strip();
            if (t == "") {
                continue;
            }
            bool exists = false;
            for (int i = 0; i < tokens.length; i++) {
                if (tokens[i] == t) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                tokens += t;
            }
        }
        return tokens;
    }

    private string[] popular_xkb_options() {
        return {
            "grp:alt_shift_toggle",
            "grp:ctrl_shift_toggle",
            "grp:shift_caps_toggle",
            "grp:win_space_toggle",
            "grp:menu_toggle",
            "grp:lalt_lshift_toggle",
            "grp:ralt_rshift_toggle",
            "caps:escape",
            "compose:ralt"
        };
    }

    private string[] environment_managed_keys() {
        return {
            "XKB_DEFAULT_LAYOUT",
            "XKB_DEFAULT_OPTIONS",
            "XKB_DEFAULT_LAYOUT_AUTO",
            "MOZ_ENABLE_WAYLAND",
            "XCURSOR_SIZE",
            "WLR_NO_HARDWARE_CURSORS",
            "_JAVA_AWT_WM_NONREPARENTING",
            "XDG_CURRENT_DESKTOP",
            "LABWC_FALLBACK_OUTPUT"
        };
    }

    private void xkb_options_select_preset(string preset) {
        if (xkb_options_entry == null || syncing_xkb_options) {
            return;
        }

        syncing_xkb_options = true;
        string[] current = parse_csv_unique(xkb_options_entry.get_text());
        bool found = false;
        for (int i = 0; i < current.length; i++) {
            if (current[i] == preset) {
                found = true;
                break;
            }
        }
        if (!found) {
            current += preset;
            xkb_options_entry.set_text(string.joinv(",", current));
        }
        syncing_xkb_options = false;
        on_change();
    }

    private Widget create_environment_keyboard_tab() {
        var grid = create_tab_grid();
        grid.column_spacing = 8;

        var header = make_section_header(tr("Keyboard"));
        grid.attach(header, 0, 0, 3, 1);

        var intro = make_section_intro(tr("Set XKB layout and options for keyboard switching and behavior."));
        grid.attach(intro, 0, 1, 3, 1);

        var label = make_row_label(tr("XKB layout:"));
        grid.attach(label, 0, 2, 1, 1);
        xkb_layout_entry = new Entry();
        xkb_layout_entry.set_tooltip_text(tr("Examples: se or se,us(intl)"));
        xkb_layout_entry.changed.connect((s) => on_change());
        tune_control_width(xkb_layout_entry);
        grid.attach(xkb_layout_entry, 1, 2, 1, 1);

        label = make_row_label(tr("XKB options:"));
        grid.attach(label, 0, 3, 1, 1);
        xkb_options_combo = new ComboBoxText.with_entry();
        string[] options = popular_xkb_options();
        for (int i = 0; i < options.length; i++) {
            xkb_options_combo.append_text(options[i]);
        }
        xkb_options_combo.set_active(-1);
        xkb_options_combo.set_size_request(CONTROL_WIDTH_WIDE, -1);
        xkb_options_combo.halign = Align.START;
        xkb_options_combo.changed.connect(() => {
            if (syncing_xkb_options) {
                return;
            }
            string? selected = xkb_options_combo.get_active_text();
            if (selected != null && selected.strip() != "") {
                xkb_options_select_preset(selected.strip());
            }
        });

        Widget? child = xkb_options_combo.get_child();
        xkb_options_entry = child as Entry;
        if (xkb_options_entry == null) {
            xkb_options_entry = new Entry();
        }
        xkb_options_entry.set_tooltip_text(tr("Comma-separated options, for example grp:alt_shift_toggle,caps:escape"));
        xkb_options_entry.changed.connect((s) => {
            if (!syncing_xkb_options) {
                on_change();
            }
        });
        grid.attach(xkb_options_combo, 1, 3, 1, 1);

        var options_header = make_section_intro(tr("Preset options:"));
        options_header.margin_bottom = 2;
        grid.attach(options_header, 0, 4, 3, 1);

        var help = make_section_intro(tr("Select a preset to append it, or type any custom CSV value directly."));
        help.margin_top = 4;
        grid.attach(help, 0, 5, 3, 1);

        var help2 = make_section_intro(tr("Use XKB parameters when multiple layouts are configured and a toggle shortcut is needed."));
        help2.margin_top = 2;
        grid.attach(help2, 0, 6, 3, 1);

        return create_scrolled(grid);
    }

    private Widget create_environment_cursor_tab() {
        var grid = create_tab_grid();

        var header = make_section_header(tr("Mouse cursor"));
        grid.attach(header, 0, 0, 3, 1);

        var intro = make_section_intro(tr("Configure cursor size and optional software cursor fallback."));
        grid.attach(intro, 0, 1, 3, 1);

        var label = make_row_label(tr("Cursor size:"));
        grid.attach(label, 0, 2, 1, 1);
        xcursor_size_entry = new Entry();
        xcursor_size_entry.set_tooltip_text(tr("Cursor size in pixels, for example 24."));
        xcursor_size_entry.changed.connect((s) => on_change());
        tune_control_width(xcursor_size_entry);
        grid.attach(xcursor_size_entry, 1, 2, 1, 1);

        wlr_no_hardware_cursors_check = new CheckButton.with_label(tr("Disable hardware cursors"));
        normalize_checkbutton(wlr_no_hardware_cursors_check);
        wlr_no_hardware_cursors_check.set_tooltip_text(tr("Enable this only if cursors are disappearing or flickering. Sets WLR_NO_HARDWARE_CURSORS=1."));
        wlr_no_hardware_cursors_check.toggled.connect((s) => on_change());
        grid.attach(wlr_no_hardware_cursors_check, 0, 3, 2, 1);

        return create_scrolled(grid);
    }

    private Widget create_environment_compatibility_tab() {
        var grid = create_tab_grid();

        var header = make_section_header(tr("Compatibility"));
        grid.attach(header, 0, 0, 3, 1);

        var intro = make_section_intro(tr("Compatibility variables for Java/AWT behavior under Wayland."));
        grid.attach(intro, 0, 1, 3, 1);

        java_nonreparenting_disable_check = new CheckButton.with_label(tr("Set Java AWT non-reparenting to 0"));
        normalize_checkbutton(java_nonreparenting_disable_check);
        java_nonreparenting_disable_check.set_tooltip_text(tr("Only set this if you need to override labwc default behavior."));
        java_nonreparenting_disable_check.toggled.connect((s) => on_change());
        grid.attach(java_nonreparenting_disable_check, 0, 2, 2, 1);

        moz_enable_wayland_check = new CheckButton.with_label(tr("Force Wayland for Mozilla apps"));
        normalize_checkbutton(moz_enable_wayland_check);
        moz_enable_wayland_check.set_tooltip_text(tr("Recommended for Firefox and Thunderbird on Wayland sessions. Sets MOZ_ENABLE_WAYLAND=1."));
        moz_enable_wayland_check.toggled.connect((s) => on_change());
        grid.attach(moz_enable_wayland_check, 0, 3, 2, 1);

        return create_scrolled(grid);
    }

    private Widget create_environment_desktop_tab() {
        var grid = create_tab_grid();

        var header = make_section_header(tr("Desktop / Portal"));
        grid.attach(header, 0, 0, 3, 1);

        var intro = make_section_intro(tr("Desktop integration variables used by xdg-desktop-portal and related tools."));
        grid.attach(intro, 0, 1, 3, 1);

        var label = make_row_label(tr("XDG current desktop:"));
        grid.attach(label, 0, 2, 1, 1);
        xdg_current_desktop_entry = new Entry();
        xdg_current_desktop_entry.set_tooltip_text(tr("Usually labwc:wlroots. Leave empty to use labwc defaults."));
        xdg_current_desktop_entry.changed.connect((s) => on_change());
        tune_control_width(xdg_current_desktop_entry);
        grid.attach(xdg_current_desktop_entry, 1, 2, 1, 1);

        return create_scrolled(grid);
    }

    private Widget create_environment_output_tab() {
        var grid = create_tab_grid();

        var header = make_section_header(tr("Virtual output"));
        grid.attach(header, 0, 0, 3, 1);

        var intro = make_section_intro(tr("Create a fallback virtual output when no physical displays are available."));
        grid.attach(intro, 0, 1, 3, 1);

        var label = make_row_label(tr("Fallback output name:"));
        grid.attach(label, 0, 2, 1, 1);
        fallback_output_entry = new Entry();
        fallback_output_entry.set_tooltip_text(tr("Example: NOOP-fallback"));
        fallback_output_entry.changed.connect((s) => on_change());
        tune_control_width(fallback_output_entry);
        grid.attach(fallback_output_entry, 1, 2, 1, 1);

        var hint = make_section_intro(tr("Names starting with NOOP- are useful for remote clients like wayvnc."));
        grid.attach(hint, 0, 3, 3, 1);
        return create_scrolled(grid);
    }

    private Widget create_environment_custom_tab() {
        var grid = create_tab_grid();
        var header = make_section_header(tr("Custom"));
        grid.attach(header, 0, 0, 3, 1);

        var intro = make_section_intro(tr("Custom KEY=VALUE lines for ~/.config/labwc/environment not covered by dedicated tabs."));
        grid.attach(intro, 0, 1, 3, 1);

        reset_custom_btn = create_reset_button();
        reset_custom_btn.halign = Align.END;
        reset_custom_btn.clicked.connect(() => {
            custom_environment_view.get_buffer().set_text(initial_state.custom_environment);
            on_change();
        });
        var reset_row = new Box(Orientation.HORIZONTAL, 0);
        reset_row.halign = Align.FILL;
        reset_row.hexpand = true;
        reset_row.pack_end(reset_custom_btn, false, false, 0);

        custom_environment_view = new TextView();
        custom_environment_view.set_wrap_mode(WrapMode.NONE);
        custom_environment_view.monospace = true;
        custom_environment_view.set_size_request(-1, 260);
        custom_environment_view.get_buffer().changed.connect(() => on_change());

        custom_environment_scrolled = new ScrolledWindow(null, null);
        custom_environment_scrolled.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        custom_environment_scrolled.add(custom_environment_view);
        custom_environment_frame = new Frame(null);
        custom_environment_frame.set_shadow_type(ShadowType.IN);
        custom_environment_frame.add(custom_environment_scrolled);
        grid.attach(custom_environment_frame, 0, 2, 3, 1);

        grid.attach(reset_row, 0, 3, 3, 1);

        var hint = make_section_intro(tr("One assignment per line, for example MOZ_ENABLE_WAYLAND=1. Invalid lines are ignored on save."));
        hint.margin_top = 4;
        grid.attach(hint, 0, 4, 3, 1);

        return create_scrolled(grid);
    }

    private Widget create_scrolled(Widget child) {
        var scrolled = new ScrolledWindow(null, null);
        scrolled.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        scrolled.set_min_content_height(250);
        scrolled.add(child);
        return scrolled;
    }

    private void load_settings() {
        is_loading_settings = true;
        debug_log("load_settings: rc_path=" + config.rc_path + " current_theme=" + config.get_theme_name());
        string current_theme = config.get_theme_name();
        initial_theme_name = current_theme;
        live_applied_theme_name = current_theme;
        selected_theme_name = current_theme;
        int idx = 0;
        bool found_selected = false;
        foreach (string theme_name in theme_scanner.themes) {
            if (theme_name == current_theme) {
                theme_list.select_row((ListBoxRow)theme_list.get_children().nth_data(idx));
                found_selected = true;
                break;
            }
            idx++;
        }
        if (!found_selected && theme_scanner.themes.length > 0) {
            theme_list.select_row((ListBoxRow)theme_list.get_children().nth_data(0));
        }
        corner_radius_spin.set_value(config.get_corner_radius());
        keep_border_check.set_active(config.get_keep_border());
        show_title_check.set_active(config.get_show_title());
        drop_shadows_check.set_active(config.get_drop_shadows());
        drop_shadows_on_tiled_check.set_active(config.get_drop_shadows_on_tiled());
        title_layout_entry.set_text(config.get_title_layout());
        title_layout_dirty = false;
        for (int i = 0; i < 5; i++) {
            string[] places = {"ActiveWindow", "InactiveWindow", "MenuHeader", "MenuItem", "OnScreenDisplay"};
            var font = config.get_font(places[i]);
            font_buttons[i].set_font(font.name + " " + font.size.to_string());
        }
        focus_delay_spin.set_value(config.get_focus_delay());
        follow_mouse_check.set_active(config.get_focus_follow_mouse());
        follow_mouse_requires_movement_check.set_active(config.get_focus_follow_mouse_requires_movement());
        raise_on_focus_check.set_active(config.get_focus_raise_on_focus());
        double_click_time_spin.set_value(config.get_mouse_double_click_time());
        window_switcher_show_check.set_active(config.get_window_switcher_show());
        string osd_style = config.get_window_switcher_style().down();
        if (osd_style != "classic" && osd_style != "thumbnail") {
            osd_style = "thumbnail";
        }
        window_switcher_style_combo.set_active_id(osd_style);
        string osd_output = config.get_window_switcher_output().down();
        if (osd_output != "all" && osd_output != "current" && osd_output != "active") {
            osd_output = "all";
        }
        window_switcher_output_combo.set_active_id(osd_output);
        window_switcher_thumbnail_label_entry.set_text(config.get_window_switcher_thumbnail_label_format());
        resize_popup_show_combo.set_active_id(config.get_resize_popup_show_mode());
        resize_draw_contents_check.set_active(config.get_resize_draw_contents());
        resize_corner_range_spin.set_value((double)config.get_resize_corner_range());
        resize_minimum_area_spin.set_value((double)config.get_resize_minimum_area());

        int popup_time = config.get_desktops_popup_time();
        desktops_popup_check.set_active(popup_time > 0);
        desktops_popup_time_spin.set_value((double)popup_time);
        desktops_popup_time_spin.set_sensitive(popup_time > 0);
        string[] desktop_names = config.get_desktops_names();
        int desktops_count = config.get_desktops_number();
        if (desktop_names.length > desktops_count) {
            desktops_count = desktop_names.length;
        }
        desktops_number_spin.set_value((double)desktops_count);
        desktops_prefix_entry.set_text(config.get_desktops_prefix());

        if (desktop_names.length == 0) {
            sync_desktop_names_with_count(desktops_count);
        } else {
            set_desktop_names_to_view(desktop_names);
            sync_desktop_names_with_count(desktops_count);
        }
        margin_top_spin.set_value((double)config.get_margin_top());
        margin_bottom_spin.set_value((double)config.get_margin_bottom());
        margin_left_spin.set_value((double)config.get_margin_left());
        margin_right_spin.set_value((double)config.get_margin_right());

        string placement_policy = config.get_placement_policy();
        placement_policy_combo.set_active_id(placement_policy.down());
        if (placement_policy_combo.get_active_id() == null) {
            placement_policy_combo.set_active_id("cascade");
        }
        placement_monitor_combo.set_active_id(config.get_placement_monitor());
        placement_cascade_x_spin.set_value((double)config.get_placement_cascade_offset_x());
        placement_cascade_y_spin.set_value((double)config.get_placement_cascade_offset_y());
        bool cascade = placement_policy_combo.get_active_id() == "cascade";
        placement_cascade_x_spin.set_sensitive(cascade);
        placement_cascade_y_spin.set_sensitive(cascade);

        xkb_layout_entry.set_text(environment_config.get_value("XKB_DEFAULT_LAYOUT"));
        xkb_options_entry.set_text(environment_config.normalize_csv_value(environment_config.get_value("XKB_DEFAULT_OPTIONS")));
        if (xkb_options_combo != null) {
            xkb_options_combo.set_active(-1);
        }
        xcursor_size_entry.set_text(environment_config.get_value("XCURSOR_SIZE"));
        wlr_no_hardware_cursors_check.set_active(environment_config.get_value("WLR_NO_HARDWARE_CURSORS") == "1");
        java_nonreparenting_disable_check.set_active(environment_config.get_value("_JAVA_AWT_WM_NONREPARENTING") == "0");
        moz_enable_wayland_check.set_active(environment_config.get_value("MOZ_ENABLE_WAYLAND") == "1");
        xdg_current_desktop_entry.set_text(environment_config.get_value("XDG_CURRENT_DESKTOP"));
        fallback_output_entry.set_text(environment_config.get_value("LABWC_FALLBACK_OUTPUT"));
        custom_environment_view.get_buffer().set_text(environment_config.export_unmanaged_assignments(environment_managed_keys()));

        initial_state.corner_radius = (int)corner_radius_spin.get_value();
        initial_state.keep_border = keep_border_check.get_active();
        initial_state.show_title = show_title_check.get_active();
        initial_state.drop_shadows = drop_shadows_check.get_active();
        initial_state.drop_shadows_on_tiled = drop_shadows_on_tiled_check.get_active();
        initial_state.title_layout = sanitize_title_layout(title_layout_entry.get_text());
        initial_state.font_names = new string[font_buttons.length];
        for (int i = 0; i < font_buttons.length; i++) {
            initial_state.font_names[i] = font_buttons[i].get_font();
        }
        initial_state.focus_delay = (int)focus_delay_spin.get_value();
        initial_state.follow_mouse = follow_mouse_check.get_active();
        initial_state.follow_mouse_requires_movement = follow_mouse_requires_movement_check.get_active();
        initial_state.raise_on_focus = raise_on_focus_check.get_active();
        initial_state.double_click_time = (int)double_click_time_spin.get_value();
        initial_state.window_switcher_show = window_switcher_show_check.get_active();
        initial_state.window_switcher_style = window_switcher_style_combo.get_active_id() ?? "";
        initial_state.window_switcher_output = window_switcher_output_combo.get_active_id() ?? "";
        initial_state.window_switcher_thumbnail_label = window_switcher_thumbnail_label_entry.get_text().strip();
        initial_state.resize_popup_show = resize_popup_show_combo.get_active_id() ?? "";
        initial_state.resize_draw_contents = resize_draw_contents_check.get_active();
        initial_state.resize_corner_range = (int)resize_corner_range_spin.get_value();
        initial_state.resize_minimum_area = (int)resize_minimum_area_spin.get_value();
        initial_state.desktops_popup = desktops_popup_check.get_active();
        initial_state.desktops_popup_time = (int)desktops_popup_time_spin.get_value();
        initial_state.desktops_number = (int)desktops_number_spin.get_value();
        initial_state.desktops_prefix = desktops_prefix_entry.get_text().strip();
        initial_state.desktops_names_text_norm = normalize_desktop_names_text();
        initial_state.margin_top = (int)margin_top_spin.get_value();
        initial_state.margin_bottom = (int)margin_bottom_spin.get_value();
        initial_state.margin_left = (int)margin_left_spin.get_value();
        initial_state.margin_right = (int)margin_right_spin.get_value();
        initial_state.placement_policy = placement_policy_combo.get_active_id() ?? "";
        initial_state.placement_monitor = placement_monitor_combo.get_active_id() ?? "";
        initial_state.placement_cascade_x = (int)placement_cascade_x_spin.get_value();
        initial_state.placement_cascade_y = (int)placement_cascade_y_spin.get_value();

        initial_state.xkb_layout = xkb_layout_entry.get_text().strip();
        initial_state.xkb_options = environment_config.normalize_csv_value(xkb_options_entry.get_text());
        initial_state.xcursor_size = xcursor_size_entry.get_text().strip();
        initial_state.wlr_no_hardware_cursors = wlr_no_hardware_cursors_check.get_active();
        initial_state.java_nonreparenting_zero = java_nonreparenting_disable_check.get_active();
        initial_state.moz_enable_wayland = moz_enable_wayland_check.get_active();
        initial_state.xdg_current_desktop = xdg_current_desktop_entry.get_text().strip();
        initial_state.fallback_output = fallback_output_entry.get_text().strip();
        TextIter custom_start;
        TextIter custom_end;
        custom_environment_view.get_buffer().get_bounds(out custom_start, out custom_end);
        initial_state.custom_environment = custom_environment_view.get_buffer().get_text(custom_start, custom_end, false);

        has_changes = false;
        preview_applied = false;
        update_field_states();
        update_action_buttons();
        is_loading_settings = false;
        update_status();
    }

    private void save_settings() {
        string theme_name = get_selected_theme();
        debug_log("save_settings: selected=" + theme_name + " initial=" + initial_theme_name + " rc=" + config.rc_path);
        config.set_theme_name(theme_name);
        config.set_corner_radius((int)corner_radius_spin.get_value());
        config.set_keep_border(keep_border_check.get_active());
        config.set_show_title(show_title_check.get_active());
        config.set_drop_shadows(drop_shadows_check.get_active());
        config.set_drop_shadows_on_tiled(drop_shadows_on_tiled_check.get_active());
        string title_layout = sanitize_title_layout(title_layout_entry.get_text());
        if (title_layout_entry.get_text() != title_layout) {
            title_layout_entry.set_text(title_layout);
        }
        if (title_layout_dirty && config.get_title_layout() != title_layout) {
            config.set_title_layout(title_layout);
        }
        for (int i = 0; i < 5; i++) {
            string[] places = {"ActiveWindow", "InactiveWindow", "MenuHeader", "MenuItem", "OnScreenDisplay"};
            string font_str = font_buttons[i].get_font();
            var desc = Pango.FontDescription.from_string(font_str);
            var font = new FontConfig();
            font.name = desc.get_family() ?? "DejaVu Sans";
            font.size = desc.get_size() / Pango.SCALE;
            config.set_font(places[i], font);
        }
        config.set_focus_delay((int)focus_delay_spin.get_value());
        config.set_focus_follow_mouse(follow_mouse_check.get_active());
        config.set_focus_follow_mouse_requires_movement(follow_mouse_requires_movement_check.get_active());
        config.set_focus_raise_on_focus(raise_on_focus_check.get_active());
        config.set_mouse_double_click_time((int)double_click_time_spin.get_value());
        string placement_id = placement_policy_combo.get_active_id();
        if (placement_id == null || placement_id == "") {
            placement_id = "cascade";
        }
        config.set_placement_policy(placement_id);
        config.set_placement_monitor(placement_monitor_combo.get_active_id());
        config.set_placement_cascade_offset((int)placement_cascade_x_spin.get_value(), (int)placement_cascade_y_spin.get_value());
        config.set_window_switcher_show(window_switcher_show_check.get_active());
        string osd_style = window_switcher_style_combo.get_active_id();
        if (osd_style == null || osd_style == "") {
            osd_style = "thumbnail";
        }
        config.set_window_switcher_style(osd_style);
        string osd_output = window_switcher_output_combo.get_active_id();
        if (osd_output == null || osd_output == "") {
            osd_output = "all";
        }
        config.set_window_switcher_output(osd_output);
        config.set_window_switcher_thumbnail_label_format(window_switcher_thumbnail_label_entry.get_text());
        string popup_mode = resize_popup_show_combo.get_active_id();
        if (popup_mode == null || popup_mode == "") {
            popup_mode = "Never";
        }
        config.set_resize_popup_show_mode(popup_mode);
        config.set_resize_draw_contents(resize_draw_contents_check.get_active());
        config.set_resize_corner_range((int)resize_corner_range_spin.get_value());
        config.set_resize_minimum_area((int)resize_minimum_area_spin.get_value());

        int popup_ms = desktops_popup_check.get_active() ? (int)desktops_popup_time_spin.get_value() : 0;
        config.set_desktops_popup_time(popup_ms);
        config.set_desktops_number((int)desktops_number_spin.get_value());
        config.set_desktops_prefix(desktops_prefix_entry.get_text());
        string[] lines = get_desktop_names_from_view();
        bool names_changed = normalize_desktop_names_text() != initial_state.desktops_names_text_norm;
        if (names_changed) {
            config.set_desktops_names(lines);
        }

        config.set_margins(
            (int)margin_top_spin.get_value(),
            (int)margin_bottom_spin.get_value(),
            (int)margin_left_spin.get_value(),
            (int)margin_right_spin.get_value()
        );

        environment_config.set_or_clear("XKB_DEFAULT_LAYOUT", xkb_layout_entry.get_text());
        environment_config.set_or_clear("XKB_DEFAULT_OPTIONS", environment_config.normalize_csv_value(xkb_options_entry.get_text()));
        environment_config.clear_value("XKB_DEFAULT_LAYOUT_AUTO");
        environment_config.set_or_clear("XCURSOR_SIZE", xcursor_size_entry.get_text());
        if (wlr_no_hardware_cursors_check.get_active()) {
            environment_config.set_value("WLR_NO_HARDWARE_CURSORS", "1");
        } else {
            environment_config.clear_value("WLR_NO_HARDWARE_CURSORS");
        }
        if (java_nonreparenting_disable_check.get_active()) {
            environment_config.set_value("_JAVA_AWT_WM_NONREPARENTING", "0");
        } else {
            environment_config.clear_value("_JAVA_AWT_WM_NONREPARENTING");
        }
        if (moz_enable_wayland_check.get_active()) {
            environment_config.set_value("MOZ_ENABLE_WAYLAND", "1");
        } else {
            environment_config.clear_value("MOZ_ENABLE_WAYLAND");
        }
        environment_config.set_or_clear("XDG_CURRENT_DESKTOP", xdg_current_desktop_entry.get_text());
        environment_config.set_or_clear("LABWC_FALLBACK_OUTPUT", fallback_output_entry.get_text());

        TextIter custom_start;
        TextIter custom_end;
        custom_environment_view.get_buffer().get_bounds(out custom_start, out custom_end);
        string custom_text = custom_environment_view.get_buffer().get_text(custom_start, custom_end, false);
        environment_config.apply_unmanaged_assignments(environment_managed_keys(), custom_text);

        debug_log("save_settings: theme_after_set=" + config.get_theme_name());
    }

    private static string read_file_or_empty(string path) {
        try {
            if (!FileUtils.test(path, FileTest.EXISTS)) {
                return "";
            }
            string content = "";
            if (!FileUtils.get_contents(path, out content)) {
                return "";
            }
            return content;
        } catch (Error e) {
            return "";
        }
    }

    private void apply_preview_changes() {
        if (!has_changes) {
            return;
        }

        save_settings();

        bool rc_ok = config.save();
        bool env_ok = environment_config.save();
        if (!rc_ok || !env_ok) {
            string message = tr("Failed to apply preview changes.");
            if (!rc_ok && !env_ok) {
                message = tr("Failed to write rc.xml and environment for preview.");
            } else if (!rc_ok) {
                message = tr("Failed to write rc.xml for preview.");
            } else {
                message = tr("Failed to write environment for preview.");
            }
            var err = new MessageDialog(this, DialogFlags.MODAL, MessageType.ERROR, ButtonsType.CLOSE, "%s", message);
            err.run();
            err.destroy();
            return;
        }

        run_labwc_reconfigure();
        has_changes = false;
        preview_applied = true;
        update_action_buttons();
        status_label.set_text(tr("Preview applied. Press OK to keep changes or Cancel to revert."));
    }

    private static string[] append_string(string[] list, string value) {
        string[] out = {};
        for (int i = 0; i < list.length; i++) {
            out += list[i];
        }
        out += value;
        return out;
    }

    private static string json_escape(string text) {
        string out = text;
        out = out.replace("\\", "\\\\");
        out = out.replace("\"", "\\\"");
        out = out.replace("\n", "\\n");
        out = out.replace("\r", "\\r");
        out = out.replace("\t", "\\t");
        return out;
    }

    private static string json_array(string[] items) {
        string[] values = {};
        for (int i = 0; i < items.length; i++) {
            values += "\"" + json_escape(items[i]) + "\"";
        }
        return "[" + string.joinv(",", values) + "]";
    }

    private static void print_status_report_json(string status, string path, string[] warnings, string[] errors, int exit_code) {
        string json = "{" +
            "\"status\":\"" + json_escape(status) + "\"," +
            "\"path\":\"" + json_escape(path) + "\"," +
            "\"warnings\":" + json_array(warnings) + "," +
            "\"errors\":" + json_array(errors) + "," +
            "\"exit_code\":" + exit_code.to_string() +
            "}";
        stdout.printf("%s\n", json);
    }

    private static void print_status_report(string status, string path, string[] warnings, string[] errors) {
        if (status == "PASS") {
            stdout.printf("PASS: %s\n", tr("rc.xml is compatible with labconf"));
            stdout.printf("%s: %s\n", tr("Path"), path);
            stdout.printf("%s: %d, %s: %d, %s: %d\n",
                tr("Checks passed"), 6,
                tr("warnings"), warnings.length,
                tr("errors"), errors.length);
            return;
        }

        if (status == "WARN") {
            stdout.printf("WARN: %s\n", tr("rc.xml is usable with warnings"));
            stdout.printf("%s: %s\n", tr("Path"), path);
            stdout.printf("%s:\n", tr("Warnings"));
            for (int i = 0; i < warnings.length; i++) {
                stdout.printf("- %s\n", warnings[i]);
            }
            stdout.printf("%s: %s\n", tr("Result"), tr("configuration can be edited and saved"));
            return;
        }

        stderr.printf("FAIL: %s\n", tr("rc.xml is not compatible with labconf"));
        stderr.printf("%s: %s\n", tr("Path"), path);
        if (errors.length > 0) {
            stderr.printf("%s:\n", tr("Errors"));
            for (int i = 0; i < errors.length; i++) {
                stderr.printf("- %s\n", errors[i]);
            }
        }
    }

    private static int run_config_test_mode(string? rc_override, bool strict_mode = false, bool json_mode = false) {
        if (rc_override != null && rc_override.strip() != "") {
            Environment.set_variable("LABCONF_RC_PATH", rc_override.strip(), true);
        }

        var cfg = new Config();
        string rc_path = cfg.rc_path;
        string[] warnings = {};
        string[] errors = {};

        if (!FileUtils.test(rc_path, FileTest.EXISTS)) {
            if (json_mode) {
                string[] errs = {"rc.xml not found"};
                print_status_report_json("FAIL", rc_path, {}, errs, 1);
            } else {
                stderr.printf("FAIL: %s\n", tr("rc.xml not found"));
                stderr.printf("%s: %s\n", tr("Path"), rc_path);
                stderr.printf("%s: %s\n", tr("Hint"), tr("use -c <path> to specify config file"));
            }
            return 1;
        }

        string raw = "";
        try {
            if (!FileUtils.get_contents(rc_path, out raw)) {
                errors = append_string(errors, "cannot read rc.xml contents");
            }
        } catch (Error e) {
            errors = append_string(errors, "cannot read rc.xml: " + e.message);
        }

        if (raw == "") {
            errors = append_string(errors, "rc.xml is empty");
        }

        if (raw.index_of("<labwc_config") < 0) {
            errors = append_string(errors, "root <labwc_config> not found");
        }

        if (!cfg.load()) {
            errors = append_string(errors, "Config.load() failed for selected rc.xml");
        } else {
            string theme = cfg.get_theme_name();
            if (theme.strip() == "") {
                warnings = append_string(warnings, "theme/name is missing; defaults may be applied");
            }

            cfg.get_title_layout();
            cfg.get_show_title();
            cfg.get_window_switcher_style();
            cfg.get_desktops_number();
            cfg.get_margin_top();
        }

        if (raw.index_of("<titleLayout>") >= 0) {
            warnings = append_string(warnings, "legacy <theme><titleLayout> detected; it will be migrated to <theme><titlebar><layout>");
        }
        if (raw.index_of("<showTitle>") >= 0 && raw.index_of("<titlebar>") < 0) {
            warnings = append_string(warnings, "legacy <theme><showTitle> detected; it will be migrated to <theme><titlebar><showTitle>");
        }
        if (raw.index_of("<names><names>") >= 0) {
            warnings = append_string(warnings, "nested <names><names> detected; save will normalize desktop names block");
        }

        if (errors.length > 0) {
            if (json_mode) {
                print_status_report_json("FAIL", rc_path, warnings, errors, 1);
            } else {
                print_status_report("FAIL", rc_path, warnings, errors);
            }
            return 1;
        }

        if (warnings.length > 0) {
            int exit_code = strict_mode ? 1 : 0;
            if (json_mode) {
                print_status_report_json("WARN", rc_path, warnings, errors, exit_code);
            } else {
                print_status_report("WARN", rc_path, warnings, errors);
            }
            return exit_code;
        }

        if (json_mode) {
            print_status_report_json("PASS", rc_path, warnings, errors, 0);
        } else {
            print_status_report("PASS", rc_path, warnings, errors);
        }
        return 0;
    }

    public static int main(string[] args) {
        bool debug = false;
        bool keyboard_tab = false;
        bool test_config = false;
        bool strict_mode = false;
        bool json_mode = false;
        string? config_override = null;
        string[] gtk_args = {};

        Intl.setlocale(LocaleCategory.ALL, "");
        Intl.bindtextdomain("labconf", "/usr/share/locale");
        Intl.bind_textdomain_codeset("labconf", "UTF-8");
        Intl.textdomain("labconf");

        for (int i = 0; i < args.length; i++) {
            if (args[i] == "-d") {
                debug = true;
                continue;
            }

            if (args[i] == "-k") {
                keyboard_tab = true;
                continue;
            }

            if (args[i] == "-t" || args[i] == "--test-config") {
                test_config = true;
                continue;
            }

            if (args[i] == "--strict") {
                strict_mode = true;
                continue;
            }

            if (args[i] == "--json") {
                json_mode = true;
                continue;
            }

            if (args[i] == "-c" || args[i] == "--config") {
                if (i + 1 >= args.length) {
                    stderr.printf("Missing value for %s\n", args[i]);
                    return 1;
                }
                i++;
                config_override = args[i].strip();
                continue;
            }

            if (args[i].has_prefix("--config=")) {
                config_override = args[i].substring("--config=".length).strip();
                continue;
            }

            if (args[i] == "--help" || args[i] == "-h") {
                stdout.printf("%s\n", tr("Usage: labconf [options]"));
                stdout.printf("  %-24s %s\n", "-d", tr("Enable debug logging to /tmp/labconf-debug.log"));
                stdout.printf("  %-24s %s\n", "-k", tr("Open directly on Keyboard tab"));
                stdout.printf("  %-24s %s\n", "-c, --config <path>", tr("Use explicit rc.xml path"));
                stdout.printf("  %-24s %s\n", "-t, --test-config", tr("Validate rc.xml compatibility and exit"));
                stdout.printf("  %-24s %s\n", "--strict", tr("Treat warnings as failure in test mode"));
                stdout.printf("  %-24s %s\n", "--json", tr("Print test result as JSON"));
                stdout.printf("  %-24s %s\n", "-h, --help", tr("Show this help and exit"));
                return 0;
            }

            gtk_args += args[i];
        }

        if (config_override != null && config_override.strip() != "") {
            Environment.set_variable("LABCONF_RC_PATH", config_override.strip(), true);
        }

        if (test_config) {
            return run_config_test_mode(config_override, strict_mode, json_mode);
        }

        unowned string[] gtk_args_ref = gtk_args;
        Gtk.init(ref gtk_args_ref);
        new ThemeSelector(debug, keyboard_tab ? StartupTab.KEYBOARD : StartupTab.DEFAULT).show_all();
        Gtk.main();
        return 0;
    }
}
