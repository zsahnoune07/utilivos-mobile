/// Maps host bridge `action` ids to user-facing paywall context (English fallback).
String paywallContextForGateAction(String action) {
  switch (action.trim().toLowerCase()) {
    case 'export':
      return 'Exports are unlimited on Pro—including this file.';
    case 'save':
    case 'save_file':
      return 'Saving files to device is a Pro feature.';
    case 'download':
    case 'download_output':
      return 'Downloads and output files are unlimited on Pro.';
    case 'convert':
    case 'convert_file':
      return 'Full conversions are included with Pro.';
    case 'advanced_mode':
    case 'advanced':
      return 'Advanced modes are part of Pro.';
    case 'storage':
      return 'You have reached the free limit for file actions today. Pro is unlimited.';
    default:
      return 'This action is included with Pro.';
  }
}

String analyticsIdForGateAction(String action) {
  final a = action.trim().toLowerCase();
  return a.isEmpty ? 'unknown_gate' : 'gate_$a';
}
