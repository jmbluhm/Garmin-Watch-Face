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
using Toybox.Math;

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
    // MIP display: high contrast matters, not luminance
    hidden var CLR_PRIMARY   = 0xFF5500;
    hidden var CLR_SECONDARY = 0xAA3300;
    hidden var CLR_GHOST     = 0x551100;
    hidden var CLR_BG        = 0x000000;

    // Day-of-week lookup (1=Sun per Gregorian)
    hidden var _dayNames = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    hidden var _monNames = ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    // Font references — 2 weights
    private var _fontTime;    // light weight — active mode (backlight on)
    private var _fontBold;    // bold weight — passive/sleep mode (backlight off)

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
    var _yDivider;  // kept for safe-zone verification logging
    var _yGrid1;
    var _yGrid2;
    var _xLeft;
    var _xRight;
    var _xLeft2;
    var _xRight2;

    // Pre-allocated slot coordinate arrays
    var _slotXs;
    var _slotYs;

    // Font height caches
    var _hTime;
    var _hSmall;
    var _hTiny;

    // Sleep state
    var _sleeping = false;

    // Background preference
    private var _bgWhite = false;

    // Sensor data caches — expensive calls refreshed on intervals
    private var _cachedWeather = null;        // Weather.getCurrentConditions()
    private var _cachedBodyBattery = "--";    // SensorHistory body battery string
    private var _weatherMinute = -99;         // last refresh minute-of-day
    private var _bodyBattMinute = -99;        // last refresh minute-of-day
    hidden const WEATHER_INTERVAL = 15;       // refresh every 15 minutes
    hidden const BODY_BATT_INTERVAL = 5;      // refresh every 5 minutes

    // Pre-allocated polygon arrays for icons
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
        // Load color — MIP-optimized preset palette
        var color = Application.Properties.getValue("foregroundColor");
        if (color != null && color instanceof Number) {
            CLR_PRIMARY = color;
        } else {
            CLR_PRIMARY = 0xFF5500;
        }
        // Lookup secondary (~65%) and ghost (~35%) per color
        // Preset values tuned for MIP 64-color palette contrast
        CLR_SECONDARY = _lookupSecondary(CLR_PRIMARY);
        CLR_GHOST = _lookupDim(CLR_PRIMARY);

        // Load background preference
        var bgPref = Application.Properties.getValue("BackgroundColor");
        _bgWhite = (bgPref != null && bgPref instanceof Number && bgPref == 1);
        CLR_BG = _bgWhite ? 0xFFFFFF : 0x000000;

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

    hidden function _lookupSecondary(primary) {
        switch (primary) {
            case 0xFFFFFF: return 0xAAAAAA;
            case 0xFFAA00: return 0xAA7700;
            case 0xFF5500: return 0xAA3300;
            case 0x00FF00: return 0x00AA00;
            case 0x00FFFF: return 0x00AAAA;
            case 0xFFFF00: return 0xAAAA00;
            case 0xFF5555: return 0xAA3333;
            case 0x55AAFF: return 0x3377AA;
        }
        // Fallback: derive mathematically
        var r = (primary >> 16) & 0xFF;
        var g = (primary >> 8) & 0xFF;
        var b = primary & 0xFF;
        return ((r * 2 / 3) << 16) | ((g * 2 / 3) << 8) | (b * 2 / 3);
    }

    hidden function _lookupDim(primary) {
        switch (primary) {
            case 0xFFFFFF: return 0x555555;
            case 0xFFAA00: return 0x553300;
            case 0xFF5500: return 0x551100;
            case 0x00FF00: return 0x005500;
            case 0x00FFFF: return 0x005555;
            case 0xFFFF00: return 0x555500;
            case 0xFF5555: return 0x551111;
            case 0x55AAFF: return 0x113355;
        }
        // Fallback: derive mathematically
        var r = (primary >> 16) & 0xFF;
        var g = (primary >> 8) & 0xFF;
        var b = primary & 0xFF;
        return ((r / 3) << 16) | ((g / 3) << 8) | (b / 3);
    }

    function onLayout(dc) {
        _width  = dc.getWidth();
        _height = dc.getHeight();
        _cx     = _width / 2;
        _cy     = _height / 2;

        // Load font weights
        _fontTime = WatchUi.loadResource(Rez.Fonts.DSEG7Time);
        _fontBold = WatchUi.loadResource(Rez.Fonts.DSEG7Bold);

        // Use bold for layout measurements (it's the larger of the two)
        _hTime  = dc.getFontHeight(_fontBold);
        _hSmall = dc.getFontHeight(Graphics.FONT_SMALL);
        _hTiny  = dc.getFontHeight(Graphics.FONT_TINY);

        var testW = dc.getTextWidthInPixels("00:00:00", _fontBold);
        System.println("hTime=" + _hTime + " hSmall=" + _hSmall +
                       " hTiny=" + _hTiny + " boldTimeW=" + testW +
                       " screen=" + _width);

        // Proportional layout — top chunk scooted down, compact widget grid
        _yBattText = _height * 11 / 100;
        _yDate     = _height * 25 / 100;
        _yTime     = _cy;
        _yDivider  = _yTime + _hTime / 2 + _height * 2 / 100;
        _yGrid1    = _height * 68 / 100;
        _yGrid2    = _height * 80 / 100;

        // Top row grid x positions — symmetric anchors, 105px from centre
        _xLeft  = _cx - 105;
        _xRight = _cx + 5;

        // Bottom row grid x positions — tighter horizontally (OK to be narrower)
        _xLeft2  = _cx - 85;
        _xRight2 = _cx + 5;

        // Safe zone verification — check every row fits
        var rows = [_yDate, _yTime, _yDivider, _yGrid1, _yGrid2, _yBattText];
        var names = ["Date", "Time", "Divider", "Grid1", "Grid2", "Batt"];
        for (var i = 0; i < rows.size(); i++) {
            System.println(names[i] + " y=" + rows[i] +
                           " safeWidth=" + (_safeHalfWidth(rows[i]) * 2));
        }

        // Check time row for clipping and report slack for font size iteration
        var timeTestStr = "00:00:00";
        var timeW = dc.getTextWidthInPixels(timeTestStr, _fontBold);
        var safeW = _safeHalfWidth(_yTime) * 2;
        var slack = safeW - timeW;
        if (timeW > safeW) {
            System.println("TIME TOO WIDE — reduce font size in fonts.xml by 2px (timeW=" + timeW + " safeW=" + safeW + ")");
        } else {
            System.println("Font fit OK: timeW=" + timeW + " safeW=" + safeW + " slack=" + slack + "px" +
                           (slack > 20 ? " — consider increasing font size" : " — good fit"));
        }

        // Enforce safe width for top grid row
        var safeG1 = _safeHalfWidth(_yGrid1);
        var maxRight1 = _cx + safeG1 - 4;
        if (_xRight + 80 > maxRight1) {
            var shift = (_xRight + 80) - maxRight1;
            _xLeft  = _xLeft  - shift;
            _xRight = _xRight - shift;
            System.println("Grid1 shifted inward by " + shift + "px");
        }

        // Enforce safe width for bottom grid row
        var safeG2 = _safeHalfWidth(_yGrid2);
        var maxRight2 = _cx + safeG2 - 4;
        if (_xRight2 + 80 > maxRight2) {
            var shift = (_xRight2 + 80) - maxRight2;
            _xLeft2  = _xLeft2  - shift;
            _xRight2 = _xRight2 - shift;
            System.println("Grid2 shifted inward by " + shift + "px");
        }

        // Update slot coordinates — bottom row uses tighter x positions
        _slotXs = [_xLeft, _xRight, _xLeft2, _xRight2];
        _slotYs = [_yGrid1, _yGrid1, _yGrid2, _yGrid2];

        // Pre-allocate icon polygons
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

        // Always draw the full face — even in sleep mode onUpdate only fires
        // once per minute so this is not expensive. The Light button may not
        // trigger onExitSleep, so we must always render widgets.
        var now       = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var actInfo   = Activity.getActivityInfo();
        var monInfo   = ActivityMonitor.getInfo();
        var sysStat   = System.getSystemStats();

        // Expensive calls — cached with interval-based refresh
        var minuteOfDay = clockTime.hour * 60 + clockTime.min;
        _refreshCaches(minuteOfDay);

        _drawBatteryText(dc, sysStat);
        _drawDate(dc, now);
        _drawTime(dc, clockTime);
        _drawDataGrid(dc, actInfo, monInfo, _cachedWeather, sysStat);
    }

    // Refresh expensive sensor caches on their respective intervals
    hidden function _refreshCaches(minuteOfDay) {
        // Weather: refresh every 15 minutes
        var weatherAge = minuteOfDay - _weatherMinute;
        if (weatherAge < 0) { weatherAge = weatherAge + 1440; } // midnight wrap
        if (weatherAge >= WEATHER_INTERVAL || _cachedWeather == null) {
            _cachedWeather = Weather.getCurrentConditions();
            _weatherMinute = minuteOfDay;
        }

        // Body battery: refresh every 5 minutes
        var bbAge = minuteOfDay - _bodyBattMinute;
        if (bbAge < 0) { bbAge = bbAge + 1440; }
        if (bbAge >= BODY_BATT_INTERVAL) {
            _cachedBodyBattery = _getBodyBattery();
            _bodyBattMinute = minuteOfDay;
        }
    }

    function onPartialUpdate(dc) {
        // In sleep mode we only show HH:MM (no seconds) — skip partial updates
        // This saves battery: no per-second redraws when backlight is off
        if (_sleeping) {
            return;
        }

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
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    // Returns maximum half-width in pixels for content at a given y position
    // Accounts for circular screen geometry + 14px buffer from edge
    private function _safeHalfWidth(y) {
        var dy = (y - _cy).abs().toFloat();
        var r  = _cy.toFloat();
        if (dy >= r) { return 0; }
        return (Math.sqrt(r * r - dy * dy) - 14.0).toNumber();
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

        // Light font when active, bold when passive (better MIP readability without backlight)
        var font = _sleeping ? _fontBold : _fontTime;

        var hrStr  = h12.format("%02d");
        var minStr = clockTime.min.format("%02d");

        // Always show HH:MM:SS format — in passive mode freeze seconds at "00"
        var secStr = _sleeping ? "00" : clockTime.sec.format("%02d");
        var timeStr = hrStr + ":" + minStr + ":" + secStr;

        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _yTime, font, timeStr, justify);

        // PM indicator: small filled dot, top-right of time block
        if (isPM) {
            var timeW = dc.getTextWidthInPixels(timeStr, font);
            var dotX  = _cx + timeW / 2 + _width * 2 / 100;
            var dotY  = _yTime - dc.getFontHeight(font) / 2 + _height * 1 / 100;
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
                val = _cachedBodyBattery;
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

    // Heart icon: 10-point polygon tracing classic heart silhouette (~14x13px)
    function _drawHeartIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x + 7,  y + 12],
            [x + 1,  y + 5],
            [x + 1,  y + 2],
            [x + 3,  y + 0],
            [x + 5,  y + 0],
            [x + 7,  y + 3],
            [x + 9,  y + 0],
            [x + 11, y + 0],
            [x + 13, y + 2],
            [x + 13, y + 5]
        ]);
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

    // ── Data helpers ────────────────────────────────────────

    // Body battery via SensorHistory (ActivityMonitor.bodyBattery returns null on fenix7pro)
    function _getBodyBattery() {
        if ((Toybox has :SensorHistory) &&
            (Toybox.SensorHistory has :getBodyBatteryHistory)) {
            var iter = Toybox.SensorHistory.getBodyBatteryHistory({ :period => 1 });
            if (iter != null) {
                var sample = iter.next();
                if (sample != null && sample.data != null) {
                    var val = sample.data;
                    if (val >= 0 && val <= 100) {
                        return val.toNumber().toString();
                    }
                }
            }
        }
        return "--";
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
