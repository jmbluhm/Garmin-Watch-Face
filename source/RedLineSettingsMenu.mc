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
            // Push color sub-menu — 20 MIP-palette-exact high-contrast colors
            var menu = new WatchUi.Menu2({:title => "Accent Color"});
            menu.addItem(new WatchUi.MenuItem("White",        null, 0xFFFFFF, null));
            menu.addItem(new WatchUi.MenuItem("Cream",        null, 0xFFFFAA, null));
            menu.addItem(new WatchUi.MenuItem("Yellow",       null, 0xFFFF00, null));
            menu.addItem(new WatchUi.MenuItem("Light Yellow", null, 0xFFFF55, null));
            menu.addItem(new WatchUi.MenuItem("Amber",        null, 0xFFAA00, null));
            menu.addItem(new WatchUi.MenuItem("Peach",        null, 0xFFAA55, null));
            menu.addItem(new WatchUi.MenuItem("Orange",       null, 0xFF5500, null));
            menu.addItem(new WatchUi.MenuItem("Red",          null, 0xFF0000, null));
            menu.addItem(new WatchUi.MenuItem("Coral",        null, 0xFF5555, null));
            menu.addItem(new WatchUi.MenuItem("Hot Pink",     null, 0xFF55AA, null));
            menu.addItem(new WatchUi.MenuItem("Magenta",      null, 0xFF55FF, null));
            menu.addItem(new WatchUi.MenuItem("Lavender",     null, 0xAAAAFF, null));
            menu.addItem(new WatchUi.MenuItem("Purple",       null, 0xAA55FF, null));
            menu.addItem(new WatchUi.MenuItem("Sky Blue",     null, 0x55AAFF, null));
            menu.addItem(new WatchUi.MenuItem("Cyan",         null, 0x00FFFF, null));
            menu.addItem(new WatchUi.MenuItem("Ice Blue",     null, 0x55FFFF, null));
            menu.addItem(new WatchUi.MenuItem("Seafoam",      null, 0x00FFAA, null));
            menu.addItem(new WatchUi.MenuItem("Green",        null, 0x00FF00, null));
            menu.addItem(new WatchUi.MenuItem("Light Green",  null, 0x55FF55, null));
            menu.addItem(new WatchUi.MenuItem("Lime",         null, 0xAAFF00, null));
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
        // Pop submenu + parent menu so sublabels rebuild correctly next open
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
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
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.requestUpdate();
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
