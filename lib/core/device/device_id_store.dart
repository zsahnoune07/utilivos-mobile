abstract interface class DeviceIdStore {
  Future<String?> read();
  Future<void> write(String deviceId);
  Future<void> clear();
}
