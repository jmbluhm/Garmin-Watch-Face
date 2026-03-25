using Toybox.Application;
using Toybox.WatchUi;

class RedLineApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        return [new RedLineView(), new RedLineDelegate()];
    }
}
