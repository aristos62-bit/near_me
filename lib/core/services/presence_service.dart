import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../debug/debug_config.dart';

class PresenceService {
  static Timer? _timer;
  static DocumentReference? _ref;
  static DocumentReference? _publicRef;
  static bool _isShuttingDown = false;
  static bool _offlineInProgress = false;
  static bool _startLogged = false;

  static void init() {
    DebugConfig.log(DebugConfig.serviceInit, 'PresenceService.init');
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _start(user.uid);
      } else {
        _stop();
      }
    });
  }

  static Future<void> _start(String uid) async {
    _isShuttingDown = false;
    _offlineInProgress = false;
    _ref = FirebaseFirestore.instance.doc('users/$uid/status/status');
    _publicRef = FirebaseFirestore.instance.doc('users/$uid/public/profile');
    await _touch();
    if (_publicRef != null) {
      await _publicRef!.set({'isOnline': true}, SetOptions(merge: true));
    }
    if (!_startLogged) {
      DebugConfig.log(DebugConfig.presence,
          'PresenceService started: uid=$uid, publicRef set online');
      _startLogged = true;
    }
    _schedule();
  }

  static void handleLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      DebugConfig.log(DebugConfig.presence, 'Presence lifecycle: $state');
      setOffline();
    } else if (state == AppLifecycleState.resumed) {
      if (_isShuttingDown) {
        DebugConfig.log(DebugConfig.presence,
            'Presence lifecycle: resumed (shutdown in progress)');
        return;
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        DebugConfig.log(DebugConfig.presence, 'Presence lifecycle: resumed');
        _start(uid);
      } else {
        DebugConfig.log(DebugConfig.presence,
            'Presence lifecycle: resumed (no user)');
      }
    }
  }

  static Future<void> _touch() async {
    if (_ref == null) return;
    try {
      await _ref!.set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      DebugConfig.log(DebugConfig.presence, 'Presence touch: heartbeat');
    } catch (e) {
      DebugConfig.warn('PresenceService touch failed', data: e);
    }
  }

  static void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _touch());
  }

  static Future<void> setOffline() async {
    if (_offlineInProgress) {
      DebugConfig.log(DebugConfig.presence,
          'Presence setOffline: skipped (already in progress)');
      return;
    }
    _offlineInProgress = true;
    _timer?.cancel();
    if (_ref == null) {
      _offlineInProgress = false;
      return;
    }
    try {
      await Future.wait<void>([
        _ref!.set({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        }),
        if (_publicRef != null)
          _publicRef!.set({'isOnline': false}, SetOptions(merge: true)),
      ]);
      DebugConfig.log(DebugConfig.presence, 'Presence setOffline');
    } catch (e) {
      DebugConfig.warn('PresenceService setOffline failed', data: e);
    } finally {
      _offlineInProgress = false;
    }
  }

  static void reset() {
    _isShuttingDown = true;
    _timer?.cancel();
    _offlineInProgress = false;
    _startLogged = false;
    _ref = null;
    _publicRef = null;
    DebugConfig.log(DebugConfig.serviceInit, 'PresenceService reset');
  }

  static void _stop() {
    reset();
    DebugConfig.log(DebugConfig.serviceInit, 'PresenceService stopped');
  }
}
