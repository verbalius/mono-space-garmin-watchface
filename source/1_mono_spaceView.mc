import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

class _1_mono_spaceView extends WatchUi.WatchFace {

    var _isSleeping = false;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {}

    // Update the view
    function onUpdate(dc as Dc) as Void {
        var WIDTH = dc.getWidth();
        var HEIGHT = dc.getHeight();

        // Get and show the current time
        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%02d")]);
        var timeLabel = View.findDrawableById("TimeLabel") as Text;
        timeLabel.setText(timeString);
        var secondsLabel = View.findDrawableById("SecondsLabel") as Text;
        if (_isSleeping) {
            secondsLabel.setText("--");
        } else {
            secondsLabel.setText(clockTime.sec.format("%02d"));
        }

        // Battery
        var batteryLabel = View.findDrawableById("BatteryLabel") as Text;
        batteryLabel.setText(getBatteryString());
        batteryLabel.setColor(getBatteryColor());

        // Date
        var dateLabel = View.findDrawableById("DateLabel") as Text;
        dateLabel.setText(getDate());

        // Heart rate
        var heartRateLabel = View.findDrawableById("HeartRateLabel") as Text;
        heartRateLabel.setText(getHeartRateString());

        // Weather temperature
        var weatherTempLabel = View.findDrawableById("WeatherTempLabel") as Text;
        weatherTempLabel.setText(getWeatherTemperatureString());

        // Sunrise / Sunset
        var sunTimesLabel = View.findDrawableById("SunTimesLabel") as Text;
        sunTimesLabel.setText(getSunTimesString());

        var sunSymbol = View.findDrawableById("SunSymbol") as WatchUi.Bitmap;
        if (isGoldenHour()) {
            sunSymbol.setBitmap(Rez.Drawables.SunIconGolden);
        } else {
            sunSymbol.setBitmap(Rez.Drawables.SunIcon);
        }

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);

        // Draw Body Battery and Steps arcs
        var ARCLENGTH = 60;
        var ARCWIDTH = 10;
        dc.setPenWidth(ARCWIDTH);

        // Draw Body Battery Arc
        dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(WIDTH / 2, HEIGHT / 2, HEIGHT / 2 - ARCWIDTH / 2, Graphics.ARC_CLOCKWISE, 180 + ARCLENGTH / 2, 180 - ARCLENGTH / 2);

        if (getBodyBattery() != null) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(WIDTH / 2, HEIGHT / 2, HEIGHT / 2 - ARCWIDTH / 2, Graphics.ARC_CLOCKWISE, 180 + ARCLENGTH / 2, 180 + ARCLENGTH / 2 - ARCLENGTH * getBodyBattery() / 100);
        }

        // Draw Steps Arc
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(WIDTH / 2, HEIGHT / 2, HEIGHT / 2 - ARCWIDTH / 2, Graphics.ARC_COUNTER_CLOCKWISE, 0 - ARCLENGTH / 2, 0 + ARCLENGTH / 2);

        if (getSteps() != null && getSteps() > 0 && getStepGoal() != null) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(WIDTH / 2, HEIGHT / 2, HEIGHT / 2 - ARCWIDTH / 2, Graphics.ARC_COUNTER_CLOCKWISE, 0 - ARCLENGTH / 2, 0 - ARCLENGTH / 2 + ARCLENGTH * getStepsRatioThresholded());
        }

        // drawReferenceLines(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {}

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        _isSleeping = false;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        _isSleeping = true;
    }

    function getDate() as String {
       var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
       var weekday = now.day_of_week;
       if (weekday.length() > 3) {
           weekday = weekday.substring(0, 3);
       }

       var dateString = Lang.format("$1$ $2$", [weekday, now.day]);
        return dateString;
    }

    function getWeatherTemperatureString() as String {
        if (!(Toybox has :Weather) || !(Weather has :getCurrentConditions)) {
            return "--";
        }

        var conditions = Weather.getCurrentConditions();
        if (conditions == null || conditions.temperature == null) {
            return "--";
        }

        return conditions.temperature.format("%d") + "℃";
    }

    function getHeartRate() as Number or Null {
        var heartrateIterator = Toybox.ActivityMonitor.getHeartRateHistory(5, true);
        var sample = heartrateIterator.next();

        while (sample != null) {
            var heartRate = sample.heartRate;
            if (heartRate != null && heartRate > 0 && heartRate != 255 &&
                (!(Toybox.ActivityMonitor has :INVALID_HR_SAMPLE) || heartRate != Toybox.ActivityMonitor.INVALID_HR_SAMPLE)) {
                return heartRate;
            }
            sample = heartrateIterator.next();
        }

        return null;
    }

    function getHeartRateString() as String {
        var heartRate = getHeartRate();
        if (heartRate == null) {
            return "-";
        }
        return heartRate.format("%d");
    }

    function getBodyBatteryIterator() {
        if ((Toybox has: SensorHistory) && (Toybox.SensorHistory has: getBodyBatteryHistory)) {
            return Toybox.SensorHistory.getBodyBatteryHistory({: period => 1,
                : order => Toybox.SensorHistory.ORDER_NEWEST_FIRST
            });
        }
        return null;
    }

    function getBodyBattery() as Number or Null {
        var bbIterator = getBodyBatteryIterator();
        var sample = bbIterator.next();

        while (sample != null) {
            if (sample.data != null) {
                return sample.data;
            }
            sample = bbIterator.next();
        }

        return null;
    }

    function getBodyBatteryString() as String {
        var bodyBattery = getBodyBattery();
        if (bodyBattery == null) {
            return "-";
        }
        return bodyBattery.format("%d") + "%";
    }

    function getSteps() as Number or Null {
        return Toybox.ActivityMonitor.getInfo().steps;
    }

    function getStepsString() as String {
        var steps = getSteps();
        if (steps == null) {
            return "-";
        }
        return getSteps().format("%d");
    }

    function getStepGoal() as Number or Null {
        return Toybox.ActivityMonitor.getInfo().stepGoal;
    }

    function getStepsRatioThresholded() as Float or Null {
        var stepGoal = getStepGoal();
        var steps = getSteps();

        if (steps == null || stepGoal == null) {
            return null;
        }

        if (steps > stepGoal) {
            steps = stepGoal;
        }

        return 1.0 * steps / stepGoal;
    }

    function getBattery() as Float {
        return Toybox.System.getSystemStats().battery;
    }

    function getBatteryString() as String {
        return getBattery().format("%d") + "%";
    }

    function getBatteryColor() as Number {
        var battery = getBattery();

        if (battery >= 80) {
            return Graphics.COLOR_GREEN;
        }

        if (battery >= 30) {
            return Graphics.COLOR_WHITE;
        }

        if (battery >= 15) {
            return Graphics.COLOR_YELLOW;
        }

        return Graphics.COLOR_RED;
    }

    function getSunTimesString() as String {
        if (!(Toybox has :Weather) || !(Weather has :getCurrentConditions) || !(Weather has :getSunrise) || !(Weather has :getSunset)) {
            return "--:--";
        }

        var conditions = Weather.getCurrentConditions();
        if (conditions == null || conditions.observationLocationPosition == null) {
            return "--:--";
        }

        var now = Time.now();
        var today = now;
        var sunrise = Weather.getSunrise(conditions.observationLocationPosition, today);
        var sunset = Weather.getSunset(conditions.observationLocationPosition, today);

        if (sunrise == null || sunset == null) {
            return "--:--";
        }

        var nowMinutes = getMinutesSinceMidnight(now);
        var sunriseMinutes = getMinutesSinceMidnight(sunrise);
        var sunsetMinutes = getMinutesSinceMidnight(sunset);

        if (nowMinutes < sunriseMinutes) {
            return formatMomentToTime(sunrise);
        }

        if (nowMinutes < sunsetMinutes) {
            return formatMomentToTime(sunset);
        }

        var tomorrow = today.add(new Time.Duration(24 * 60 * 60));
        var tomorrowSunrise = Weather.getSunrise(conditions.observationLocationPosition, tomorrow);
        if (tomorrowSunrise == null) {
            return "--:--";
        }

        return formatMomentToTime(tomorrowSunrise);
    }

    function formatMomentToTime(moment as Time.Moment) as String {
        var timeInfo = Gregorian.info(moment, Time.FORMAT_MEDIUM);
        return Lang.format("$1$:$2$", [timeInfo.hour, timeInfo.min.format("%02d")]);
    }

    function getMinutesSinceMidnight(moment as Time.Moment) as Number {
        var timeInfo = Gregorian.info(moment, Time.FORMAT_MEDIUM);
        return timeInfo.hour * 60 + timeInfo.min;
    }

    function isGoldenHour() as Boolean {
        if (!(Toybox has :Weather) || !(Weather has :getCurrentConditions) || !(Weather has :getSunrise) || !(Weather has :getSunset)) {
            return false;
        }

        var conditions = Weather.getCurrentConditions();
        if (conditions == null || conditions.observationLocationPosition == null) {
            return false;
        }

        var now = Time.now();
        var sunrise = Weather.getSunrise(conditions.observationLocationPosition, now);
        var sunset = Weather.getSunset(conditions.observationLocationPosition, now);
        if (sunrise == null || sunset == null) {
            return false;
        }

        var nowMinutes = getMinutesSinceMidnight(now);
        var sunriseMinutes = getMinutesSinceMidnight(sunrise);
        var sunsetMinutes = getMinutesSinceMidnight(sunset);
        var goldenWindow = 60;

        var isMorningGolden = (nowMinutes >= sunriseMinutes) && (nowMinutes <= sunriseMinutes + goldenWindow);
        var isEveningGolden = (nowMinutes >= sunsetMinutes - goldenWindow) && (nowMinutes <= sunsetMinutes);

        return isMorningGolden || isEveningGolden;
    }

    function drawReferenceLines(dc as Dc) as Void {
        var WIDTH = dc.getWidth();
        var HEIGHT = dc.getHeight();

        dc.setPenWidth(1);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(0.2 * WIDTH, 0.1 * HEIGHT, 0.6 * WIDTH, 0.8 * HEIGHT);
        dc.drawRectangle(0.15 * WIDTH, 0.15 * HEIGHT, 0.7 * WIDTH, 0.7 * HEIGHT);
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(0.1 * WIDTH, 0.2 * HEIGHT, 0.8 * WIDTH, 0.6 * HEIGHT);
        dc.drawRectangle(0.05 * WIDTH, 0.3 * HEIGHT, 0.9 * WIDTH, 0.4 * HEIGHT);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0.25 * HEIGHT, WIDTH, 1);
        dc.fillRectangle(0, 0.5 * HEIGHT, WIDTH, 1);
        dc.fillRectangle(0, 0.75 * HEIGHT, WIDTH, 1);
        dc.fillRectangle(0.25 * WIDTH, 0, 1, HEIGHT);

        dc.fillRectangle(0.1 * WIDTH, 0, 1, HEIGHT);
        dc.fillRectangle(0.9 * WIDTH, 0, 1, HEIGHT);

        dc.fillRectangle(0.5 * WIDTH, 0, 1, HEIGHT);
        dc.fillRectangle(0.75 * WIDTH, 0, 1, HEIGHT);

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0.3333 * WIDTH, 0, 1, HEIGHT);
        dc.fillRectangle(0.6666 * WIDTH, 0, 1, HEIGHT);
    }
}
