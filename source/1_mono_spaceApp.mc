import Toybox.Application;
import Toybox.WatchUi;

class _1_mono_spaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new _1_mono_spaceView() ];
    }

}

function getApp() as _1_mono_spaceApp {
    return Application.getApp() as _1_mono_spaceApp;
}
