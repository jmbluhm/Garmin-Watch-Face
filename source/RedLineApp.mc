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
        return [_view, new RedLineDelegate()];
    }

    function onSettingsChanged() {
        _view.loadColorSetting();
        WatchUi.requestUpdate();
    }
}
