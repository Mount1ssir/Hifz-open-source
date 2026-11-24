import '../domain/review_scheduler.dart';

String normalizeDigits(String value) {
  for (var i = 0; i < 10; i++) {
    value = value
        .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i')
        .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
  }
  return value.replaceAll('٫', '.').replaceAll('،', ',');
}

String recallLabel(RecallRating rating) => switch (rating) {
  RecallRating.again => 'أعد المحاولة',
  RecallRating.hard => 'صعب',
  RecallRating.good => 'جيد',
  RecallRating.easy => 'سهل',
};
