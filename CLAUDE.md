# CLAUDE.md — Garmin Fenix 7 Pro Watch Face

## Project Overview

This is a Garmin Connect IQ watch face built in Monkey C for the **fēnix® 7 Pro** (product id: `fenix7pro`). The watch has a **454×454 MIP (Memory-in-Pixel) transflective LCD circular display**. The face is purely custom-drawn — no XML layouts, all rendering via `Graphics.Dc` in `onUpdate` / `onPartialUpdate`.

## Tech Stack

- **Language:** Monkey C
- **SDK:** Garmin Connect IQ (latest installed via SDK Manager)
- **IDE:** VS Code + Monkey C extension
- **Target device:** `fenix7pro` (454×454, MIP transflective LCD, round)
- **Min API Level:** 3.4.0 (covers fenix7pro; use SDK-verified level)
- **Entry point class:** `RedLineApp` (extends `Application.AppBase`)
- **View class:** `RedLineView` (extends `WatchUi.WatchFace`)

## Project File Structure

```
redline/
├── CLAUDE.md
├── monkey.jungle
├── manifest.xml
├── resources/
│   ├── fonts/              ← custom bitmap fonts go here
│   ├── images/
│   │   └── launcher_icon.png
│   ├── strings/
│   │   └── strings.xml
│   └── drawables/
│       └── drawables.xml
└── source/
    ├── RedLineApp.mc       ← AppBase entry point
    ├── RedLineView.mc      ← WatchFace view, all rendering logic
    └── RedLineDelegate.mc  ← WatchFaceDelegate for power budget
```

## Architecture Rules

### Rendering approach
- **Do NOT use XML layouts** (`setLayout`, `findDrawableById`). All drawing is done manually via `dc.*` calls in `onUpdate` and `onPartialUpdate`.
- Call `dc.setColor(fg, bg)` before every draw operation — do not assume color state persists.
- Always call `dc.clear()` at the top of `onUpdate` after setting the background color.
- Draw order matters: background → static elements → dynamic elements.

### Power / performance
- `onUpdate()` is called once per minute in low-power (sleep) mode and every second in high-power mode (wrist raise, ~10s window).
- `onPartialUpdate()` is called every second in low-power mode for the seconds field only. Use `dc.setClip()` to restrict the redraw region to the smallest bounding box around the seconds display — this is the **primary battery optimization**.
- Never allocate objects (arrays, strings via `Lang.format`) inside `onUpdate` or `onPartialUpdate` — pre-allocate in `onLayout` or class fields.
- Cache all layout coordinates (x, y positions) as class-level `var` fields computed once in `onLayout` from `dc.getWidth()` and `dc.getHeight()`. Never hard-code pixel values.
- Do not use timers in a watch face — rely on the system's `onUpdate`/`onPartialUpdate` cadence.

### Coordinate system
- Origin (0,0) = top-left corner.
- Screen center = `(dc.getWidth() / 2, dc.getHeight() / 2)` → for fenix7pro this is (227, 227).
- All positions must be computed relative to `width` and `height`, never hard-coded, so the face is portable to other round devices.

### Fonts
- System fonts available: `Graphics.FONT_TINY`, `FONT_SMALL`, `FONT_MEDIUM`, `FONT_LARGE`, `FONT_NUMBER_MILD`, `FONT_NUMBER_MEDIUM`, `FONT_NUMBER_HOT`, `FONT_NUMBER_THAI_HOT`.
- `FONT_NUMBER_HOT` and `FONT_NUMBER_THAI_HOT` are the closest built-in options to a 7-segment digital style — use these for the time display in v1.
- Custom bitmap fonts (`.fnt` + `.png` spritesheet) can be added under `resources/fonts/` and referenced via `Rez.Fonts.MyFont`. This is the path for a true DSEG7-style digit font in a future iteration.
- Font height can be measured with `dc.getFontHeight(font)` — use this for vertical layout math.

### Display — MIP (NOT AMOLED)

The fenix7pro uses a **MIP (Memory-in-Pixel) transflective LCD** — NOT AMOLED.

MIP key facts:
- Reflects ambient light — more light = more readable WITHOUT backlight
- Backlight illuminates from behind (like traditional LCD) for low-light use
- **64-color palette** — RGB values are rounded to nearest of 64 fixed colors
- Black vs white background: NO battery difference on MIP
- Low-light visibility = **contrast** issue, not luminance. Use high-contrast color pairs
- Best colors on black MIP: white, amber (`0xFFAA00`), orange (`0xFF5500`), green (`0x00FF00`), yellow (`0xFFFF00`)
- Avoid on black: dark red (`0xCC1111`), dark blue (`0x0000FF`), dark green (`0x006600`) — low contrast

### Color
- Primary color (text/symbols): `0xFF5500` (orange-red, default — high MIP contrast)
- Background BLACK: `0x000000`
- Background WHITE: `0xFFFFFF`
- Secondary/dim colors: preset per accent color, not derived mathematically
- In Monkey C: `dc.setColor(foreground, background)` — the background param in `drawText` fills behind the glyph; use `Graphics.COLOR_TRANSPARENT` for the bg arg when drawing text over already-drawn backgrounds.

### Data sources

| Field | API |
|---|---|
| Time (H, M, S) | `System.getClockTime()` → `.hour`, `.min`, `.sec` |
| Day of week | `Gregorian.info(Time.now(), Time.FORMAT_SHORT).day_of_week` (1=Sun) |
| Date (month, day) | `Gregorian.info(...)` → `.month`, `.day` |
| Heart rate | `Activity.getActivityInfo().currentHeartRate` |
| Step count | `ActivityMonitor.getInfo().steps` |
| Body battery | `SensorHistory.getBodyBatteryHistory({:period=>1})` → iterate `.next()` → `.data` (requires `SensorHistory` permission) |
| Device battery | `System.getSystemStats().battery` → returns 0.0–100.0 |
| Weather / temp | `Weather.getCurrentConditions().temperature` (requires `<iq:permission id="WeatherConditions"/>` in manifest) |

### Permissions required in manifest.xml
```xml
<iq:permissions>
  <iq:uses-permission id="SensorHistory"/>
</iq:permissions>
```
`ActivityMonitor`, `System`, and `Weather` do **not** require explicit permissions on fenix7pro. `SensorHistory` is required for body battery data.

### 12-hour time formatting
```monkeyc
var clockTime = System.getClockTime();
var hour = clockTime.hour;
var isPM = hour >= 12;
hour = hour % 12;
if (hour == 0) { hour = 12; }
var minStr = clockTime.min.format("%02d");
var hrStr  = hour.format("%02d");
```

### Drawing patterns

**Filled rectangle (divider line):**
```monkeyc
dc.setColor(0xCC1111, Graphics.COLOR_TRANSPARENT);
dc.fillRectangle(x, y, width, 1);
```

**Centered text:**
```monkeyc
dc.drawText(centerX, y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
```

**Left-aligned text:**
```monkeyc
dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
```

**Battery bar:**
```monkeyc
var batt = System.getSystemStats().battery;  // 0–100 float
var barW = 80;
var fillW = (batt / 100.0 * barW).toNumber();
dc.setColor(0x220000, Graphics.COLOR_TRANSPARENT);
dc.fillRectangle(barX, barY, barW, 3);  // track
dc.setColor(0xCC1111, Graphics.COLOR_TRANSPARENT);
dc.fillRectangle(barX, barY, fillW, 3); // fill
```

**SVG-style icons via polygons:**
Garmin has no SVG support. Draw icons using `dc.fillPolygon(pointArray)` for shapes, or `dc.drawLine` / `dc.fillCircle` for simpler icons.

Heart icon approximation:
```monkeyc
// Two overlapping circles + triangle — or use a bitmap
dc.fillCircle(cx - 4, cy - 2, 4);
dc.fillCircle(cx + 4, cy - 2, 4);
dc.fillPolygon([[cx - 8, cy], [cx + 8, cy], [cx, cy + 8]]);
```

Lightning bolt: `dc.fillPolygon` with 6-point path.
Thermometer: `dc.fillRectangle` for stem + `dc.fillCircle` for bulb.
Steps bars: three `dc.fillRectangle` calls of increasing height.

## Settings / App Properties

The watch face supports a `background` setting (black or white), stored via `Application.Storage`:
```monkeyc
var bgPref = Application.Storage.getValue("bg");  // "black" or "white"
```
Default is `"black"`. Read in `onUpdate`; write via a settings menu defined in `resources/settings/` (future iteration).

## Common Monkey C Pitfalls

- **Null safety:** `Activity.getActivityInfo()` can return null if no activity is active. Always null-check: `var info = Activity.getActivityInfo(); if (info != null) { ... }`.
- **Integer division:** `5 / 2` = `2` in Monkey C. Use `5.0 / 2` or cast: `(5.toFloat() / 2)` for float math.
- **String formatting:** Use `Lang.format("$1$:$2$", [a, b])` — not string interpolation.
- **No `+` for string concat on numbers:** Convert first: `a.toString() + ":" + b.toString()`.
- **`format("%02d")` on integers:** Pads with leading zero — essential for time display.
- **Color constants:** Use hex literals `0xRRGGBB` or `Graphics.COLOR_RED`, `Graphics.COLOR_BLACK`, etc.
- **`onPartialUpdate` clipping:** Must call `dc.setClip(x, y, w, h)` before drawing, then `dc.clearClip()` after.
- **Don't call `View.onUpdate(dc)` if not using layouts** — it will try to render a null layout and crash.

## Build & Test Workflow

```bash
# Simulate in VS Code
Ctrl+Shift+P → "Monkey C: Build for Simulator" → select fenix7pro

# Run simulator
Ctrl+F5 (or Run Without Debugging)

# Build for device
Ctrl+Shift+P → "Monkey C: Build for Device" → fenix7pro → outputs .prg

# Deploy to watch
# Connect Fenix 7 Pro via USB → copy .prg to GARMIN/Apps/
# On macOS: may need Android File Transfer

# View diagnostics in simulator
# Simulator menu → File → View Watchface Diagnostics
# Check onPartialUpdate execution time (target: under 30ms budget)
```

## Iteration Notes

- **v1 goal:** Get all data fields rendering correctly in simulator with correct layout. Font will be system `FONT_NUMBER_HOT` for time as a stand-in.
- **v2:** Swap in custom DSEG7-style bitmap font for the time digits once v1 is confirmed working.
- **v3:** Add white/black background setting, refine icon polygons, tune spacing on real device.

## Reference

- API Docs: https://developer.garmin.com/connect-iq/api-docs/
- Compatible devices: https://developer.garmin.com/connect-iq/compatible-devices/
- Monkey C language reference: https://developer.garmin.com/connect-iq/monkey-c/
- Analog sample (onPartialUpdate example): in SDK `/samples/Analog/`