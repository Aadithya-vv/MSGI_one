import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/one_widgets.dart';
import 'opportunities_screen.dart' show careerKindLabel, careerStatusLabel;
import '../../../core/community_identity.dart';
import '../domain/career_repository.dart';
import '../data/career_providers.dart';

class CareerDetailScreen extends ConsumerStatefulWidget {
  const CareerDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<CareerDetailScreen> createState() => _CareerDetailScreenState();
}

class _CareerDetailScreenState extends ConsumerState<CareerDetailScreen> {
  CareerPost? _post;
  bool _loading = true, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ref.read(careerRepositoryProvider).detail(widget.id);
      if (mounted) _post = p;
    } catch (_) {
      if (mounted) {
        _error =
            'Opportunity unavailable. Check access or connection and retry.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transition(String action) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          action == 'archive'
              ? 'Archive this opportunity?'
              : 'Close this opportunity?',
        ),
        content: Text(
          action == 'archive'
              ? 'It will leave discovery. The post and any reports will be retained.'
              : 'It will stop accepting applications and become author-only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep post'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(careerRepositoryProvider).transition(widget.id, action);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not update the post. Check access and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String value) async {
    final uri = safeCareerUrl(value);
    if (uri == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open application site?'),
        content: Text(
          'Continue in your browser to ${uri.host}. MSGI One does not verify external employers or collect applications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay here'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open site'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Browser unavailable');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Application link could not be opened. Try again later.',
        );
      }
    }
  }

  Future<void> _report() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => CareerReportDialog(id: widget.id),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent to moderation.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;
    final own = p?.authorId == ref.watch(communityUserIdProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opportunity details'),
        leading: BackButton(onPressed: () => context.go('/opportunities')),
      ),
      body: PageBody(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Semantics(liveRegion: true, child: Text(_error!)),
            TextButton(
              onPressed: _load,
              child: const Text('Retry opportunity'),
            ),
          ],
          if (!_loading && p == null && _error == null)
            const EmptyState(
              title: 'Post no longer available',
              message: 'It may be private, closed, archived or outside your audience.',
            ),
          if (p != null) ...[
            Text(p.title, style: Theme.of(context).textTheme.headlineMedium),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    p.archived ? 'Archived' : careerStatusLabel(p.status),
                  ),
                ),
                Chip(label: Text(careerKindLabel(p.data['kind'] as String))),
                if (own) const Chip(label: Text('Your post')),
                if (p.data['remote'] == true) const Chip(label: Text('Remote')),
                if (p.data['referral'] == true)
                  const Chip(label: Text('Referral')),
              ],
            ),
            Text(
              '${p.data['organization']} | ${p.data['professional_domain']}',
            ),
            Text(p.data['location_text'] as String? ?? ''),
            const SectionHeading('About the opportunity'),
            Text(p.data['description'] as String),
            const SectionHeading('Required skills'),
            if (p.skills.isEmpty)
              const Text('No skill criteria specified')
            else
              SkillTags(p.skills),
            const SizedBox(height: 20),
            Text('Audience: ${p.data['audience']}'),
            Text(
              'Author: ${own ? 'You' : p.data['author_name'] ?? 'Verified community member'}',
            ),
            if (p.data['author_available'] == true)
              TextButton(
                onPressed: () => context.go('/alumni/${p.authorId}'),
                child: const Text('View author profile'),
              ),
            if (p.status == 'published' &&
                !p.archived &&
                safeCareerUrl(p.data['external_url'] as String? ?? '') != null)
              FilledButton(
                onPressed: () => _open(p.data['external_url'] as String),
                child: const Text('Apply externally'),
              ),
            if (p.status != 'published' || p.archived)
              const Text('This post is not accepting applications.'),
            if (own && !p.archived) ...[
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => context.go('/opportunities/${p.id}/edit'),
                child: const Text('Edit opportunity'),
              ),
              if (p.status != 'closed')
                OutlinedButton(
                  onPressed: _busy ? null : () => _transition('close'),
                  child: const Text('Close opportunity'),
                ),
              TextButton(
                onPressed: _busy ? null : () => _transition('archive'),
                child: const Text('Archive opportunity'),
              ),
            ],
            if (!own && p.status == 'published')
              TextButton(
                onPressed: _report,
                child: const Text('Report opportunity'),
              ),
          ],
        ],
      ),
    );
  }
}

class CareerReportDialog extends ConsumerStatefulWidget {
  const CareerReportDialog({super.key, required this.id});
  final String id;
  @override
  ConsumerState<CareerReportDialog> createState() => _CareerReportDialogState();
}

class _CareerReportDialogState extends ConsumerState<CareerReportDialog> {
  final _details = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _reason = 'other';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(careerRepositoryProvider)
          .report(widget.id, _reason, _details.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Report could not be sent. Check access and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Report opportunity'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [
                for (final r in [
                  'harassment',
                  'impersonation',
                  'inappropriate',
                  'other',
                ])
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: _busy ? null : (v) => setState(() => _reason = v!),
            ),
            TextFormField(
              controller: _details,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Report details'),
              maxLength: 2000,
              minLines: 3,
              maxLines: 6,
              validator: (v) => (v ?? '').trim().length < 10
                  ? 'Please provide at least 10 characters.'
                  : null,
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _send,
        child: Text(_busy ? 'Sending...' : 'Send report'),
      ),
    ],
  );
}
