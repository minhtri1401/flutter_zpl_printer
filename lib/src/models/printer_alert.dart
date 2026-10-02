/// Alert conditions that can trigger notifications.
///
/// Mirrors SDK's `AlertCondition.java`.
enum AlertCondition {
  headOpen,
  paperOut,
  ribbonOut,
  batteryLow,
  coldWeatherMode,
  allErrors,
  allWarnings;

  /// SGD string representation for this condition.
  String get sgdValue {
    switch (this) {
      case AlertCondition.headOpen:
        return 'HEAD_OPEN';
      case AlertCondition.paperOut:
        return 'PAPER_OUT';
      case AlertCondition.ribbonOut:
        return 'RIBBON_OUT';
      case AlertCondition.batteryLow:
        return 'BATTERY_LOW';
      case AlertCondition.coldWeatherMode:
        return 'COLD_WEATHER';
      case AlertCondition.allErrors:
        return 'ALL_ERRORS';
      case AlertCondition.allWarnings:
        return 'ALL_WARNINGS';
    }
  }

  /// Parse from SGD string.
  static AlertCondition? fromSgd(String value) {
    for (final condition in values) {
      if (condition.sgdValue == value.trim().toUpperCase()) return condition;
    }
    return null;
  }
}

/// Alert delivery destinations.
enum AlertDestination {
  tcp,
  email,
  snmp,
  serial;

  String get sgdValue => name.toUpperCase();
}

/// A configured printer alert.
///
/// Mirrors SDK's `PrinterAlert.java`.
class PrinterAlert {
  final AlertCondition condition;
  final AlertDestination destination;
  final bool onSet;
  final bool onClear;
  final String destinationAddress;
  final int port;

  const PrinterAlert({
    required this.condition,
    required this.destination,
    this.onSet = true,
    this.onClear = false,
    required this.destinationAddress,
    this.port = 0,
  });

  /// Convert to SGD-compatible configuration string.
  String toSgdConfig() {
    final setFlag = onSet ? 'YES' : 'NO';
    final clearFlag = onClear ? 'YES' : 'NO';
    return '${condition.sgdValue},${destination.sgdValue},'
        '$setFlag,$clearFlag,$destinationAddress,$port';
  }

  @override
  String toString() =>
      'PrinterAlert(${condition.sgdValue} -> ${destination.sgdValue}:'
      '$destinationAddress:$port)';
}
