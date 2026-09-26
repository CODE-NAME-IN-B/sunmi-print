enum PrintJobStatus {
  pending,
  printing,
  completed,
  failed,
  cancelled,
}

enum PrintFileType {
  image,
  pdf,
  text,
}

const _sentinel = Object();

class PrintJob {
  final String id;
  final String filePath;
  final String fileName;
  final PrintFileType fileType;
  final int copies;
  final PrintJobStatus status;
  final DateTime createdAt;
  final int retryCount;
  final String? errorMessage;
  final int completedPages;
  final int totalPages;

  const PrintJob({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    this.copies = 1,
    this.status = PrintJobStatus.pending,
    required this.createdAt,
    this.retryCount = 0,
    this.errorMessage,
    this.completedPages = 0,
    this.totalPages = 1,
  });

  PrintJob copyWith({
    String? id,
    String? filePath,
    String? fileName,
    PrintFileType? fileType,
    int? copies,
    PrintJobStatus? status,
    DateTime? createdAt,
    int? retryCount,
    Object? errorMessage = _sentinel,
    int? completedPages,
    int? totalPages,
  }) {
    return PrintJob(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      copies: copies ?? this.copies,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage == _sentinel ? null : (errorMessage as String?),
      completedPages: completedPages ?? this.completedPages,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'fileName': fileName,
        'fileType': fileType.name,
        'copies': copies,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'errorMessage': errorMessage,
        'completedPages': completedPages,
        'totalPages': totalPages,
      };

  factory PrintJob.fromJson(Map<String, dynamic> json) => PrintJob(
        id: json['id'] as String,
        filePath: json['filePath'] as String,
        fileName: json['fileName'] as String,
        fileType: PrintFileType.values.firstWhere(
          (e) => e.name == json['fileType'],
          orElse: () => PrintFileType.image,
        ),
        copies: json['copies'] as int? ?? 1,
        status: PrintJobStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => PrintJobStatus.pending,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
        errorMessage: json['errorMessage'] as String?,
        completedPages: json['completedPages'] as int? ?? 0,
        totalPages: json['totalPages'] as int? ?? 1,
      );
}
