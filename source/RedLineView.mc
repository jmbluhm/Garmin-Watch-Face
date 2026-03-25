using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.Weather;

class RedLineView extends WatchUi.WatchFace {

    // Widget type constants
    hidden const W_NONE        = 0;
    hidden const W_HR          = 1;
    hidden const W_STEPS       = 2;
    hidden const W_CALORIES    = 3;
    hidden const W_DISTANCE    = 4;
    hidden const W_FLOORS      = 5;
    hidden const W_ACTIVE_MIN  = 6;
    hidden const W_BODY_BATT   = 7;
    hidden const W_STRESS      = 8;
    hidden const W_RESPIRATION = 9;
    hidden const W_TEMP        = 10;
    hidden const W_HUMIDITY    = 11;
    hidden const W_DEV_BATT    = 12;
    hidden const W_ALTITUDE    = 13;
    hidden const W_SUNRISE     = 14;
    hidden const W_SUNSET      = 15;
    hidden const W_SPO2        = 16;

    // Colors (loaded from settings)
    hidden var CLR_PRIMARY   = 0xCC1111;
    hidden var CLR_SECONDARY = 0x661111;
    hidden var CLR_GHOST     = 0x330000;
    hidden const CLR_BG      = 0x000000;

    // Day-of-week lookup (1=Sun per Gregorian)
    hidden var _dayNames = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    hidden var _monNames = ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    // Custom font reference
    private var _fontTime;

    // Widget slot configuration (loaded from settings)
    hidden var _widgetSlots = [1, 2, 10, 7];

    // Cached layout coordinates
    var _width;
    var _height;
    var _cx;
    var _cy;
    var _yBattText;
    var _yDate;
    var _yTime;
    var _yDivider;
    var _yGrid1;
    var _yGrid2;
    var _xLeft;
    var _xRight;

    // Pre-allocated slot coordinate arrays
    var _slotXs;
    var _slotYs;

    // Font height caches
    var _hTime;
    var _hSmall;
    var _hTiny;

    // Sleep state
    var _sleeping = false;

    // Pre-allocated polygon arrays for icons
    var _heartPoly;
    var _boltPoly;
    var _calPoly;
    var _distPoly;
    var _altPoly;
    var _dropPoly;
    var _sunPoly;

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    function loadSettings() {
        // Load color
        var color = Application.Properties.getValue("foregroundColor");
        if (color != null && color instanceof Number) {
            CLR_PRIMARY = color;
        } else {
            CLR_PRIMARY = 0xCC1111;
        }
        // Derive secondary (~50% brightness) and ghost (~25% brightness)
        var r = (CLR_PRIMARY >> 16) & 0xFF;
        var g = (CLR_PRIMARY >> 8) & 0xFF;
        var b = CLR_PRIMARY & 0xFF;
        CLR_SECONDARY = ((r / 2) << 16) | ((g / 2) << 8) | (b / 2);
        CLR_GHOST = ((r / 4) << 16) | ((g / 4) << 8) | (b / 4);

        // Load widget slots
        var w1 = Application.Properties.getValue("widget1");
        var w2 = Application.Properties.getValue("widget2");
        var w3 = Application.Properties.getValue("widget3");
        var w4 = Application.Properties.getValue("widget4");
        _widgetSlots[0] = (w1 != null && w1 instanceof Number) ? w1 : 1;
        _widgetSlots[1] = (w2 != null && w2 instanceof Number) ? w2 : 2;
        _widgetSlots[2] = (w3 != null && w3 instanceof Number) ? w3 : 10;
        _widgetSlots[3] = (w4 != null && w4 instanceof Number) ? w4 : 7;
    }

    function onLayout(dc) {
        _width  = dc.getWidth();
        _height = dc.getHeight();
        _cx     = _width / 2;
        _cy     = _height / 2;

        // Load custom font
        _fontTime = WatchUi.loadResource(Rez.Fonts.DSEG7Time);

        // Measure ACTUAL rendered heights
        _hTime  = dc.getFontHeight(_fontTime);
        _hSmall = dc.getFontHeight(Graphics.FONT_SMALL);
        _hTiny  = dc.getFontHeight(Graphics.FONT_TINY);

        var testW = dc.getTextWidthInPixels("00:00:00", _fontTime);
        System.println("hTime=" + _hTime + " hSmall=" + _hSmall +
                       " hTiny=" + _hTiny + " timeW=" + testW +
                       " screen=" + _width);

        // Proportional layout for round screen — maximize screen use
        _yBattText = _height * 7 / 100;
        _yDate     = _height * 21 / 100;
        _yTime     = _cy;
        _yDivider  = _yTime + _hTime / 2 + _height * 2 / 100;
        _yGrid1    = _height * 63 / 100;
        _yGrid2    = _height * 78 / 100;

        // Grid x positions — wider spread to fill screen
        _xLeft  = _cx - _width * 32 / 100;
        _xRight = _cx + _width * 5 / 100;

        // Pre-allocate slot coordinate arrays
        _slotXs = [_xLeft, _xRight, _xLeft, _xRight];
        _slotYs = [_yGrid1, _yGrid1, _yGrid2, _yGrid2];

        // Pre-allocate icon polygons
        _heartPoly = [[0, 0], [0, 0], [0, 0]];
        _boltPoly  = [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0]];
        _calPoly   = [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0]];
        _distPoly  = [[0, 0], [0, 0], [0, 0]];
        _altPoly   = [[0, 0], [0, 0], [0, 0]];
        _dropPoly  = [[0, 0], [0, 0], [0, 0]];
        _sunPoly   = [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0]];

        System.println("yBatt=" + _yBattText + " yDate=" + _yDate +
                       " yTime=" + _yTime + " yDiv=" + _yDivider +
                       " yG1=" + _yGrid1 + " yG2=" + _yGrid2 +
                       " xL=" + _xLeft + " xR=" + _xRight);
    }

    function onUpdate(dc) {
        dc.setColor(CLR_BG, CLR_BG);
        dc.clear();

        var clockTime = System.getClockTime();
        var now       = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var actInfo   = Activity.getActivityInfo();
        var monInfo   = ActivityMonitor.getInfo();
        var sysStat   = System.getSystemStats();
        var weather   = Weather.getCurrentConditions();

        _drawBatteryText(dc, sysStat);
        _drawDate(dc, now);
        _drawTime(dc, clockTime);
        _drawDivider(dc);
        _drawDataGrid(dc, actInfo, monInfo, weather, sysStat);
    }

    function onPartialUpdate(dc) {
        var clockTime = System.getClockTime();
        var clipY     = _yTime - _hTime / 2 - 4;
        var clipH     = _hTime + 16;

        dc.setClip(0, clipY, _width, clipH);
        dc.setColor(CLR_BG, CLR_BG);
        dc.fillRectangle(0, clipY, _width, clipH);
        _drawTime(dc, clockTime);
        dc.clearClip();
    }

    function onEnterSleep() {
        _sleeping = true;
    }

    function onExitSleep() {
        _sleeping = false;
    }

    // ── Drawing helpers ──────────────────────────────────────

    function _drawBatteryText(dc, sysStat) {
        var batt = (sysStat != null) ? sysStat.battery : 0.0;
        var pctStr = batt.toNumber().toString() + "%";
        dc.setColor(CLR_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _yBattText, Graphics.FONT_TINY, pctStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawTime(dc, clockTime) {
        var h24   = clockTime.hour;
        var isPM  = h24 >= 12;
        var h12   = h24 % 12;
        if (h12 == 0) { h12 = 12; }

        var hrStr  = h12.format("%02d");
        var minStr = clockTime.min.format("%02d");
        var secStr = clockTime.sec.format("%02d");

        var timeStr = hrStr + ":" + minStr + ":" + secStr;
        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _yTime, _fontTime, timeStr, justify);

        // PM indicator: small filled dot, top-right of time block
        if (isPM) {
            var timeW = dc.getTextWidthInPixels(timeStr, _fontTime);
            var dotX  = _cx + timeW / 2 + _width * 2 / 100;
            var dotY  = _yTime - _hTime / 2 + _height * 1 / 100;
            dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dotX, dotY, 4);
        }
    }

    function _drawDate(dc, now) {
        var dow = _dayNames[now.day_of_week];
        var mon = _monNames[now.month];
        var day = now.day.format("%d");

        var fullStr = dow + "  " + mon + " " + day;

        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _yDate, Graphics.FONT_MEDIUM, fullStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawDivider(dc) {
        var divW = _width * 50 / 100;
        dc.setColor(CLR_GHOST, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx - divW / 2, _yDivider, divW, 1);
    }

    // ── Data grid with configurable widget slots ─────────────

    function _drawDataGrid(dc, actInfo, monInfo, weather, sysStat) {
        for (var i = 0; i < 4; i++) {
            if (_widgetSlots[i] != W_NONE) {
                _drawWidget(dc, _slotXs[i], _slotYs[i], _widgetSlots[i],
                            actInfo, monInfo, weather, sysStat);
            }
        }
    }

    function _drawWidget(dc, x, y, wType, actInfo, monInfo, weather, sysStat) {
        var iconX = x;
        var iconY = y - 4;
        var val = "--";

        switch (wType) {
            case W_HR:
                _drawHeartIcon(dc, iconX, iconY);
                if (actInfo != null && actInfo.currentHeartRate != null) {
                    val = actInfo.currentHeartRate.toString();
                }
                break;
            case W_STEPS:
                _drawStepsIcon(dc, iconX, iconY);
                if (monInfo != null) {
                    val = _formatSteps(monInfo.steps);
                }
                break;
            case W_CALORIES:
                _drawCaloriesIcon(dc, iconX, iconY);
                if (monInfo != null && monInfo.calories != null) {
                    val = monInfo.calories.toString();
                }
                break;
            case W_DISTANCE:
                _drawDistanceIcon(dc, iconX, iconY);
                if (monInfo != null && monInfo.distance != null) {
                    var mi = monInfo.distance.toFloat() / 160934.0;
                    val = mi.format("%.1f");
                }
                break;
            case W_FLOORS:
                _drawFloorsIcon(dc, iconX, iconY);
                if (monInfo != null && monInfo has :floorsClimbed && monInfo.floorsClimbed != null) {
                    val = monInfo.floorsClimbed.toString();
                }
                break;
            case W_ACTIVE_MIN:
                _drawActiveMinIcon(dc, iconX, iconY);
                if (monInfo != null && monInfo has :activeMinutesWeek && monInfo.activeMinutesWeek != null) {
                    val = monInfo.activeMinutesWeek.total.toString();
                }
                break;
            case W_BODY_BATT:
                _drawBoltIcon(dc, iconX, iconY);
                if (monInfo != null && monInfo has :bodyBattery && monInfo.bodyBattery != null) {
                    val = monInfo.bodyBattery.toString();
                }
                break;
            case W_STRESS:
                _drawStressIcon(dc, iconX, iconY);
                if (monInfo != null && monInfo has :stress && monInfo.stress != null) {
                    val = monInfo.stress.toString();
                }
                break;
            case W_RESPIRATION:
                _drawRespirationIcon(dc, iconX, iconY);
                if (actInfo != null && actInfo has :respirationRate && actInfo.respirationRate != null) {
                    val = actInfo.respirationRate.toNumber().toString();
                }
                break;
            case W_TEMP:
                _drawTempIcon(dc, iconX, iconY);
                if (weather != null && weather.temperature != null) {
                    var tempF = (weather.temperature.toFloat() * 9.0 / 5.0 + 32.0).toNumber();
                    val = tempF.toString() + "F";
                }
                break;
            case W_HUMIDITY:
                _drawHumidityIcon(dc, iconX, iconY);
                if (weather != null && weather has :relativeHumidity && weather.relativeHumidity != null) {
                    val = weather.relativeHumidity.toString() + "%";
                }
                break;
            case W_DEV_BATT:
                _drawDevBattIcon(dc, iconX, iconY);
                if (sysStat != null) {
                    val = sysStat.battery.toNumber().toString() + "%";
                }
                break;
            case W_ALTITUDE:
                _drawAltitudeIcon(dc, iconX, iconY);
                if (actInfo != null && actInfo.altitude != null) {
                    var ft = (actInfo.altitude * 3.28084).toNumber();
                    val = ft.toString();
                }
                break;
            case W_SUNRISE:
                _drawSunriseIcon(dc, iconX, iconY);
                if (weather != null && weather has :sunrise && weather.sunrise != null) {
                    val = _formatMomentTime(weather.sunrise);
                }
                break;
            case W_SUNSET:
                _drawSunsetIcon(dc, iconX, iconY);
                if (weather != null && weather has :sunset && weather.sunset != null) {
                    val = _formatMomentTime(weather.sunset);
                }
                break;
            case W_SPO2:
                _drawSpO2Icon(dc, iconX, iconY);
                if (actInfo != null && actInfo has :currentOxygenSaturation && actInfo.currentOxygenSaturation != null) {
                    val = actInfo.currentOxygenSaturation.toString() + "%";
                }
                break;
        }

        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 22, y, Graphics.FONT_SMALL, val,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── Icon drawing functions ───────────────────────────────

    // Heart icon: two overlapping circles + triangle
    function _drawHeartIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 5, y - 1, 5);
        dc.fillCircle(x + 13, y - 1, 5);
        _heartPoly[0] = [x, y + 2];
        _heartPoly[1] = [x + 18, y + 2];
        _heartPoly[2] = [x + 9, y + 13];
        dc.fillPolygon(_heartPoly);
    }

    // Steps icon: three ascending bars
    function _drawStepsIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x,      y + 8, 5, 8);
        dc.fillRectangle(x + 6,  y + 4, 5, 12);
        dc.fillRectangle(x + 12, y,     5, 16);
    }

    // Calories icon: flame shape
    function _drawCaloriesIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        _calPoly[0] = [x + 8, y];
        _calPoly[1] = [x + 13, y + 6];
        _calPoly[2] = [x + 12, y + 16];
        _calPoly[3] = [x + 4, y + 16];
        _calPoly[4] = [x + 3, y + 6];
        dc.fillPolygon(_calPoly);
    }

    // Distance icon: arrow pointing right
    function _drawDistanceIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y + 6, 10, 4);
        _distPoly[0] = [x + 10, y + 2];
        _distPoly[1] = [x + 18, y + 8];
        _distPoly[2] = [x + 10, y + 14];
        dc.fillPolygon(_distPoly);
    }

    // Floors icon: staircase (3 offset blocks ascending right)
    function _drawFloorsIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x,      y + 10, 6, 6);
        dc.fillRectangle(x + 6,  y + 5,  6, 5);
        dc.fillRectangle(x + 12, y,      6, 5);
    }

    // Active minutes icon: clock face (circle + two hands)
    function _drawActiveMinIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x + 8, y + 8, 8);
        dc.drawLine(x + 8, y + 8, x + 8, y + 2);
        dc.drawLine(x + 8, y + 8, x + 13, y + 8);
    }

    // Stress icon: zigzag EKG wave
    function _drawStressIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y + 8, x + 4, y + 8);
        dc.drawLine(x + 4, y + 8, x + 7, y);
        dc.drawLine(x + 7, y, x + 10, y + 16);
        dc.drawLine(x + 10, y + 16, x + 13, y + 8);
        dc.drawLine(x + 13, y + 8, x + 18, y + 8);
    }

    // Respiration icon: sine wave approximation
    function _drawRespirationIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y + 8, x + 4, y + 2);
        dc.drawLine(x + 4, y + 2, x + 9, y + 14);
        dc.drawLine(x + 9, y + 14, x + 14, y + 2);
        dc.drawLine(x + 14, y + 2, x + 18, y + 8);
    }

    // Temperature icon: thermometer (stem + bulb)
    function _drawTempIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 5, y, 5, 10);
        dc.fillCircle(x + 7, y + 13, 5);
    }

    // Humidity icon: water droplet (triangle top + circle bottom)
    function _drawHumidityIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        _dropPoly[0] = [x + 8, y];
        _dropPoly[1] = [x + 14, y + 8];
        _dropPoly[2] = [x + 2, y + 8];
        dc.fillPolygon(_dropPoly);
        dc.fillCircle(x + 8, y + 10, 6);
    }

    // Device battery icon: battery outline with partial fill
    function _drawDevBattIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y + 2, 16, 12);
        dc.fillRectangle(x + 16, y + 5, 3, 6);
        dc.fillRectangle(x + 2, y + 4, 12, 8);
    }

    // Altitude icon: mountain peak triangle
    function _drawAltitudeIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        _altPoly[0] = [x + 9, y];
        _altPoly[1] = [x + 18, y + 16];
        _altPoly[2] = [x, y + 16];
        dc.fillPolygon(_altPoly);
    }

    // Sunrise icon: half sun above horizon with up arrow
    function _drawSunriseIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 9, y + 10, 6);
        dc.setColor(CLR_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y + 10, 18, 8);
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y + 10, x + 18, y + 10);
        // Up arrow
        dc.drawLine(x + 9, y, x + 5, y + 4);
        dc.drawLine(x + 9, y, x + 13, y + 4);
    }

    // Sunset icon: half sun above horizon with down arrow
    function _drawSunsetIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 9, y + 10, 6);
        dc.setColor(CLR_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y + 10, 18, 8);
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y + 10, x + 18, y + 10);
        // Down arrow
        dc.drawLine(x + 9, y + 5, x + 5, y + 1);
        dc.drawLine(x + 9, y + 5, x + 13, y + 1);
    }

    // SpO2 icon: O2 symbol (circle with dot inside)
    function _drawSpO2Icon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x + 8, y + 8, 8);
        dc.fillCircle(x + 8, y + 8, 3);
    }

    // Body Battery icon: lightning bolt
    function _drawBoltIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        _boltPoly[0] = [x + 10, y];
        _boltPoly[1] = [x + 4, y + 9];
        _boltPoly[2] = [x + 8, y + 9];
        _boltPoly[3] = [x + 5, y + 18];
        _boltPoly[4] = [x + 13, y + 7];
        _boltPoly[5] = [x + 9, y + 7];
        dc.fillPolygon(_boltPoly);
    }

    // ── Formatting helpers ───────────────────────────────────

    function _formatSteps(steps) {
        if (steps >= 1000) {
            var k = steps / 100;
            var whole = k / 10;
            var frac = k % 10;
            return whole.toString() + "." + frac.toString() + "k";
        }
        return steps.toString();
    }

    function _formatMomentTime(moment) {
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        var h = info.hour % 12;
        if (h == 0) { h = 12; }
        return h.toString() + ":" + info.min.format("%02d");
    }
}
