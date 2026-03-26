using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;

class RedLineDelegate extends WatchUi.WatchFaceDelegate {

    hidden var _view;

    function initialize(view) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onMenu() {
        var menu = new WatchUi.Menu2({:title => "Settings"});

        // Widget slot items — show current selection as sublabel
        var slotNames = ["Top Left", "Top Right", "Bottom Left", "Bottom Right"];
        var slotKeys  = ["widget1", "widget2", "widget3", "widget4"];
        for (var i = 0; i < 4; i++) {
            var current = Application.Properties.getValue(slotKeys[i]);
            if (current == null || !(current instanceof Number)) { current = 0; }
            menu.addItem(new WatchUi.MenuItem(
                slotNames[i], _widgetLabel(current), slotKeys[i], null));
        }

        // Color item
        var curColor = Application.Properties.getValue("foregroundColor");
        menu.addItem(new WatchUi.MenuItem(
            "Accent Color", _colorLabel(curColor), "color", null));

        // Background item
        var curBg = Application.Properties.getValue("BackgroundColor");
        var bgLabel = (curBg != null && curBg == 1) ? "White" : "Black";
        menu.addItem(new WatchUi.MenuItem(
            "Background", bgLabel, "background", null));

        WatchUi.pushView(menu, new RedLineSettingsDelegate(_view), WatchUi.SLIDE_UP);
        return true;
    }

    function onPowerBudgetExceeded(powerInfo) {
        System.println("WARNING: Power budget exceeded in onPartialUpdate");
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

    // Color value -> display label
    hidden function _colorLabel(val) {
        if (val == null) { return "Red"; }
        switch (val) {
            case 0xFF3300: return "Red";
            case 0xFF5500: return "Orange";
            case 0xFFAA00: return "Amber";
            case 0xFFFF00: return "Yellow";
            case 0x00CC00: return "Green";
            case 0x00CCCC: return "Cyan";
            case 0x3399FF: return "Blue";
            case 0xAA44FF: return "Purple";
            case 0xFF44AA: return "Pink";
            case 0xFFFFFF: return "White";
        }
        return "Custom";
    }
}
