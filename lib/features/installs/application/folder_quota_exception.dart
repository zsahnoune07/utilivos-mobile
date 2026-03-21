/// Thrown when a free user tries to create more folders than allowed.
class FolderQuotaExceededException implements Exception {
  const FolderQuotaExceededException();

  @override
  String toString() => 'FolderQuotaExceededException';
}
