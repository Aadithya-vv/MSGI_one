import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/one_widgets.dart';
import '../../../core/errors/error_state.dart';
import '../data/administration_providers.dart';
import '../domain/administration_repository.dart';

String administrationRequestId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final s = b.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

class AdministrationDashboard extends StatefulWidget {
  const AdministrationDashboard({
    required this.summary,
    required this.onReview,
    super.key,
  });
  final Map<String, dynamic> summary;
  final Future<void> Function(MembershipCandidate) onReview;
  @override
  State<AdministrationDashboard> createState() => _DashboardState();
}

class _DashboardState extends State<AdministrationDashboard> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FeatureHeader(
            eyebrow: 'Trusted institutional review',
            title: 'Review pending memberships',
            description: 'Declared details are claims. Review approved offline evidence; email confirmation is not institutional verification.',
          ),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Pending: ${widget.summary['pending']}')),
              Chip(label: Text('Open reports: ${widget.summary['reports']}')),
              Chip(
                label: Text('Review requests: ${widget.summary['requests']}'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in [
                (0, 'Memberships'),
                (1, 'Reports'),
                (2, 'Operations help'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: tab == entry.$1,
                  onSelected: (_) => setState(() => tab = entry.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (tab == 0) _MembershipQueue(onReview: widget.onReview),
          if (tab == 1) const _ReportsQueue(),
          if (tab == 2)
            const Text(
              'Only explicitly authorized, verified administrators may act, within their own institution. Staff selection grants no privilege.\n\nCheck claims against independently approved college records or offline evidence. Do not upload identity documents, passwords or recovery links.\n\nApproval, rejection, suspension, reinstatement and correction are separate decisions. Correction returns a reviewed account to pending and removes community access until verified again.\n\nUse an approved institutional support channel for appeals. No support address has been configured. Administrator replacement is an owner-only, independently approved operation, never a client self-service action.\n\nHistory is private and cannot be erased here. Refresh stale reviews before deciding. See docs/institutional-admin-operations.md for handover and escalation.',
            ),
        ],
      ),
    ),
  );
}

class _MembershipQueue extends ConsumerStatefulWidget {
  const _MembershipQueue({required this.onReview});
  final Future<void> Function(MembershipCandidate) onReview;
  @override
  ConsumerState<_MembershipQueue> createState() => _MembershipQueueState();
}

class _MembershipQueueState extends ConsumerState<_MembershipQueue> {
  String status = 'pending';
  String? kind;
  int offset = 0;
  late Future<List<MembershipCandidate>> future;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    future = ref
        .read(administrationRepositoryProvider)
        .members(status: status, kind: kind, offset: offset);
  }

  void reload({bool reset = false}) {
    setState(() {
      if (reset) offset = 0;
      load();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Membership status'),
        items: [
          'pending',
          'verified',
          'rejected',
          'suspended',
        ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (s) {
          status = s!;
          reload(reset: true);
        },
      ),
      DropdownButtonFormField<String>(
        initialValue: kind ?? 'all',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Declared account type'),
        items: [
          'all',
          'student',
          'alumni',
          'staff',
        ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (s) {
          kind = s == 'all' ? null : s;
          reload(reset: true);
        },
      ),
      FutureBuilder<List<MembershipCandidate>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState();
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: 'Administrator access is required, or reviews could not be loaded. No privileges have been changed.',
              onRetry: reload,
            );
          }
          final people = snapshot.data!;
          return Column(
            children: [
              if (people.isEmpty)
                const EmptyState(
                  title: 'No pending reviews',
                  message: 'No matching memberships on this page. Refresh or adjust filters.',
                ),
              for (final p in people)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          p.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('Claimed ${p.claimedKind} · ${p.status}'),
                        Text(
                          [
                            p.institution,
                            p.programme,
                            p.department,
                            p.affiliation,
                            p.professional,
                            if (p.joiningYear != null)
                              'Joining year: ${p.joiningYear}',
                            if (p.graduationYear != null)
                              'Graduation year: ${p.graduationYear}',
                            if (p.requestKind != null)
                              'Open ${p.requestKind} request',
                          ].where((s) => s.isNotEmpty).join('\n'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            await widget.onReview(p);
                            if (mounted) reload();
                          },
                          child: const Text('Review evidence and decide'),
                        ),
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => _HistoryDialog(userId: p.id),
                          ),
                          child: const Text('Private review history'),
                        ),
                      ],
                    ),
                  ),
                ),
              _PageControls(
                offset: offset,
                hasNext: people.length == 30,
                onPrevious: () {
                  offset -= 30;
                  reload();
                },
                onNext: () {
                  offset += 30;
                  reload();
                },
              ),
            ],
          );
        },
      ),
      TextButton(
        onPressed: reload,
        child: const Text('Refresh pending reviews'),
      ),
    ],
  );
}

class _HistoryDialog extends ConsumerStatefulWidget {
  const _HistoryDialog({required this.userId});
  final String userId;
  @override
  ConsumerState<_HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends ConsumerState<_HistoryDialog> {
  int offset = 0;
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    future = ref
        .read(administrationRepositoryProvider)
        .history(widget.userId, offset: offset);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Private review history'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const LoadingState();
            }
            if (s.hasError) {
              return const Text(
                'History unavailable. Close and retry after checking access.',
              );
            }
            final items = s.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (items.isEmpty)
                  const Text(
                    'No operations recorded on this page. Legacy verification history remains available to authorized operators.',
                  ),
                for (final a in items)
                  ListTile(
                    title: Text('${a['action']} · ${a['category']}'),
                    subtitle: Text(
                      '${a['before_state']} → ${a['after_state']}\n${a['note']}\nReviewer ${a['actor_id']}\n${a['created_at']}',
                    ),
                  ),
                _PageControls(
                  offset: offset,
                  hasNext: items.length == 30,
                  onPrevious: () => setState(() {
                    offset -= 30;
                    load();
                  }),
                  onNext: () => setState(() {
                    offset += 30;
                    load();
                  }),
                ),
              ],
            );
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _ReportsQueue extends ConsumerStatefulWidget {
  const _ReportsQueue();
  @override
  ConsumerState<_ReportsQueue> createState() => _ReportsQueueState();
}

class _ReportsQueueState extends ConsumerState<_ReportsQueue> {
  String status = 'open';
  int offset = 0;
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    future = ref
        .read(administrationRepositoryProvider)
        .reports(status: status, offset: offset);
  }

  void reload() {
    setState(load);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      DropdownButtonFormField<String>(
        initialValue: status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Report status'),
        items: [
          'open',
          'resolved',
          'dismissed',
        ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (s) {
          status = s!;
          offset = 0;
          reload();
        },
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const LoadingState();
          }
          if (s.hasError) {
            return ErrorState(
              message:
                  'Reports unavailable. Check administrator access and retry.',
              onRetry: reload,
            );
          }
          final items = s.data!;
          return Column(
            children: [
              if (items.isEmpty)
                const EmptyState(
                  title: 'No matching reports',
                  message: 'Reports are private; reporters are not listed in this queue.',
                ),
              for (final r in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${r['reason']} · ${r['status']}'),
                        Text(r['details'] as String),
                        Text(
                          'Target: ${r['target_profile_id'] ?? r['target_opportunity_id']}\nRelated reports: ${r['prior_reports']}',
                        ),
                        if (status == 'open')
                          OutlinedButton(
                            onPressed: () async {
                              final saved = await showDialog<bool>(
                                context: context,
                                builder: (_) => _ModerationDialog(report: r),
                              );
                              if (saved == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Moderation decision recorded.',
                                    ),
                                  ),
                                );
                              }
                              if (mounted) reload();
                            },
                            child: const Text('Review moderation decision'),
                          ),
                      ],
                    ),
                  ),
                ),
              _PageControls(
                offset: offset,
                hasNext: items.length == 30,
                onPrevious: () {
                  offset -= 30;
                  reload();
                },
                onNext: () {
                  offset += 30;
                  reload();
                },
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _ModerationDialog extends ConsumerStatefulWidget {
  const _ModerationDialog({required this.report});
  final Map<String, dynamic> report;
  @override
  ConsumerState<_ModerationDialog> createState() => _ModerationDialogState();
}

class _ModerationDialogState extends ConsumerState<_ModerationDialog> {
  final note = TextEditingController(), request = administrationRequestId();
  String status = 'resolved';
  bool busy = false, checked = false;
  String? error;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Confirm private moderation decision'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Resolve or dismiss this report under approved policy. “Resolve and archive” also hides the reported opportunity. Account suspension is a separate decision.',
            ),
            DropdownButtonFormField<String>(
              initialValue: status,
              items:
                  [
                        'resolved',
                        'dismissed',
                        if (widget.report['target_opportunity_id'] != null)
                          'archive',
                      ]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            v == 'archive'
                                ? 'Resolve and archive opportunity'
                                : v,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: busy ? null : (v) => setState(() => status = v!),
            ),
            TextField(
              controller: note,
              maxLength: 1000,
              maxLines: 3,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Private moderation reason',
              ),
            ),
            CheckboxListTile(
              title: const Text(
                'I reviewed this report under approved policy.',
              ),
              value: checked,
              onChanged: busy ? null : (v) => setState(() => checked = v!),
            ),
            if (error != null) Semantics(liveRegion: true, child: Text(error!)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (!checked || note.text.trim().isEmpty) {
                    setState(
                      () => error =
                          'Review the report and enter a non-sensitive reason.',
                    );
                    return;
                  }
                  setState(() => busy = true);
                  try {
                    await ref
                        .read(administrationRepositoryProvider)
                        .moderate(widget.report, status, note.text, request);
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => error = 'Decision unavailable or changed. Close, refresh and review again.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'Saving…' : 'Confirm moderation'),
        ),
      ],
    ),
  );
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.offset,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });
  final int offset;
  final bool hasNext;
  final VoidCallback onPrevious, onNext;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text('Page ${offset ~/ 30 + 1}'),
      TextButton(
        onPressed: offset == 0 ? null : onPrevious,
        child: const Text('Previous page'),
      ),
      TextButton(
        onPressed: !hasNext || offset >= 9990 ? null : onNext,
        child: const Text('Next page'),
      ),
    ],
  );
}
