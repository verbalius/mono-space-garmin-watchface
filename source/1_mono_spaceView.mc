import Toybox.Graphics;
import Toybox.Activity;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.Weather;

class _1_mono_spaceView extends WatchUi.WatchFace {

    var _isSleeping = false;
    var _highPowerRefreshTimer as Timer.Timer or Null = null;
    var _timeLabel as Text or Null = null;
    var _secondsLabel as Text or Null = null;
    var _batteryLabel as Text or Null = null;
    var _dateLabel as Text or Null = null;
    var _heartRateLabel as Text or Null = null;
    var _weatherTempLabel as Text or Null = null;
    var _sunTimesLabel as Text or Null = null;
    var _sunSymbol as WatchUi.Bitmap or Null = null;
    var _lastHeartRate = null;
    var _lastHeartRateMoment as Time.Moment or Null = null;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));

        _timeLabel = View.findDrawableById("TimeLabel") as Text;
        _secondsLabel = View.findDrawableById("SecondsLabel") as Text;
        _batteryLabel = View.findDrawableById("BatteryLabel") as Text;
        _dateLabel = View.findDrawableById("DateLabel") as Text;
        _heartRateLabel = View.findDrawableById("HeartRateLabel") as Text;
        _weatherTempLabel = View.findDrawableById("WeatherTempLabel") as Text;
        _sunTimesLabel = View.findDrawableById("SunTimesLabel") as Text;
        _sunSymbol = View.findDrawableById("SunSymbol") as WatchUi.Bitmap;
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        if (!_isSleeping) {
            startHighPowerRefresh();
        }
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;
        var arcLength = 60;
        var arcWidth = 10;
        var arcRadius = height / 2 - arcWidth / 2;

        // Get and show the current time
        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%02d")]);

        (_timeLabel as Text).setText(timeString);
        if (_isSleeping) {
            (_secondsLabel as Text).setText("--");
        } else {
            (_secondsLabel as Text).setText(clockTime.sec.format("%02d"));
        }

        // Battery
        var battery = getBattery();
        (_batteryLabel as Text).setText(battery.format("%d") + "%");
        (_batteryLabel as Text).setColor(getBatteryColorForLevel(battery));

        // Date
        (_dateLabel as Text).setText(getDate());

        // Heart rate
        (_heartRateLabel as Text).setText(getHeartRateString());

        // Weather temperature
        (_weatherTempLabel as Text).setText(getWeatherTemperatureString());

        // Sunrise / Sunset
        (_sunTimesLabel as Text).setText(getSunTimesString());

        if (isGoldenHour()) {
            (_sunSymbol as WatchUi.Bitmap).setBitmap(Rez.Drawables.SunIconGolden);
        } else {
            (_sunSymbol as WatchUi.Bitmap).setBitmap(Rez.Drawables.SunIcon);
        }

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);

        // Draw Body Battery and Steps arcs
        dc.setPenWidth(arcWidth);

        var bodyBattery = getBodyBattery();
        var activityInfo = Toybox.ActivityMonitor.getInfo();
        var steps = activityInfo.steps;
        var stepGoal = activityInfo.stepGoal;
        var stepsRatio = getStepsRatioThresholded(steps, stepGoal);

        // Draw Body Battery Arc
        dc.setColor(Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, arcRadius, Graphics.ARC_CLOCKWISE, 180 + arcLength / 2, 180 - arcLength / 2);

        if (bodyBattery != null) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(centerX, centerY, arcRadius, Graphics.ARC_CLOCKWISE, 180 + arcLength / 2, 180 + arcLength / 2 - arcLength * bodyBattery / 100);
        }

        // Draw Steps Arc
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, arcRadius, Graphics.ARC_COUNTER_CLOCKWISE, 0 - arcLength / 2, 0 + arcLength / 2);

        if (steps != null && steps > 0 && stepGoal != null && stepsRatio != null) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(centerX, centerY, arcRadius, Graphics.ARC_COUNTER_CLOCKWISE, 0 - arcLength / 2, 0 - arcLength / 2 + arcLength * stepsRatio);
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
        stopHighPowerRefresh();
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        _isSleeping = false;
        startHighPowerRefresh();
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        _isSleeping = true;
        stopHighPowerRefresh();
    }

    function startHighPowerRefresh() as Void {
        if (_highPowerRefreshTimer == null) {
            _highPowerRefreshTimer = new Timer.Timer();
        }

        _highPowerRefreshTimer.start(method(:onHighPowerRefreshTick), 1000, true);
    }

    function stopHighPowerRefresh() as Void {
        if (_highPowerRefreshTimer != null) {
            _highPowerRefreshTimer.stop();
        }
    }

    function onHighPowerRefreshTick() as Void {
        if (!_isSleeping) {
            WatchUi.requestUpdate();
        }
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
        var liveHeartRate = getLiveHeartRate();
        if (liveHeartRate != null) {
            _lastHeartRate = liveHeartRate;
            _lastHeartRateMoment = Time.now();
            return liveHeartRate;
        }

        var recentWindow = new Time.Duration(12);
        var heartrateIterator = Toybox.ActivityMonitor.getHeartRateHistory(recentWindow, true);
        var sample = heartrateIterator.next();

        while (sample != null) {
            var heartRate = sample.heartRate;
            if (isValidHeartRate(heartRate)) {
                if (isRecentHeartRateSample(sample, 8)) {
                    _lastHeartRate = heartRate;
                    _lastHeartRateMoment = Time.now();
                    return heartRate;
                }
            }

            sample = heartrateIterator.next();
        }

        if (_lastHeartRate != null && _lastHeartRateMoment != null) {
            var cacheAge = Time.now().subtract(_lastHeartRateMoment).value();
            if (cacheAge <= 12) {
                return _lastHeartRate;
            }
        }

        return null;
    }

    function getLiveHeartRate() as Number or Null {
        if (!(Toybox has :Activity) || !(Activity has :getActivityInfo)) {
            return null;
        }

        var activityInfo = Activity.getActivityInfo();
        if (activityInfo == null || !(activityInfo has :currentHeartRate)) {
            return null;
        }

        var heartRate = activityInfo.currentHeartRate;
        if (isValidHeartRate(heartRate)) {
            return heartRate;
        }

        return null;
    }

    function isValidHeartRate(heartRate as Number or Null) as Boolean {
        return heartRate != null && heartRate > 0 && heartRate != 255 &&
            (!(Toybox.ActivityMonitor has :INVALID_HR_SAMPLE) || heartRate != Toybox.ActivityMonitor.INVALID_HR_SAMPLE);
    }

    function isRecentHeartRateSample(sample, maxAgeSeconds as Number) as Boolean {
        if (sample == null || sample.when == null) {
            return false;
        }

        var age = Time.now().subtract(sample.when).value();
        return age <= maxAgeSeconds;
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

    function getStepsRatioThresholded(steps as Number or Null, stepGoal as Number or Null) as Float or Null {

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

    function getBatteryColorForLevel(battery as Float) as Number {

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

}
