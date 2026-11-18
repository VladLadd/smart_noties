import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/note_location.dart';
import '../providers/locale_provider.dart';

class NoteLocationCard extends StatelessWidget {
  final NoteLocation location;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  const NoteLocationCard(
      {super.key, required this.location, this.onEdit, this.onRemove});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(location.label.isEmpty
              ? context.strings.location
              : location.label),
          subtitle: Text(location.coordinates),
          onTap: () => openLocationMaps(context, location),
          trailing: onEdit == null && onRemove == null
              ? const Icon(Icons.open_in_new)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (onEdit != null)
                    IconButton(
                        tooltip: context.strings.edit,
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined)),
                  if (onRemove != null)
                    IconButton(
                        tooltip: context.strings.delete,
                        onPressed: onRemove,
                        icon: const Icon(Icons.close)),
                ]),
        ),
      );
}

Future<void> openLocationMaps(
    BuildContext context, NoteLocation location) async {
  final strings = context.readStrings;
  var maps = <AvailableMap>[];
  try {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        maps = await MapLauncher.installedMaps;
      } catch (_) {
        // Если список приложений недоступен, остаётся открытие в браузере.
      }
    }
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<int>(
        context: context,
        builder: (ctx) => SafeArea(
                child: ListView(shrinkWrap: true, children: [
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(strings.openInMaps,
                      style: Theme.of(ctx).textTheme.titleLarge)),
              for (var i = 0; i < maps.length; i++)
                ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: Text(maps[i].mapName),
                    onTap: () => Navigator.pop(ctx, i)),
              ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(strings.openMapInBrowser),
                  onTap: () => Navigator.pop(ctx, -1)),
            ])));
    if (selected == null) return;
    if (selected >= 0) {
      await maps[selected].showMarker(
          coords: Coords(location.latitude, location.longitude),
          title: location.label.isEmpty ? strings.location : location.label);
    } else {
      final url = Uri.https('www.openstreetmap.org', '/', {
        'mlat': '${location.latitude}',
        'mlon': '${location.longitude}',
      }).replace(fragment: 'map=16/${location.latitude}/${location.longitude}');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError(strings.mapOpenError);
      }
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.mapOpenError)));
    }
  }
}

Future<NoteLocation?> editNoteLocation(
        BuildContext context, NoteLocation? initial) =>
    showDialog<NoteLocation>(
        context: context, builder: (_) => _LocationDialog(initial: initial));

class _LocationDialog extends StatefulWidget {
  final NoteLocation? initial;
  const _LocationDialog({this.initial});
  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.initial?.label);
  late final _latitude =
      TextEditingController(text: widget.initial?.latitude.toString());
  late final _longitude =
      TextEditingController(text: widget.initial?.longitude.toString());
  bool _loading = false;
  bool _settings = false;
  String? _error;
  double? _number(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  Future<void> _currentPosition() async {
    if (_loading) return;
    final strings = context.readStrings;
    setState(() {
      _loading = true;
      _error = null;
      _settings = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _error = strings.locationServiceOff;
            _settings = true;
          });
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _error = strings.locationPermissionDenied;
            _settings = permission == LocationPermission.deniedForever;
          });
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20)));
      if (!mounted) return;
      _latitude.text = position.latitude.toString();
      _longitude.text = position.longitude.toString();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = strings.locationUnavailable);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(strings.location),
      content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
              child: Form(
                  key: _form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    OutlinedButton.icon(
                        onPressed: _loading ? null : _currentPosition,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location),
                        label: Text(strings.currentLocation)),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _label,
                        maxLength: 120,
                        decoration:
                            InputDecoration(labelText: strings.locationName)),
                    const SizedBox(height: 12),
                    TextFormField(
                        key: const ValueKey('location-latitude'),
                        controller: _latitude,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration:
                            InputDecoration(labelText: strings.latitude),
                        validator: (value) {
                          final number = _number(value);
                          return number != null &&
                                  number.isFinite &&
                                  number >= -90 &&
                                  number <= 90
                              ? null
                              : strings.invalidLatitude;
                        }),
                    const SizedBox(height: 12),
                    TextFormField(
                        key: const ValueKey('location-longitude'),
                        controller: _longitude,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration:
                            InputDecoration(labelText: strings.longitude),
                        validator: (value) {
                          final number = _number(value);
                          return number != null &&
                                  number.isFinite &&
                                  number >= -180 &&
                                  number <= 180
                              ? null
                              : strings.invalidLongitude;
                        }),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    if (_settings && !kIsWeb)
                      TextButton(
                          onPressed: () async {
                            if (!await Geolocator.isLocationServiceEnabled()) {
                              await Geolocator.openLocationSettings();
                            } else {
                              await Geolocator.openAppSettings();
                            }
                          },
                          child: Text(strings.locationSettings)),
                  ])))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel)),
        FilledButton(
            onPressed: _loading
                ? null
                : () {
                    if (_form.currentState!.validate()) {
                      Navigator.pop(
                          context,
                          NoteLocation(
                              latitude: _number(_latitude.text)!,
                              longitude: _number(_longitude.text)!,
                              label: _label.text.trim()));
                    }
                  },
            child: Text(strings.save)),
      ],
    );
  }
}
