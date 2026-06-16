import 'package:flutter/services.dart';
import '../debug/debug_config.dart';

class ScreenProtector {
  ScreenProtector._();

  static const _channel = MethodChannel('near_me/screen_protector');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
      DebugConfig.log(DebugConfig.serviceCall, 'ScreenProtector: enabled');
    } catch (e) {
      DebugConfig.warn('ScreenProtector: enable failed', data: e);
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
      DebugConfig.log(DebugConfig.serviceCall, 'ScreenProtector: disabled');
    } catch (e) {
      DebugConfig.warn('ScreenProtector: disable failed', data: e);
    }
  }
}
