import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/debug/debug_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/responsive_utils.dart';
import '../../core/utils/app_messenger.dart';
import '../../features/profile/providers/location_service.dart';

enum _GpsStrength {
  unknown,
  noSignal,
  weak,
  fair,
  good,
  excellent,
}

class GpsStrengthIndicator extends StatefulWidget {
  const GpsStrengthIndicator({super.key});

  @override
  State<GpsStrengthIndicator> createState() => _GpsStrengthIndicatorState();
}

class _GpsStrengthIndicatorState extends State<GpsStrengthIndicator>
    with WidgetsBindingObserver {
  _GpsStrength _strength = _GpsStrength.unknown;
  double? _accuracyMeters;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchInitial();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPoll();
      _refresh();
    } else if (state == AppLifecycleState.paused) {
      _stopPoll();
    }
  }

  void _startPoll() {
    _pollTimer ??= Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  void _stopPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchInitial() async {
    final cached = LocationService.lastAccuracy;
    if (cached != null) {
      _applyAccuracy(cached);
    }
    _startPoll();
    // Αν δεν υπάρχει cached accuracy, κάνε ένα early refresh μετά από 6s
    // για να προλάβει να ολοκληρωθεί το GPS από DiscoveryScreen (αν τρέχει).
    if (cached == null) {
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) _refresh();
      });
    }
  }

  Future<void> _refresh() async {
    try {
      await LocationService.getCurrentLocation(forceRefresh: false);
      if (!mounted) return;
      final acc = LocationService.lastAccuracy;
      if (acc != null) {
        _applyAccuracy(acc);
      }
    } catch (e) {
      DebugConfig.log(DebugConfig.gpsLocation,
          'GpsStrength: poll error → $e (keeping last value)');
    }
  }

  void _applyAccuracy(double acc) {
    _accuracyMeters = acc;
    if (acc <= 10) {
      _strength = _GpsStrength.excellent;
    } else if (acc <= 50) {
      _strength = _GpsStrength.good;
    } else if (acc <= 100) {
      _strength = _GpsStrength.fair;
    } else if (acc <= 500) {
      _strength = _GpsStrength.weak;
    } else {
      _strength = _GpsStrength.noSignal;
    }
    DebugConfig.log(DebugConfig.gpsLocation,
        'GpsStrength: ${acc}m → ${_strength.name}');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (_strength) {
      _GpsStrength.excellent => Colors.green,
      _GpsStrength.good => Colors.blue,
      _GpsStrength.fair => Colors.amber,
      _GpsStrength.weak => Colors.deepOrange,
      _GpsStrength.noSignal => Colors.red,
      _GpsStrength.unknown => Colors.grey,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = ResponsiveUtils.resolveWidth(context, constraints);
        return Padding(
          padding: ResponsiveUtils.horizontalPaddingFromWidth(w),
          child: GestureDetector(
            onTap: _showInfo,
            child: Icon(
              _strength == _GpsStrength.noSignal
                  ? Icons.location_off
                  : Icons.location_on,
              color: color,
              size: 24,
            ),
          ),
        );
      },
    );
  }

  void _showInfo() {
    final isGreek = L10n.isGreek(context);
    final msg = _accuracyMeters != null
        ? '${isGreek ? "Ακρίβεια GPS" : "GPS accuracy"}: ${_accuracyMeters!.toStringAsFixed(0)}m'
        : (isGreek ? 'GPS: Χωρίς σήμα' : 'GPS: No signal');
    AppMessenger.showInfo(context, msg);
  }
}
