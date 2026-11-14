import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/one_widgets.dart';
import '../../../core/widgets/consumer_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/map_repository.dart';
import '../data/map_providers.dart';
import 'world_geography.dart';

class AlumniMapScreen extends ConsumerStatefulWidget {
  const AlumniMapScreen({
    super.key,
    this.enableNetworkTiles = true,
    this.description = 'Explore consenting verified alumni by approximate city. Pan or pinch to explore; no live tracking or precise personal locations.',
  });
  final bool enableNetworkTiles;
  final String description;
  @override
  ConsumerState<AlumniMapScreen> createState() => _AlumniMapScreenState();
}

class _AlumniMapScreenState extends ConsumerState<AlumniMapScreen> {
  final _controller = MapController(),
      _location = TextEditingController(),
      _domain = TextEditingController();
  List<CityCluster> _cities = [];
  CityCluster? _selected;
  List<Map<String, dynamic>> _members = [];
  bool _busy = false,
      _more = false,
      _memberBusy = false,
      _memberMore = false,
      _tileError = false;
  String? _error, _memberError;
  String _appliedDomain = '', _appliedLocation = '';
  int _generation = 0, _memberGeneration = 0;
  double _zoom = 1;
  final _sheetController = DraggableScrollableController();
  // No network tiles without an approved account/license. Free-plan logo support
  // must be implemented before using a free key; default geography is public domain.
  static const _tileKey = String.fromEnvironment('MAPTILER_PUBLIC_KEY');
  static const _approved = bool.fromEnvironment(
    'MAPTILER_LOGO_EXEMPT_PLAN_APPROVED',
  );
  bool get _tiles =>
      widget.enableNetworkTiles &&
      _approved &&
      RegExp(r'^[A-Za-z0-9_-]{10,100}$').hasMatch(_tileKey) &&
      !_tileError;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _generation++;
    _memberGeneration++;
    _sheetController.dispose();
    _controller.dispose();
    _location.dispose();
    _domain.dispose();
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    if (!next) {
      _appliedDomain = _domain.text;
      _appliedLocation = _location.text;
    }
    final generation = ++_generation;
    _memberGeneration++;
    setState(() {
      _busy = true;
      _error = null;
      _selected = null;
      _members = [];
      if (!next) _cities = [];
    });
    try {
      final rows = await ref
          .read(alumniMapRepositoryProvider)
          .cities(
            location: _appliedLocation,
            domain: _appliedDomain,
            after: next && _cities.isNotEmpty ? _cities.last.id : null,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _cities = next
            ? [..._cities, ...rows.take(100)]
            : rows.take(100).toList();
        _more = rows.length > 100;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Map data unavailable. Check your connection or access and retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _select(CityCluster city, {bool next = false}) async {
    final generation = ++_memberGeneration;
    setState(() {
      _selected = city;
      _memberBusy = true;
      _memberError = null;
      if (!next) _members = [];
    });
    try {
      final rows = await ref
          .read(alumniMapRepositoryProvider)
          .members(
            city.id,
            domain: _appliedDomain,
            after: next && _members.isNotEmpty
                ? _members.last['user_id'] as String
                : null,
          );
      if (!mounted || generation != _memberGeneration) return;
      setState(() {
        _members = next
            ? [..._members, ...rows.take(20)]
            : rows.take(20).toList();
        _memberMore = rows.length > 20;
      });
      if (!next && _sheetController.isAttached) {
        if (MediaQuery.disableAnimationsOf(context)) {
          _sheetController.jumpTo(.55);
        } else {
          _sheetController.animateTo(
            .55,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      }
    } catch (_) {
      if (mounted && generation == _memberGeneration) {
        setState(
          () => _memberError = 'City members unavailable. Visibility or access may have changed.',
        );
      }
    } finally {
      if (mounted && generation == _memberGeneration) {
        setState(() => _memberBusy = false);
      }
    }
  }

  void _move(double delta) {
    final camera = _controller.camera;
    _controller.move(camera.center, (camera.zoom + delta).clamp(0, 8));
  }

  Future<void> _filters() => showFilterSheet<void>(
    context,
    title: 'Map filters',
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _domain,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Professional domain'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            _load();
            Navigator.pop(context);
          },
          child: const Text('Filter map'),
        ),
        const SizedBox(height: 12),
        Text(
          widget.description,
          style: const TextStyle(color: OneColors.muted, fontSize: 12),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final land = ref.watch(landPolygonsProvider),
        groups = groupCities(_cities, _zoom);
    return Material(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: const LatLng(20, 0),
                initialZoom: 1,
                minZoom: 0,
                maxZoom: 8,
                backgroundColor: const Color(0xFFDCEEF8),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onPositionChanged: (camera, _) {
                  if ((camera.zoom - _zoom).abs() > 0.1) {
                    setState(() => _zoom = camera.zoom);
                  }
                },
              ),
              children: [
                if (land.asData != null)
                  PolygonLayer(polygons: land.requireValue),
                if (_tiles)
                  TileLayer(
                    urlTemplate:
                        'https://api.maptiler.com/maps/streets-v4/256/{z}/{x}/{y}.png?key=$_tileKey',
                    userAgentPackageName: 'com.msgi.nexus.msgi_nexus',
                    maxZoom: 8,
                    errorTileCallback: (_, _, _) {
                      if (mounted && !_tileError) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _tileError = true);
                        });
                      }
                    },
                  ),
                MarkerLayer(
                  markers: groups
                      .map(
                        (g) => Marker(
                          point: g.center,
                          width: 52,
                          height: 52,
                          child: Semantics(
                            button: true,
                            label: g.cities.length == 1
                                ? '${g.cities.first.name}: ${g.count} alumni'
                                : '${g.cities.length} cities: ${g.count} alumni',
                            child: Tooltip(
                              message: g.cities.length == 1
                                  ? g.cities.first.name
                                  : 'Zoom to ${g.cities.length} cities',
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(48, 48),
                                  shape: const CircleBorder(),
                                  backgroundColor: OneColors.gold,
                                  foregroundColor: OneColors.navy,
                                ),
                                onPressed: () {
                                  if (g.cities.length > 1) {
                                    if (_zoom >= 7.9) {
                                      showModalBottomSheet<void>(
                                        context: context,
                                        builder: (ctx) => SafeArea(
                                          child: SizedBox(
                                            height: 320,
                                            child: ListView(
                                              children: [
                                                for (final city in g.cities)
                                                  ListTile(
                                                    title: Text(city.name),
                                                    subtitle: Text(
                                                      '${city.count} alumni',
                                                    ),
                                                    onTap: () {
                                                      Navigator.pop(ctx);
                                                      _select(city);
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      _controller.move(
                                        g.center,
                                        (_zoom + 2).clamp(0, 8),
                                      );
                                    }
                                  } else {
                                    _select(g.cities.first);
                                  }
                                },
                                child: Text(
                                  '${g.count}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      OneColors.background,
                      OneColors.background,
                      Color(0x00F5F7FC),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Global alumni map',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    CompactSearch(
                      controller: _location,
                      label: 'City or country',
                      onSearch: _load,
                      onFilters: _filters,
                      filterCount: _appliedDomain.isEmpty ? 0 : 1,
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () => launchUrl(
                            Uri.parse(
                              'https://www.naturalearthdata.com/about/terms-of-use/',
                            ),
                          ),
                          child: const Text(
                            'Made with Natural Earth',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                        if (_tiles) ...[
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse('https://www.maptiler.com/copyright/'),
                            ),
                            child: const Text(
                              'MapTiler',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                            ),
                            child: const Text(
                              'OpenStreetMap contributors',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_busy) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 220 : 164,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filled(
                    tooltip: 'Zoom in',
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Zoom out',
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'World view',
                    onPressed: () => _controller.move(const LatLng(20, 0), 1),
                    icon: const Icon(Icons.public),
                  ),
                ],
              ),
            ),
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: .24,
              minChildSize: .16,
              maxChildSize: .82,
              builder: (context, scrollController) => Material(
                elevation: 6,
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Column(
                          children: [
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: OneColors.border,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selected == null
                                        ? 'Explore by city'
                                        : '${_selected!.name} alumni',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                if (_selected != null)
                                  IconButton(
                                    tooltip: 'All cities',
                                    onPressed: () {
                                      _memberGeneration++;
                                      setState(() {
                                        _selected = null;
                                        _members = [];
                                      });
                                    },
                                    icon: const Icon(Icons.arrow_back),
                                  )
                                else
                                  IconButton(
                                    tooltip: 'Expand city list',
                                    onPressed: () =>
                                        _sheetController.jumpTo(.7),
                                    icon: const Icon(Icons.keyboard_arrow_up),
                                  ),
                              ],
                            ),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'City-level locations only. No live tracking.',
                                style: TextStyle(
                                  color: OneColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (_error != null) Text(_error!),
                            if (_error != null)
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry map'),
                              ),
                            if (_memberBusy) const LinearProgressIndicator(),
                            if (_memberError != null)
                              TextButton(
                                onPressed: () => _select(_selected!),
                                child: Text('$_memberError Retry'),
                              ),
                            if (land.hasError || _tileError)
                              const Text(
                                'Detailed geography is offline. City list remains available.',
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_selected == null)
                      SliverList.builder(
                        itemCount: _cities.length,
                        itemBuilder: (context, index) {
                          final c = _cities[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.location_city_outlined,
                              color: OneColors.blue,
                            ),
                            title: Text('${c.name}, ${c.country}'),
                            subtitle: Text('${c.count} alumni'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _select(c),
                          );
                        },
                      )
                    else
                      SliverList.builder(
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final p = _members[index];
                          return ListTile(
                            leading: ProfileAvatar(p['display_name'] as String),
                            title: Text(p['display_name'] as String),
                            subtitle: Text(
                              '${p['designation'] ?? ''} / ${p['company'] ?? ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/alumni/${p['user_id']}'),
                          );
                        },
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (!_busy && _error == null && _cities.isEmpty)
                              const EmptyState(
                                title: 'No map-visible alumni',
                                message: 'Try fewer filters. Only consenting members appear.',
                              ),
                            if (_selected != null &&
                                !_memberBusy &&
                                _members.isEmpty &&
                                _memberError == null)
                              const Text(
                                'No members currently available for these filters.',
                              ),
                            if (_selected == null && _more)
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _load(next: true),
                                child: const Text('Load more cities'),
                              ),
                            if (_selected != null && _memberMore)
                              OutlinedButton(
                                onPressed: _memberBusy
                                    ? null
                                    : () => _select(_selected!, next: true),
                                child: const Text('Load more city alumni'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
