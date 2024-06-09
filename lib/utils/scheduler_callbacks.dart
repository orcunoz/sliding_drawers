import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

mixin AfterLayout<W extends StatefulWidget> on State<W> {
  @mustCallSuper
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) afterLayout();
    });
  }

  void afterLayout() {}
}

class LnSchedulerCallbacks {
  LnSchedulerCallbacks._();

  static FutureOr<void> endOfFrame([VoidCallback? callback]) async {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await SchedulerBinding.instance.endOfFrame;
    }
    if (callback != null) {
      callback();
    }
  }
}
