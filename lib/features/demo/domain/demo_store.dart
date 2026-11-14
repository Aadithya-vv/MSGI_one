import 'dart:convert';

import 'package:flutter/foundation.dart';

enum DemoRole { student, alumni, staff }

extension DemoRoleLabel on DemoRole {
  String get label => switch (this) {
    DemoRole.student => 'Student',
    DemoRole.alumni => 'Alumni',
    DemoRole.staff => 'Staff / Faculty',
  };
  String get actor => switch (this) {
    DemoRole.student => 'demo-student-01',
    DemoRole.alumni => 'demo-alumni-01',
    DemoRole.staff => 'demo-staff-01',
  };
}

/// Purpose-built fictional simulation, not an Auth session or a verification model.
/// No SDK/client/key is accepted by this object. All mutation is confined here.
class DemoStore extends ChangeNotifier {
  DemoStore() {
    _seed();
  }
  static const version = 2;
  static const alumniNames = [
    'Arjun Iyer',
    'Leela Menon',
    'Rohan Das',
    'Nila Varma',
    'Dev Shah',
    'Sara Nair',
    'Ishan Rao',
    'Anika Bose',
    'Kabir Sen',
    'Tara Mehta',
    'Vihaan Pillai',
    'Zoya Kumar',
    'Aditya Roy',
    'Meera Joshi',
    'Neil Thomas',
    'Riya Anand',
    'Samar Kapoor',
    'Asha Patel',
    'Yuvan Krishnan',
    'Diya Sethi',
    'Arav Malik',
    'Ira Balan',
    'Kian Dutta',
    'Sana Verma',
  ];
  static const studentNames = [
    'Mira Rao',
    'Ayan Suri',
    'Eva Menon',
    'Rehan Nair',
    'Nisha Dev',
    'Om Varma',
    'Sia Raman',
    'Ved Sen',
  ];
  static const staffNames = [
    'Kavya Sen',
    'Priya Narang',
    'Vikram Bedi',
    'Aditi Soman',
  ];
  static const organizations = [
    'Cobalt Orchard Labs',
    'Northglow Digital',
    'Juniper Signal Studio',
    'Horizon Loom Systems',
    'Terracotta Grid Works',
    'Saffron Arc Analytics',
  ];
  static const designations = [
    'Embedded Systems Engineer',
    'Mobile Product Engineer',
    'Data Science Specialist',
    'Cloud Platform Engineer',
    'Structural Design Engineer',
    'Business Analytics Lead',
  ];
  static const stories = [
    'Builds reliable embedded products and guides early-career engineers through hardware-to-software transitions.',
    'Creates accessible mobile experiences and mentors students on portfolios, Flutter and product thinking.',
    'Turns open datasets into useful tools and helps newcomers develop practical analytical judgment.',
    'Designs resilient cloud platforms and shares hands-on guidance on infrastructure and engineering careers.',
    'Works on sustainable structures and enjoys helping students connect design principles with field practice.',
    'Connects data with business decisions and supports students exploring analytics and cross-functional careers.',
  ];
  static const opportunityTitles = [
    'Embedded Systems Engineer',
    'Flutter Engineering Internship',
    'Open Data Accessibility Project',
    'Cloud Platform Engineer',
    'Structural Design Internship',
    'Market Insights Collaboration',
    'Firmware Test Engineer',
    'Mobile Product Internship',
    'Community Data Atlas',
    'Cloud Reliability Engineer',
    'Sustainable Design Internship',
    'Analytics Portfolio Project',
  ];
  DemoRole role = DemoRole.student;
  bool active = false;
  int tick = 1000;
  final profiles = <String, Map<String, dynamic>>{},
      connections = <String, Map<String, dynamic>>{},
      posts = <String, Map<String, dynamic>>{},
      goals = <String, Map<String, dynamic>>{};
  final reports = <String, Map<String, dynamic>>{}, blocks = <String>{};
  String get actor => role.actor;
  Map<String, dynamic> get person => profiles[actor]!;
  static const domains = [
    'Embedded Systems',
    'Software Engineering',
    'Data Science',
    'Cloud Infrastructure',
    'Civil Engineering',
    'Business Analytics',
  ];
  static const skillLabels = [
    'C++',
    'Embedded Linux',
    'Flutter',
    'Dart',
    'Python',
    'SQL',
    'Cloud Platforms',
    'Networks',
    'CAD',
    'Project Planning',
    'Data Analysis',
    'Communication',
  ];
  static const cities = [
    ('Bengaluru', 'IN', 12.9, 77.6),
    ('London', 'GB', 51.5, -0.1),
    ('Toronto', 'CA', 43.7, -79.4),
    ('Dubai', 'AE', 25.3, 55.3),
    ('Singapore', 'SG', 1.4, 103.8),
    ('Sydney', 'AU', -33.9, 151.2),
  ];
  static String skillId(int n) => 'demo-skill-${n.toString().padLeft(2, '0')}';
  static String skillName(String id) =>
      skillLabels[int.parse(id.split('-').last)];
  static String cityId(int n) => 'demo-city-$n';
  String stamp() => DateTime.utc(
    2026,
    11,
    14,
  ).add(Duration(seconds: tick++)).toIso8601String();
  void changed() => notifyListeners();
  void switchRole(DemoRole next) {
    role = next;
    active = true;
    changed();
  }

  void reset() {
    role = DemoRole.student;
    active = true;
    tick = 1000;
    profiles.clear();
    connections.clear();
    posts.clear();
    goals.clear();
    reports.clear();
    blocks.clear();
    _seed();
    changed();
  }

  void _seed() {
    for (final entry in [
      (DemoRole.alumni, 24),
      (DemoRole.student, 8),
      (DemoRole.staff, 4),
    ]) {
      for (var i = 1; i <= entry.$2; i++) {
        final role = entry.$1,
            id = 'demo-${role.name}-${i.toString().padLeft(2, '0')}',
            d = (i - 1) % 6;
        final named = switch (role) {
          DemoRole.alumni => alumniNames[i - 1],
          DemoRole.student => studentNames[i - 1],
          DemoRole.staff => staffNames[i - 1],
        };
        final pair = d * 2;
        final skills = [skillId(pair), skillId(pair + 1), skillId(5)];
        profiles[id] = {
          'user_id': id,
          'display_name': named,
          'role': role.name,
          'institution_id': i % 2 == 0 ? 'demo-campus-b' : 'demo-campus-a',
          'department_id': i % 2 == 0 ? 'demo-dept-b' : 'demo-dept-a',
          'institution': i % 2 == 0
              ? 'Sample Engineering Institute B'
              : 'Sample Engineering Institute A',
          'department': 'Sample Engineering Department',
          'graduation_year': role == DemoRole.student ? 2028 : 2010 + i % 14,
          'joining_year': role == DemoRole.student ? 2024 : 2006 + i % 14,
          'designation': role == DemoRole.staff
              ? 'Faculty & Career Advisor'
              : role == DemoRole.student
              ? 'Engineering Student'
              : designations[d],
          'company': role == DemoRole.student
              ? 'Student Innovation Circle (Fictional)'
              : role == DemoRole.staff
              ? 'Faculty Learning Collective (Fictional)'
              : '${organizations[d]} (Fictional)',
          'professional_domain': id == 'demo-student-01'
              ? 'Software Engineering'
              : domains[d],
          'biography': role == DemoRole.alumni
              ? stories[d]
              : role == DemoRole.student
              ? 'Exploring ${domains[d].toLowerCase()} through student projects, practical learning and guidance from the alumni community.'
              : 'Supports student projects, interdisciplinary learning and thoughtful career exploration across the community.',
          'degree': role == DemoRole.staff
              ? 'Postgraduate Engineering'
              : 'Bachelor of Engineering',
          'skill_ids': id == 'demo-student-01'
              ? [skillId(2), skillId(3)]
              : skills.toSet().toList(),
          'career_interests': ['Career guidance', 'Product building'],
          'city_id': cityId((i - 1) % 6),
          'directory_visible': id != 'demo-alumni-24',
          'map_opt_in': role == DemoRole.alumni && i < 23,
          'mentoring': role == DemoRole.alumni && i <= 14,
        };
      }
    }
    void link(String id, String sender, String recipient, String status) {
      connections[id] = {
        'id': id,
        'sender': sender,
        'recipient': recipient,
        'status': status,
      };
    }

    link('demo-link-01', 'demo-student-01', 'demo-alumni-01', 'pending');
    link('demo-link-02', 'demo-alumni-02', 'demo-student-01', 'pending');
    link('demo-link-03', 'demo-student-01', 'demo-alumni-03', 'accepted');
    link('demo-link-04', 'demo-alumni-01', 'demo-alumni-04', 'accepted');
    link('demo-link-05', 'demo-staff-01', 'demo-alumni-05', 'accepted');
    link('demo-link-06', 'demo-student-02', 'demo-alumni-01', 'pending');
    for (var i = 1; i <= 12; i++) {
      final kind = ['job', 'internship', 'collaboration'][(i - 1) % 3],
          author = i == 12
              ? 'demo-alumni-01'
              : 'demo-alumni-${i.toString().padLeft(2, '0')}',
          p = profiles[author]!;
      final date = DateTime.utc(
        2026,
        11,
        1,
      ).add(Duration(hours: i)).toIso8601String();
      posts['demo-post-${i.toString().padLeft(2, '0')}'] = {
        'id': 'demo-post-${i.toString().padLeft(2, '0')}',
        'author_id': author,
        'title': opportunityTitles[i - 1],
        'description':
            'Fictional demo opportunity. ${stories[(i - 1) % 6]} Collaborate on practical challenges, share your approach and learn with a supportive team. This is not a real vacancy, employer partnership or referral.',
        'kind': kind,
        'location_text': cities[(i - 1) % 6].$1,
        'external_url': '',
        'status': i == 12 ? 'draft' : 'published',
        'professional_domain': p['professional_domain'],
        'organization': p['company'],
        'remote': i.isEven,
        'referral': kind != 'collaboration' && i % 4 == 0,
        'audience': 'community',
        'archived': false,
        'skill_ids': List<String>.from(p['skill_ids'] as List),
        'created_at': date,
        'updated_at': date,
      };
    }
  }

  Map<String, dynamic>? relationship(String peer) => connections.values
      .where(
        (c) =>
            (c['sender'] == actor && c['recipient'] == peer) ||
            (c['recipient'] == actor && c['sender'] == peer),
      )
      .firstOrNull;
  void updatePerson(Map<String, dynamic> input) {
    for (final key in input.keys) {
      if (![
        'display_name',
        'biography',
        'mentoring',
        'directory_visible',
        'map_opt_in',
      ].contains(key)) {
        throw StateError('Unsupported demo preference');
      }
    }
    if ((input['display_name'] as String? ?? person['display_name'] as String)
        .trim()
        .isEmpty) {
      throw StateError('Name required');
    }
    person.addAll(input);
    if (person['directory_visible'] != true) person['map_opt_in'] = false;
    if (role != DemoRole.alumni) person['mentoring'] = false;
    changed();
  }

  Map<String, dynamic> snapshot() => {
    'version': version,
    'role': role.name,
    'active': active,
    'tick': tick,
    'profiles': profiles,
    'connections': connections,
    'posts': posts,
    'goals': goals,
    'reports': reports,
    'blocks': blocks.toList(),
  };
  factory DemoStore.restore(Map<String, dynamic>? value) {
    final result = DemoStore();
    if (value == null) return result;
    try {
      if (value['version'] != 1 && value['version'] != version) {
        throw StateError('Unknown demo format');
      }
      final restored = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
      final role = DemoRole.values.byName(restored['role'] as String);
      final people = Map<String, dynamic>.from(restored['profiles'] as Map);
      if (people.length != 36 ||
          !people.containsKey(role.actor) ||
          !people.keys.toSet().containsAll(result.profiles.keys)) {
        throw StateError('Invalid fixture identities');
      }
      for (final field in [
        'profiles',
        'connections',
        'posts',
        'goals',
        'reports',
      ]) {
        final data = Map<String, dynamic>.from(restored[field] as Map);
        final target = switch (field) {
          'profiles' => result.profiles,
          'connections' => result.connections,
          'posts' => result.posts,
          'goals' => result.goals,
          _ => result.reports,
        };
        // Upgrade only original placeholder copy; preserve edited profiles, posts,
        // preferences, requests and status transitions from the previous demo.
        if (value['version'] == 1 &&
            (field == 'profiles' || field == 'posts')) {
          for (final entry in data.entries) {
            final old = Map<String, dynamic>.from(entry.value as Map);
            final fresh = target[entry.key];
            if (fresh == null) continue;
            if (field == 'profiles') {
              for (final key in [
                'display_name',
                'designation',
                'company',
                'biography',
                'degree',
              ]) {
                final text = old[key] as String? ?? '';
                final originalName =
                    RegExp(r'^(Alumni|Student|Faculty) \d{2} \(Demo\)$')
                        .hasMatch(text) ||
                    [
                      'Mira Rao (Demo)',
                      'Arjun Iyer (Demo)',
                      'Kavya Sen (Demo)',
                    ].contains(text);
                if ((key == 'display_name' && originalName) ||
                    (key != 'display_name' && text.startsWith('Sample ')) ||
                    (key == 'biography' && text.startsWith('A fictional '))) {
                  old[key] = fresh[key];
                }
              }
            } else {
              if (RegExp(r'^Demo .+ (job|internship|project) \d+$')
                  .hasMatch(old['title'] as String? ?? '')) {
                old['title'] = fresh['title'];
              }
              if ((old['description'] as String? ?? '').startsWith(
                'Fictional demonstration only.',
              )) {
                old['description'] = fresh['description'];
              }
              if ((old['organization'] as String? ?? '').startsWith(
                'Sample Organization ',
              )) {
                old['organization'] = fresh['organization'];
              }
            }
            data[entry.key] = old;
          }
        }
        target.clear();
        target.addAll(
          data.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map))),
        );
      }
      result.role = role;
      result.active = restored['active'] as bool;
      result.tick = restored['tick'] as int;
      result.blocks.addAll((restored['blocks'] as List).cast<String>());
      // Validate serialized types; corrupt private storage falls back to fresh fixtures.
      for (final p in result.profiles.values) {
        for (final key in [
          'display_name',
          'role',
          'institution_id',
          'department_id',
          'institution',
          'department',
          'designation',
          'company',
          'professional_domain',
          'biography',
          'degree',
          'city_id',
        ]) {
          p[key] as String;
        }
        DemoRole.values.byName(p['role'] as String);
        for (final key in ['mentoring', 'directory_visible', 'map_opt_in']) {
          p[key] as bool;
        }
        for (final id in (p['skill_ids'] as List).cast<String>()) {
          skillName(id);
        }
        (p['career_interests'] as List).cast<String>();
        p['joining_year'] as int;
        p['graduation_year'] as int;
      }
      for (final c in result.connections.values) {
        if (!result.profiles.containsKey(c['sender']) ||
            !result.profiles.containsKey(c['recipient']) ||
            ![
              'pending',
              'accepted',
              'rejected',
              'cancelled',
            ].contains(c['status'])) {
          throw StateError('Invalid demo connection');
        }
      }
      for (final p in result.posts.values) {
        for (final key in [
          'id',
          'author_id',
          'title',
          'description',
          'kind',
          'location_text',
          'external_url',
          'status',
          'professional_domain',
          'organization',
          'audience',
          'created_at',
          'updated_at',
        ]) {
          p[key] as String;
        }
        for (final key in ['archived', 'remote', 'referral']) {
          p[key] as bool;
        }
        if (!result.profiles.containsKey(p['author_id']) ||
            p['external_url'] != '' ||
            !['job', 'internship', 'collaboration'].contains(p['kind']) ||
            !['draft', 'published', 'closed'].contains(p['status'])) {
          throw StateError('Invalid demo post');
        }
        for (final id in (p['skill_ids'] as List).cast<String>()) {
          skillName(id);
        }
      }
      for (final entry in result.goals.entries) {
        if (!result.profiles.containsKey(entry.key)) continue;
        for (final key in [
          'career_interests',
          'target_domains',
          'existing_skill_ids',
          'learning_skill_ids',
          'objectives',
        ]) {
          (entry.value[key] as List).cast<String>();
        }
      }
      return result;
    } catch (_) {
      return DemoStore();
    }
  }
}
