import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/domain/onboarding.dart';
import '../../profile/data/profile_providers.dart';
import '../domain/catalog_repository.dart';

/// Search is paginated at the server; selected items remain visible across pages.
class CatalogPicker extends ConsumerStatefulWidget {
  const CatalogPicker({
    super.key,
    required this.kind,
    required this.label,
    required this.onSelected,
    this.institutionId,
    this.enabled = true,
  });
  final CatalogKind kind;
  final String label;
  final String? institutionId;
  final bool enabled;
  final ValueChanged<CatalogEntry> onSelected;
  @override
  ConsumerState<CatalogPicker> createState() => _CatalogPickerState();
}

class _CatalogPickerState extends ConsumerState<CatalogPicker> {
  final _search = TextEditingController();
  Timer? _timer;
  List<CatalogEntry> _items = [];
  int _page = 0, _generation = 0;
  bool _busy = false, _more = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _generation++;
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      if (!next) {
        _page = 0;
        _items = [];
      }
    });
    try {
      final rows = await ref
          .read(catalogRepositoryProvider)
          .search(
            widget.kind,
            query: _search.text,
            institutionId: widget.institutionId,
            page: next ? _page + 1 : 0,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (next) _page++;
        _items = next ? [..._items, ...rows] : rows;
        _more = rows.length == 50;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Catalog unavailable. Retry.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _search,
        enabled: widget.enabled,
        decoration: InputDecoration(
          labelText: 'Search ${widget.label}',
          prefixIcon: const Icon(Icons.search),
        ),
        onChanged: (_) {
          _timer?.cancel();
          _timer = Timer(const Duration(milliseconds: 300), _load);
        },
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) TextButton(onPressed: _load, child: Text(_error!)),
      if (!_busy && _items.isEmpty && _error == null)
        Text('No ${widget.label.toLowerCase()} found.'),
      Wrap(
        spacing: 6,
        children: _items
            .map(
              (e) => ActionChip(
                label: Text(
                  e.countryCode == null
                      ? e.name
                      : '${e.name}, ${e.countryCode}',
                ),
                onPressed: widget.enabled ? () => widget.onSelected(e) : null,
              ),
            )
            .toList(),
      ),
      if (_more)
        TextButton(
          onPressed: _busy ? null : () => _load(next: true),
          child: const Text('More options'),
        ),
    ],
  );
}
