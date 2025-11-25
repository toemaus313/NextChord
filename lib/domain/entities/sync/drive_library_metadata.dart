import 'package:googleapis/drive/v3.dart' as drive;

/// Model for Google Drive file metadata
class DriveLibraryMetadata {
  final String fileId;
  final String modifiedTime;
  final String md5Checksum;
  final String headRevisionId;

  DriveLibraryMetadata({
    required this.fileId,
    required this.modifiedTime,
    required this.md5Checksum,
    required this.headRevisionId,
  });

  /// Create from Google Drive File metadata
  factory DriveLibraryMetadata.fromDriveFile(drive.File file) {
    return DriveLibraryMetadata(
      fileId: file.id ?? '',
      modifiedTime: file.modifiedTime?.toString() ?? '',
      md5Checksum: file.md5Checksum ?? '',
      headRevisionId: file.headRevisionId ?? '',
    );
  }

  /// Check if remote metadata represents changes since last sync
  bool hasChanged(DriveLibraryMetadata? other) {
    if (other == null) return true;
    return fileId != other.fileId ||
        modifiedTime != other.modifiedTime ||
        md5Checksum != other.md5Checksum ||
        headRevisionId != other.headRevisionId;
  }

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'modifiedTime': modifiedTime,
        'md5Checksum': md5Checksum,
        'headRevisionId': headRevisionId,
      };

  factory DriveLibraryMetadata.fromJson(Map<String, dynamic> json) =>
      DriveLibraryMetadata(
        fileId: json['fileId'] ?? '',
        modifiedTime: json['modifiedTime'] ?? '',
        md5Checksum: json['md5Checksum'] ?? '',
        headRevisionId: json['headRevisionId'] ?? '',
      );
}
