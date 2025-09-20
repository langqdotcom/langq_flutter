import 'models.dart';

// lib/src/extraction/context_type.dart
enum ContextType {
  // UI Text
  uiText('UI Text'),
  appBarTitle('App Bar Title'),
  buttonText('Button Text'),
  tooltipText('Tooltip Text'),
  inputText('Input Text'),

  // Dialog & Messages
  dialogTitle('Dialog Title'),
  dialogContent('Dialog Content'),
  snackbarMessage('Snackbar Message'),
  errorMessage('Error Message'),

  // Navigation
  pageTitle('Page Title'),
  navigationLabel('Navigation Label'),

  // Generic
  stringLiteral('String Literal'),
  interpolatedString('Interpolated String'),

  // Special
  unknown('Unknown');

  const ContextType(this.displayName);

  final String displayName;

  /// Returns true if this context type is likely user-facing
  bool get isUserFacing {
    switch (this) {
      case ContextType.uiText:
      case ContextType.appBarTitle:
      case ContextType.buttonText:
      case ContextType.tooltipText:
      case ContextType.inputText:
      case ContextType.dialogTitle:
      case ContextType.dialogContent:
      case ContextType.snackbarMessage:
      case ContextType.pageTitle:
      case ContextType.navigationLabel:
      case ContextType.interpolatedString:
        return true;
      case ContextType.errorMessage:
      case ContextType.stringLiteral:
      case ContextType.unknown:
        return false;
    }
  }

  /// Returns the priority this context type should have by default
  Priority get defaultPriority {
    if (isUserFacing) {
      switch (this) {
        case ContextType.appBarTitle:
        case ContextType.dialogTitle:
        case ContextType.pageTitle:
          return Priority.high;
        case ContextType.buttonText:
        case ContextType.navigationLabel:
        case ContextType.interpolatedString:
          return Priority.high;
        default:
          return Priority.medium;
      }
    }
    return Priority.low;
  }
}
