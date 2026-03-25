using Toybox.WatchUi;
using Toybox.System;

class RedLineDelegate extends WatchUi.WatchFaceDelegate {

    function initialize() {
        WatchFaceDelegate.initialize();
    }

    function onPowerBudgetExceeded(powerInfo) {
        System.println("WARNING: Power budget exceeded in onPartialUpdate");
    }
}
