import 'models/downloaded_tool_bundle.dart';

abstract interface class DownloadedToolBundleStore {
  Future<List<DownloadedToolBundle>> read();
  Future<void> write(List<DownloadedToolBundle> bundles);
  Future<void> clear();
}
