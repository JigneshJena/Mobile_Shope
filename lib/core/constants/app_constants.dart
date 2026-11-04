/// Central constants for the Mobile Repair Shop Management App.
class AppConstants {
  static const String appName = 'SP Mobile Repair';
  static const String cloudinaryCloudName = 'dgywpx1xw';
  static const String cloudinaryUploadPreset = 'repair_shop_uploads';
  static const String cloudinaryBaseUrl = 'https://api.cloudinary.com/v1_1/dgywpx1xw/image/upload';
  static const int maxImages = 3;
}

class UserRole {
  static const String owner = 'owner';
  static const String employee = 'employee';
}

abstract class RepairStatus {
  static const String pending    = 'pending';
  static const String inProgress = 'in_progress';
  static const String repaired   = 'repaired';
  static const String delivered  = 'delivered';

  static const List<String> all = [pending, inProgress, repaired, delivered];

  static String label(String status) {
    switch (status) {
      case pending:    return 'Pending';
      case inProgress: return 'In Progress';
      case repaired:   return 'Repaired';
      case delivered:  return 'Delivered';
      default:         return 'Unknown';
    }
  }
}

abstract class InventoryCategory {
  static const String screen      = 'screen';
  static const String display     = 'display';
  static const String frame       = 'frame';
  static const String chargingPort= 'charging_port';
  static const String socket      = 'socket';
  static const String battery     = 'battery';
  static const String charger     = 'charger';
  static const String backPanel   = 'back_panel';
  static const String speaker     = 'speaker';
  static const String microphone  = 'microphone';
  static const String camera      = 'camera';
  static const String motherboard = 'motherboard';
  static const String other       = 'other';

  static const List<String> all = [
    display, frame, chargingPort, socket, battery,
    screen, charger, backPanel, speaker, microphone, camera, motherboard, other,
  ];

  static String label(String category) {
    switch (category) {
      case display:     return 'Display';
      case frame:       return 'Frame';
      case chargingPort:return 'Charging Port';
      case socket:      return 'Socket';
      case screen:      return 'Screen';
      case battery:     return 'Battery';
      case charger:     return 'Charger';
      case backPanel:   return 'Back Panel';
      case speaker:     return 'Speaker';
      case microphone:  return 'Microphone';
      case camera:      return 'Camera';
      case motherboard: return 'Motherboard';
      default:          return 'Other';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppSizes — standardized sizing constants used throughout the app.
// Change a value here to update all usages consistently.
// ─────────────────────────────────────────────────────────────────────────────
abstract class AppSizes {
  // Dashboard grid
  static const double dashboardIconSize   = 18.0;
  static const double dashboardCardHeight = 82.0; // mainAxisExtent for compact stat cards
  static const double gridCrossAxisSpacing = 10.0;
  static const double gridMainAxisSpacing  = 10.0;

  // General spacing
  static const double pageHorizontalPadding = 16.0;
  static const double cardBorderRadius      = 16.0;
  static const double buttonBorderRadius    = 12.0;

  // Bottom nav
  static const double bottomNavIconSize     = 24.0;
}
