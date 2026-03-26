using Toybox.Application;
using Toybox.WatchUi;

class RedLineApp extends Application.AppBase {

    hidden var _view;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        _view = new RedLineView();
        return [_view, new RedLineDelegate(_view)];
    }

    // Hook into on-watch Customize menu (MENU → Watch Face → RedLine → Customize)
    function getSettingsView() {
        var menu = new WatchUi.Menu2({:title => "Settings"});

        var slotNames = ["Top Left", "Top Right", "Bottom Left", "Bottom Right"];
        var slotKeys  = ["widget1", "widget2", "widget3", "widget4"];
        for (var i = 0; i < 4; i++) {
            var current = Application.Properties.getValue(slotKeys[i]);
            if (current == null || !(current instanceof Number)) { current = 0; }
            menu.addItem(new WatchUi.MenuItem(
                slotNames[i], _widgetLabel(current), slotKeys[i], null));
        }

        var curColor = Application.Properties.getValue("foregroundColor");
        menu.addItem(new WatchUi.MenuItem(
            "Accent Color", _colorLabel(curColor), "color", null));

        var curBg = Application.Properties.getValue("BackgroundColor");
        var bgLabel = (curBg != null && curBg == 1) ? "White" : "Black";
        menu.addItem(new WatchUi.MenuItem(
            "Background", bgLabel, "background", null));

        return [menu, new RedLineSettingsDelegate(_view)];
    }

    function onSettingsChanged() {
        if (_view != null) {
            _view.loadSettings();
        }
        WatchUi.requestUpdate();
    }

    // Widget type ID -> display label
    hidden function _widgetLabel(id) {
        switch (id) {
            case 0:  return "None";
            case 1:  return "Heart Rate";
            case 2:  return "Steps";
            case 3:  return "Calories";
            case 4:  return "Distance";
            case 5:  return "Floors";
            case 6:  return "Active Min";
            case 7:  return "Body Battery";
            case 8:  return "Stress";
            case 9:  return "Respiration";
            case 10: return "Temperature";
            case 11: return "Humidity";
            case 12: return "Battery %";
            case 13: return "Altitude";
            case 14: return "Sunrise";
            case 15: return "Sunset";
            case 16: return "Blood Oxygen";
        }
        return "None";
    }

    // Color value -> display label (20 MIP-palette-exact colors)
    hidden function _colorLabel(val) {
        if (val == null) { return "Orange"; }
        switch (val) {
            case 0xFFFFFF: return "White";
            case 0xFFFFAA: return "Cream";
            case 0xFFFF00: return "Yellow";
            case 0xFFFF55: return "Light Yellow";
            case 0xFFAA00: return "Amber";
            case 0xFFAA55: return "Peach";
            case 0xFF5500: return "Orange";
            case 0xFF0000: return "Red";
            case 0xFF5555: return "Coral";
            case 0xFF55AA: return "Hot Pink";
            case 0xFF55FF: return "Magenta";
            case 0xAAAAFF: return "Lavender";
            case 0xAA55FF: return "Purple";
            case 0x55AAFF: return "Sky Blue";
            case 0x00FFFF: return "Cyan";
            case 0x55FFFF: return "Ice Blue";
            case 0x00FFAA: return "Seafoam";
            case 0x00FF00: return "Green";
            case 0x55FF55: return "Light Green";
            case 0xAAFF00: return "Lime";
        }
        return "Custom";
    }
}
