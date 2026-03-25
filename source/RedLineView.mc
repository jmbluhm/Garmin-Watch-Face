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

    // Colors
    hidden const CLR_PRIMARY   = 0xCC1111;
    hidden const CLR_SECONDARY = 0x882222;
    hidden const CLR_GHOST     = 0x330000;
    hidden const CLR_BG        = 0x000000;

    // Day-of-week lookup (1=Sun per Gregorian)
    hidden var _dayNames = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    hidden var _monNames = ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    // Custom font reference
    private var _fontTime;

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

    // Font height caches
    var _hTime;
    var _hSmall;
    var _hTiny;

    // Sleep state
    var _sleeping = false;

    // Pre-allocated polygon arrays for icons
    var _heartPoly;
    var _boltPoly;

    function initialize() {
        WatchFace.initialize();
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

        // ── Proportional layout for round screen ─────────────────────
        //
        // Round screen geometry: at vertical offset dy from center,
        // usable chord width = 2 * sqrt(r² - dy²) where r = width/2.
        //
        // All y positions are percentages of screen height:
        //   Battery %:   10%  (near top edge, tight to bezel)
        //   Date:        30%  (closer to time, more space from battery)
        //   Time:        50%  (dead center)
        //   Divider:     time + hTime/2 + 3%
        //   Grid row 1:  67%  (dy=77  → chord=426px)
        //   Grid row 2:  81%  (dy=141 → chord=348px)
        //
        // Bottom grid pushed closer to edge (81%) — round bezel still
        // provides ~348px chord, plenty for icon+value.

        _yBattText = _height * 10 / 100;
        _yDate     = _height * 26 / 100;
        _yTime     = _cy;
        _yDivider  = _yTime + _hTime / 2 + _height * 3 / 100;
        _yGrid1    = _height * 67 / 100;
        _yGrid2    = _height * 81 / 100;

        // Grid x positions — wider spread, proportional
        // At y=81% (worst case), chord ≈ 348px → safe from x=53 to x=401
        _xLeft  = _cx - _width * 25 / 100;
        _xRight = _cx + _width * 5 / 100;

        // Pre-allocate icon polygons
        _heartPoly = [[0, 0], [0, 0], [0, 0]];
        _boltPoly = [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0]];

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
        _drawDataGrid(dc, actInfo, monInfo, weather);
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
        dc.drawText(_cx, _yDate, Graphics.FONT_SMALL, fullStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawDivider(dc) {
        var divW = _width * 35 / 100;
        dc.setColor(CLR_GHOST, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx - divW / 2, _yDivider, divW, 1);
    }

    function _drawDataGrid(dc, actInfo, monInfo, weather) {
        // HR (top-left)
        var hr = (actInfo != null && actInfo.currentHeartRate != null)
                 ? actInfo.currentHeartRate.toString() : "--";
        _drawHeartIcon(dc, _xLeft, _yGrid1 - 4);
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_xLeft + 18, _yGrid1, Graphics.FONT_SMALL, hr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Steps (top-right)
        var steps = (monInfo != null) ? _formatSteps(monInfo.steps) : "--";
        _drawStepsIcon(dc, _xRight, _yGrid1 - 4);
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_xRight + 18, _yGrid1, Graphics.FONT_SMALL, steps,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Temp (bottom-left)
        var tempStr = "--";
        if (weather != null && weather.temperature != null) {
            var tempF = (weather.temperature.toFloat() * 9.0 / 5.0 + 32.0).toNumber();
            tempStr = tempF.toString();
        }
        _drawTempIcon(dc, _xLeft, _yGrid2 - 4);
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_xLeft + 18, _yGrid2, Graphics.FONT_SMALL, tempStr + "F",
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Body Battery (bottom-right)
        var bbStr = "--";
        if (monInfo != null && monInfo has :bodyBattery && monInfo.bodyBattery != null) {
            bbStr = monInfo.bodyBattery.toString();
        }
        _drawBoltIcon(dc, _xRight, _yGrid2 - 4);
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_xRight + 18, _yGrid2, Graphics.FONT_SMALL, bbStr,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawHeartIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + 4, y, 4);
        dc.fillCircle(x + 10, y, 4);
        _heartPoly[0] = [x, y + 2];
        _heartPoly[1] = [x + 14, y + 2];
        _heartPoly[2] = [x + 7, y + 10];
        dc.fillPolygon(_heartPoly);
    }

    function _drawStepsIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x,      y + 6, 4, 6);
        dc.fillRectangle(x + 5,  y + 3, 4, 9);
        dc.fillRectangle(x + 10, y,     4, 12);
    }

    function _drawTempIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 4, y, 4, 8);
        dc.fillCircle(x + 6, y + 10, 4);
    }

    function _drawBoltIcon(dc, x, y) {
        dc.setColor(CLR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        _boltPoly[0] = [x + 8, y];
        _boltPoly[1] = [x + 3, y + 7];
        _boltPoly[2] = [x + 6, y + 7];
        _boltPoly[3] = [x + 4, y + 14];
        _boltPoly[4] = [x + 10, y + 5];
        _boltPoly[5] = [x + 7, y + 5];
        dc.fillPolygon(_boltPoly);
    }

    function _formatSteps(steps) {
        if (steps >= 1000) {
            var k = steps / 100;
            var whole = k / 10;
            var frac = k % 10;
            return whole.toString() + "." + frac.toString() + "k";
        }
        return steps.toString();
    }
}
