import 'package:cloud_firestore/cloud_firestore.dart';

class TrialState {
  final bool hasUsedTrial;
  final String? courseId;
  final DateTime? expiresAt;

  const TrialState({
    this.hasUsedTrial = false,
    this.courseId,
    this.expiresAt,
  });

  factory TrialState.fromData(Map<String, dynamic> data) {
    final expiry = data['trialExpiry'];
    return TrialState(
      hasUsedTrial: data['hasUsedTrial'] == true ||
          data['trialStartedAt'] != null ||
          expiry != null,
      courseId: data['trialCourseId'] is String ? data['trialCourseId'] : null,
      expiresAt: expiry is Timestamp ? expiry.toDate() : null,
    );
  }

  bool get isActive =>
      courseId != null &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now());

  bool grantsAccess(String id) => courseId == id && isActive;
}

class TrialFailure implements Exception {
  final String message;
  const TrialFailure(this.message);
  @override
  String toString() => message;
}
