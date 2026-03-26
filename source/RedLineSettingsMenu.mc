using Toybox.Application;
using Toybox.WatchUi;

class RedLineSettingsDelegate extends WatchUi.Menu2InputDelegate {

    hidden var _view;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item) {
        var id = item.getId();

        if (id.equals("background")) {
            // Push background sub-menu
            var menu = new WatchUi.Menu2({:title => "Background"});
            menu.addItem(new WatchUi.MenuItem("Black", null, 0, null));
            menu.addItem(new WatchUi.MenuItem("White", null, 1, null));
            WatchUi.pushView(menu, new BackgroundPickerDelegate(_view), WatchUi.SLIDE_LEFT);
        } else if (id.equals("color")) {
            // Push color sub-menu
            var menu = new WatchUi.Menu2({:title => "Accent Color"});
            menu.addItem(new WatchUi.MenuItem("Red",    null, 0xFF3300, null));
            menu.addItem(new WatchUi.MenuItem("Orange", null, 0xFF5500, null));
            menu.addItem(new WatchUi.MenuItem("Amber",  null, 0xFFAA00, null));
            menu.addItem(new WatchUi.MenuItem("Yellow", null, 0xFFFF00, null));
            menu.addItem(new WatchUi.MenuItem("Green",  null, 0x00CC00, null));
            menu.addItem(new WatchUi.MenuItem("Cyan",   null, 0x00CCCC, null));
            menu.addItem(new WatchUi.MenuItem("Blue",   null, 0x3399FF, null));
            menu.addItem(new WatchUi.MenuItem("Purple", null, 0xAA44FF, null));
            menu.addItem(new WatchUi.MenuItem("Pink",   null, 0xFF44AA, null));
            menu.addItem(new WatchUi.MenuItem("White",  null, 0xFFFFFF, null));
            WatchUi.pushView(menu, new ColorPickerDelegate(_view), WatchUi.SLIDE_LEFT);
        } else {
            // It's a widget slot key (widget1-widget4) — push widget picker sub-menu
            var menu = new WatchUi.Menu2({:title => "Select Widget"});
            menu.addItem(new WatchUi.MenuItem("None",         null, 0,  null));
            menu.addItem(new WatchUi.MenuItem("Heart Rate",   null, 1,  null));
            menu.addItem(new WatchUi.MenuItem("Steps",        null, 2,  null));
            menu.addItem(new WatchUi.MenuItem("Calories",     null, 3,  null));
            menu.addItem(new WatchUi.MenuItem("Distance",     null, 4,  null));
            menu.addItem(new WatchUi.MenuItem("Floors",       null, 5,  null));
            menu.addItem(new WatchUi.MenuItem("Active Min",   null, 6,  null));
            menu.addItem(new WatchUi.MenuItem("Body Battery", null, 7,  null));
            menu.addItem(new WatchUi.MenuItem("Stress",       null, 8,  null));
            menu.addItem(new WatchUi.MenuItem("Respiration",  null, 9,  null));
            menu.addItem(new WatchUi.MenuItem("Temperature",  null, 10, null));
            menu.addItem(new WatchUi.MenuItem("Humidity",     null, 11, null));
            menu.addItem(new WatchUi.MenuItem("Battery %",    null, 12, null));
            menu.addItem(new WatchUi.MenuItem("Altitude",     null, 13, null));
            menu.addItem(new WatchUi.MenuItem("Sunrise",      null, 14, null));
            menu.addItem(new WatchUi.MenuItem("Sunset",       null, 15, null));
            menu.addItem(new WatchUi.MenuItem("Blood Oxygen", null, 16, null));
            WatchUi.pushView(menu, new WidgetPickerDelegate(_view, id), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

// Handles color selection from the color sub-menu
class ColorPickerDelegate extends WatchUi.Menu2InputDelegate {

    hidden var _view;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item) {
        var colorVal = item.getId();
        Application.Properties.setValue("foregroundColor", colorVal);
        _view.loadSettings();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.requestUpdate();
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// Handles background selection
class BackgroundPickerDelegate extends WatchUi.Menu2InputDelegate {

    hidden var _view;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item) {
        var bgVal = item.getId();
        Application.Properties.setValue("BackgroundColor", bgVal);
        _view.loadSettings();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.requestUpdate();
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// Handles widget type selection for a specific slot
class WidgetPickerDelegate extends WatchUi.Menu2InputDelegate {

    hidden var _view;
    hidden var _slotKey;

    function initialize(view, slotKey) {
        Menu2InputDelegate.initialize();
        _view = view;
        _slotKey = slotKey;
    }

    function onSelect(item) {
        var widgetId = item.getId();
        Application.Properties.setValue(_slotKey, widgetId);
        _view.loadSettings();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.requestUpdate();
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
