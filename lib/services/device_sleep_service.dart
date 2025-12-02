import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service responsible for managing device sleep behavior (screen on/off)
/// independently of UI widgets.
///
/// When [isDeviceSleepDisabled] is true and the app is in the foreground
/// (resumed), this service will keep the device screen awake using wakelock.
/// When the app is backgrounded or the flag is false, wakelock is released.
class DeviceSleepService extends ChangeNotifier with WidgetsBindingObserver {
  bool _isDeviceSleepDisabled = false;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;

  DeviceSleepService() {
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isDeviceSleepDisabled => _isDeviceSleepDisabled;

  /// Attach to an appearance/settings provider so this service stays in sync
  /// with the persisted user preference.
  void attachToAppearanceProvider(
      Listenable appearanceProvider, bool Function() getDisableDeviceSleep) {
    // Initial sync from provider
    _setDeviceSleepDisabledInternal(getDisableDeviceSleep());

    appearanceProvider.addListener(() {
      _setDeviceSleepDisabledInternal(getDisableDeviceSleep());
    });
  }

  /// Explicitly set the user preference flag.
  Future<void> setDeviceSleepDisabled(bool disabled) async {
    _setDeviceSleepDisabledInternal(disabled);
  }

  void _setDeviceSleepDisabledInternal(bool disabled) {
    if (_isDeviceSleepDisabled == disabled) {
      return;
    }
    _isDeviceSleepDisabled = disabled;
    _applyWakelock();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    _applyWakelock();
  }

  void _applyWakelock() {
    final shouldKeepAwake = _isDeviceSleepDisabled &&
        _lastLifecycleState == AppLifecycleState.resumed;

    if (shouldKeepAwake) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Ensure wakelock is released when service is disposed.
    WakelockPlus.disable();
    super.dispose();
  }
}
