import 'dart:math';

String careerRequestId() {
  final b = List.generate(16, (_) => Random.secure().nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

Uri? safeCareerUrl(String value) {
  if (value.isEmpty ||
      value.length > 2048 ||
      RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(value) ||
      RegExp('%0[ad]', caseSensitive: false).hasMatch(value)) {
    return null;
  }
  if (!RegExp(
    r'^https://([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}([/?#][^\s]*)?$',
  ).hasMatch(value)) {
    return null;
  }
  final u = Uri.tryParse(value);
  if (u == null ||
      u.userInfo.isNotEmpty ||
      u.hasPort ||
      RegExp(
        r'(^|\.)(localhost|local|internal|test|invalid)$',
        caseSensitive: false,
      ).hasMatch(u.host)) {
    return null;
  }
  return u;
}

class CareerPost {
  CareerPost(Map<String, dynamic> row) : data = Map.unmodifiable(row);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get title => data['title'] as String;
  String get authorId => data['author_id'] as String;
  String get status => data['status'] as String;
  bool get archived => data['archived'] as bool? ?? false;
  String get updated => data['updated_at'] as String;
  List<String> get skills =>
      (data['required_skills'] as List? ?? []).cast<String>();
  Map<String, dynamic> get cursor => {
    'id': id,
    'created_at': data['created_at'],
    'rank': data['rank'],
  };
  Map<String, dynamic> get input => {
    for (final k in const [
      'title',
      'description',
      'kind',
      'location_text',
      'external_url',
      'status',
      'professional_domain',
      'organization',
      'remote',
      'referral',
      'audience',
      'skill_ids',
    ])
      k: data[k] ?? (k == 'external_url' || k == 'location_text' ? '' : null),
  };
}

abstract class CareerRepository {
  Future<bool> canPublish();
  Future<List<CareerPost>> list(
    Map<String, dynamic> filters, {
    CareerPost? after,
  });
  Future<CareerPost?> detail(String id);
  Future<String> save(
    String id,
    Map<String, dynamic> input, {
    String? expected,
  });
  Future<void> transition(String id, String action);
  Future<void> report(String id, String reason, String details);
  Future<Map<String, String>> skillNames(List<String> ids);
}
