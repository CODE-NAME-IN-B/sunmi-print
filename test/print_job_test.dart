import 'package:flutter_test/flutter_test.dart';
import 'package:sunmi_print_app/models/print_job.dart';

void main() {
  group('PrintJob', () {
    test('toJson and fromJson round-trip', () {
      final job = PrintJob(
        id: '123',
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        fileType: PrintFileType.pdf,
        copies: 2,
        status: PrintJobStatus.completed,
        createdAt: DateTime(2026, 7, 1),
        retryCount: 1,
        errorMessage: 'Out of paper',
        completedPages: 3,
        totalPages: 5,
      );

      final json = job.toJson();
      final restored = PrintJob.fromJson(json);

      expect(restored.id, job.id);
      expect(restored.filePath, job.filePath);
      expect(restored.fileName, job.fileName);
      expect(restored.fileType, job.fileType);
      expect(restored.copies, job.copies);
      expect(restored.status, job.status);
      expect(restored.createdAt, job.createdAt);
      expect(restored.retryCount, job.retryCount);
      expect(restored.errorMessage, job.errorMessage);
      expect(restored.completedPages, job.completedPages);
      expect(restored.totalPages, job.totalPages);
    });

    test('copyWith preserves unchanged fields', () {
      final job = PrintJob(
        id: '123',
        filePath: '/path/file.pdf',
        fileName: 'file.pdf',
        fileType: PrintFileType.pdf,
        copies: 1,
        status: PrintJobStatus.pending,
        createdAt: DateTime(2026, 7, 1),
      );

      final modified = job.copyWith(status: PrintJobStatus.printing);

      expect(modified.status, PrintJobStatus.printing);
      expect(modified.id, job.id);
      expect(modified.filePath, job.filePath);
      expect(modified.fileName, job.fileName);
      expect(modified.copies, job.copies);
    });
  });
}
