/*
 * Copyright (c) 2011-2018 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 */

public class Wingpanel.Application : Gtk.Application {
    private const string LIST_INDICATORS_ACTION_NAME = "list-indicators";
    private const string OPEN_INDICATOR_ACTION_NAME = "open-indicator";
    private const string CLOSE_INDICATOR_ACTION_NAME = "close-indicator";
    private const string SERVER_TYPE_ACTION_NAME = "greeter";
    private const string TOGGLE_INDICATOR_ACTION_NAME = "toggle-indicator";

    private const OptionEntry[] OPTIONS = {
        { OPEN_INDICATOR_ACTION_NAME, 'o', 0, OptionArg.STRING, null, "Open an indicator", "code_name" },
        { CLOSE_INDICATOR_ACTION_NAME, 'c', 0, OptionArg.STRING, null, "Close an indicator", "code_name" },
        { SERVER_TYPE_ACTION_NAME, 'g', 0, OptionArg.NONE, null, "Server is a greeter", null },
        { TOGGLE_INDICATOR_ACTION_NAME, 't', 0, OptionArg.STRING, null, "Toggle an indicator", "code_name" },
        { null }
    };

    private PanelWindow? panel_window = null;

    construct {
        flags = ApplicationFlags.HANDLES_COMMAND_LINE;
        application_id = "org.elementary.wingpanel";

        add_main_option_entries (OPTIONS);

        register_with_session.begin ((obj, res) => {
            bool success = register_with_session.end (res);
            if (!success) {
                warning ("Failed to register with Session manager");
            }
        });
    }

    private async bool register_with_session () {
        var sclient = yield SessionManager.register_with_session ("io.elementary.wingpanel");
        if (sclient == null) {
            return false;
        }

        sclient.query_end_session.connect ((flags) => session_respond (sclient, flags));
        sclient.end_session.connect ((flags) => session_respond (sclient, flags));
        sclient.stop.connect (session_stop);

        return true;
    }

    private void session_respond (SessionManager.SessionClient sclient, uint flags) {
        try {
            sclient.end_session_response (true, "");
        } catch (Error e) {
            warning ("Unable to respond to session manager: %s", e.message);
        }
    }

    private void session_stop () {
        if (panel_window != null) {
            panel_window.destroy ();
        }
    }

    protected override int command_line (ApplicationCommandLine command_line) {
        VariantDict options = command_line.get_options_dict ();

        if (options.contains (SERVER_TYPE_ACTION_NAME)) {
            IndicatorManager.get_default ().initialize (IndicatorManager.ServerType.GREETER);
        } else {
            IndicatorManager.get_default ().initialize (IndicatorManager.ServerType.SESSION);

            var granite_settings = Granite.Settings.get_default ();
            var gtk_settings = Gtk.Settings.get_default ();

            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

            granite_settings.notify["prefers-color-scheme"].connect (() => {
                gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            });
        }

        if (options.contains (OPEN_INDICATOR_ACTION_NAME)) {
            activate_action (OPEN_INDICATOR_ACTION_NAME, options.lookup_value (OPEN_INDICATOR_ACTION_NAME, VariantType.STRING));
        }

        if (options.contains (CLOSE_INDICATOR_ACTION_NAME)) {
            activate_action (CLOSE_INDICATOR_ACTION_NAME, options.lookup_value (CLOSE_INDICATOR_ACTION_NAME, VariantType.STRING));
        }

        if (options.contains (TOGGLE_INDICATOR_ACTION_NAME)) {
            activate_action (TOGGLE_INDICATOR_ACTION_NAME, options.lookup_value (TOGGLE_INDICATOR_ACTION_NAME, VariantType.STRING));
        }

        return 0;
    }

    protected override void startup () {
        base.startup ();

        panel_window = new PanelWindow (this);
        panel_window.show_all ();

        register_actions ();
    }

    protected override void activate () {
        /* Do nothing */
    }

    private void register_actions () {
        SimpleAction list_indicators_action = new SimpleAction.stateful (LIST_INDICATORS_ACTION_NAME, null, new Variant.strv (list_indicators ()));

        IndicatorManager indicator_manager = IndicatorManager.get_default ();
        indicator_manager.indicator_added.connect (() => {
            list_indicators_action.set_state (new Variant.strv (list_indicators ()));
        });
        indicator_manager.indicator_removed.connect (() => {
            list_indicators_action.set_state (new Variant.strv (list_indicators ()));
        });

        SimpleAction open_indicator_action = new SimpleAction (OPEN_INDICATOR_ACTION_NAME, VariantType.STRING);
        open_indicator_action.activate.connect ((parameter) => {
            if (panel_window == null) {
                return;
            }

            panel_window.popover_manager.set_popover_visible (parameter.get_string (), true);
        });

        SimpleAction close_indicator_action = new SimpleAction (CLOSE_INDICATOR_ACTION_NAME, VariantType.STRING);
        close_indicator_action.activate.connect ((parameter) => {
            if (panel_window == null) {
                return;
            }

            panel_window.popover_manager.set_popover_visible (parameter.get_string (), false);
        });

        SimpleAction toggle_indicator_action = new SimpleAction (TOGGLE_INDICATOR_ACTION_NAME, VariantType.STRING);
        toggle_indicator_action.activate.connect ((parameter) => {
            if (panel_window == null) {
                return;
            }

            panel_window.popover_manager.toggle_popover_visible (parameter.get_string ());
        });

        this.add_action (list_indicators_action);
        this.add_action (open_indicator_action);
        this.add_action (close_indicator_action);
        this.add_action (toggle_indicator_action);
    }

    private string[] list_indicators () {
        string[] code_names = {};

        foreach (Indicator indicator in IndicatorManager.get_default ().get_indicators ()) {
            code_names += indicator.code_name;
        }

        return code_names;
    }

    public static int main (string[] args) {
        return new Wingpanel.Application ().run (args);
    }
}

#if TRANSLATION
_("A super sexy space-saving top panel");
#endif
