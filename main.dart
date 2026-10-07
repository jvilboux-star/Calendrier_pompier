import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CalendrierPompierApp());
}

class CalendrierPompierApp extends StatelessWidget {
  const CalendrierPompierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tournée Calendriers',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B3558)),
        useMaterial3: true,
      ),
      home: const MapHomePage(),
    );
  }
}

enum VisitStatus { revisit, done, later }

extension VisitStatusUi on VisitStatus {
  String get label => switch (this) {
        VisitStatus.revisit => 'Absent - à repasser',
        VisitStatus.done => 'Terminé',
        VisitStatus.later => 'À revoir plus tard',
      };

  Color get color => switch (this) {
        VisitStatus.revisit => Colors.red,
        VisitStatus.done => Colors.green,
        VisitStatus.later => Colors.orange,
      };

  IconData get icon => switch (this) {
        VisitStatus.revisit => Icons.home,
        VisitStatus.done => Icons.check_circle,
        VisitStatus.later => Icons.schedule,
      };
}

class HousePoint {
  HousePoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.note,
    required this.updatedAt,
  });

  final String id;
  final double latitude;
  final double longitude;
  final VisitStatus status;
  final String note;
  final DateTime updatedAt;

  LatLng get position => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'status': status.name,
        'note': note,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HousePoint.fromJson(Map<String, dynamic> json) {
    return HousePoint(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      status: VisitStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => VisitStatus.revisit,
      ),
      note: (json['note'] as String?) ?? '',
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  static const _storageKey = 'house_points_v1';

  final MapController _mapController = MapController();
  final List<HousePoint> _houses = [];
  LatLng? _currentPosition;
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadHouses();
    _locateUser(centerMap: true);
  }

  Future<void> _loadHouses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final loaded = decoded
          .map((e) => HousePoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        _houses
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      // Une donnée locale invalide ne doit pas empêcher l'application de démarrer.
    }
  }

  Future<void> _saveHouses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_houses.map((h) => h.toJson()).toList()),
    );
  }

  Future<void> _locateUser({bool centerMap = false}) async {
    if (_loadingLocation) return;
    setState(() => _loadingLocation = true);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showSnack('Active le GPS du téléphone pour afficher ta position.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Autorisation de localisation refusée.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final point = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() => _currentPosition = point);

      if (centerMap) {
        _mapController.move(point, 18);
      }
    } catch (_) {
      _showSnack('Impossible de récupérer la position GPS.');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addHouse(LatLng point) async {
    final result = await _openHouseEditor(
      point: point,
      initialStatus: VisitStatus.revisit,
      initialNote: '',
    );
    if (result == null) return;

    setState(() {
      _houses.add(
        HousePoint(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          latitude: point.latitude,
          longitude: point.longitude,
          status: result.status,
          note: result.note,
          updatedAt: DateTime.now(),
        ),
      );
    });
    await _saveHouses();
  }

  Future<void> _editHouse(HousePoint house) async {
    final result = await _openHouseEditor(
      point: house.position,
      initialStatus: house.status,
      initialNote: house.note,
      canDelete: true,
    );
    if (result == null) return;

    if (result.delete) {
      setState(() => _houses.removeWhere((h) => h.id == house.id));
      await _saveHouses();
      return;
    }

    final index = _houses.indexWhere((h) => h.id == house.id);
    if (index < 0) return;
    setState(() {
      _houses[index] = HousePoint(
        id: house.id,
        latitude: house.latitude,
        longitude: house.longitude,
        status: result.status,
        note: result.note,
        updatedAt: DateTime.now(),
      );
    });
    await _saveHouses();
  }

  Future<_HouseEditorResult?> _openHouseEditor({
    required LatLng point,
    required VisitStatus initialStatus,
    required String initialNote,
    bool canDelete = false,
  }) {
    return showModalBottomSheet<_HouseEditorResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _HouseEditorSheet(
        point: point,
        initialStatus: initialStatus,
        initialNote: initialNote,
        canDelete: canDelete,
      ),
    );
  }

  int _count(VisitStatus status) => _houses.where((h) => h.status == status).length;

  @override
  Widget build(BuildContext context) {
    final fallbackCenter = _houses.isNotEmpty
        ? _houses.first.position
        : const LatLng(45.7640, 4.8357);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournée Calendriers'),
        actions: [
          IconButton(
            tooltip: 'Liste des maisons à repasser',
            onPressed: _showRevisitList,
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: fallbackCenter,
              initialZoom: 16,
              onLongPress: (_, point) => _addHouse(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.pompier.calendriers',
              ),
              MarkerLayer(
                markers: [
                  ..._houses.map(
                    (house) => Marker(
                      point: house.position,
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () => _editHouse(house),
                        child: Container(
                          decoration: BoxDecoration(
                            color: house.status.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(blurRadius: 4, color: Colors.black26),
                            ],
                          ),
                          child: Icon(house.status.icon, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                  ),
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(blurRadius: 5, color: Colors.black38),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Appui long sur une maison pour ajouter un passage',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 18,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatusCount(
                      color: VisitStatus.revisit.color,
                      value: _count(VisitStatus.revisit),
                      label: 'À repasser',
                    ),
                    _StatusCount(
                      color: VisitStatus.done.color,
                      value: _count(VisitStatus.done),
                      label: 'Terminés',
                    ),
                    _StatusCount(
                      color: VisitStatus.later.color,
                      value: _count(VisitStatus.later),
                      label: 'À revoir',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Me localiser',
        onPressed: () => _locateUser(centerMap: true),
        child: _loadingLocation
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }

  void _showRevisitList() {
    final revisit = _houses.where((h) => h.status == VisitStatus.revisit).toList();
    revisit.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        if (revisit.isEmpty) {
          return const SizedBox(
            height: 180,
            child: Center(child: Text('Aucune maison à repasser 🎉')),
          );
        }
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: revisit.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final house = revisit[index];
              return ListTile(
                leading: const Icon(Icons.home, color: Colors.red),
                title: Text('Maison ${index + 1}'),
                subtitle: Text(
                  house.note.isEmpty
                      ? 'Aucune note'
                      : house.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _mapController.move(house.position, 19);
                  _editHouse(house);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({required this.color, required this.value, required this.label});

  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _HouseEditorResult {
  const _HouseEditorResult({
    required this.status,
    required this.note,
    this.delete = false,
  });

  final VisitStatus status;
  final String note;
  final bool delete;
}

class _HouseEditorSheet extends StatefulWidget {
  const _HouseEditorSheet({
    required this.point,
    required this.initialStatus,
    required this.initialNote,
    required this.canDelete,
  });

  final LatLng point;
  final VisitStatus initialStatus;
  final String initialNote;
  final bool canDelete;

  @override
  State<_HouseEditorSheet> createState() => _HouseEditorSheetState();
}

class _HouseEditorSheetState extends State<_HouseEditorSheet> {
  late VisitStatus _status;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Maison', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${widget.point.latitude.toStringAsFixed(6)}, ${widget.point.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<VisitStatus>(
              segments: VisitStatus.values
                  .map(
                    (status) => ButtonSegment(
                      value: status,
                      icon: Icon(status.icon),
                      label: Text(
                        switch (status) {
                          VisitStatus.revisit => 'Repasser',
                          VisitStatus.done => 'Terminé',
                          VisitStatus.later => 'Plus tard',
                        },
                      ),
                    ),
                  )
                  .toList(),
              selected: {_status},
              onSelectionChanged: (selection) {
                setState(() => _status = selection.first);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Note (optionnelle)',
                hintText: 'Ex. Repasser après 18h',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  _HouseEditorResult(status: _status, note: _noteController.text.trim()),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
            ),
            if (widget.canDelete) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(
                    context,
                    _HouseEditorResult(
                      status: _status,
                      note: _noteController.text.trim(),
                      delete: true,
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer ce point'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
