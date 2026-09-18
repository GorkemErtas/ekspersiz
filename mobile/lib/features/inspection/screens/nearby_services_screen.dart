import 'package:mobile/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nearby_service.dart';
import '../services/nearby_service_service.dart';

class NearbyServicesScreen extends StatefulWidget {
  const NearbyServicesScreen({
    super.key,
    required this.inspectionId,
    required this.latitude,
    required this.longitude,
  });

  final int inspectionId;
  final double latitude;
  final double longitude;

  @override
  State<NearbyServicesScreen> createState() => _NearbyServicesScreenState();
}

class _NearbyServicesScreenState extends State<NearbyServicesScreen> {
  static const String _darkMapStyle = r'''[
    {"elementType":"geometry","stylers":[{"color":"#0b090e"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#a9a0b5"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#0b090e"}]},
    {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#302a39"}]},
    {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#151119"}]},
    {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#9d91aa"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#211c27"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#131016"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#34254a"}]},
    {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#18131d"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#08070b"}]},
    {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#62586e"}]}
  ]''';
  final NearbyServiceService _nearbyServiceService =
      const NearbyServiceService();

  GoogleMapController? _mapController;

  List<NearbyService> _services = const [];

  bool _isLoading = true;

  String? _errorMessage;

  String? _selectedPlaceId;

  NearbyService? get _selectedService {
    final selectedPlaceId = _selectedPlaceId;

    if (selectedPlaceId == null) {
      return null;
    }

    for (final service in _services) {
      if (service.placeId == selectedPlaceId) {
        return service;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    _loadServices();
  }

  @override
  void dispose() {
    _mapController?.dispose();

    super.dispose();
  }

  Future<void> _loadServices() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final services = await _nearbyServiceService.getNearbyServices(
        widget.inspectionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Yakındaki servisler yüklenemedi. '
            'Lütfen tekrar deneyin.';
      });
    }
  }

  Set<Marker> get _markers {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('inspection-location'),
        position: LatLng(widget.latitude, widget.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        zIndexInt: 20,
      ),
    };

    for (final service in _services) {
      final isSelected = _selectedPlaceId == service.placeId;

      markers.add(
        Marker(
          markerId: MarkerId(service.placeId),
          position: LatLng(service.latitude, service.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected
                ? BitmapDescriptor.hueMagenta
                : BitmapDescriptor.hueViolet,
          ),
          zIndexInt: isSelected ? 10 : 1,
          alpha: isSelected ? 1 : 0.85,
          onTap: () => _focusService(service),
        ),
      );
    }

    return markers;
  }

  Set<Circle> get _selectionCircles {
    final service = _selectedService;

    if (service == null) {
      return const {};
    }

    return {
      Circle(
        circleId: CircleId('selected-${service.placeId}'),
        center: LatLng(service.latitude, service.longitude),
        radius: 35,
        fillColor: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
        strokeColor: const Color(0xFFC084FC).withValues(alpha: 0.78),
        strokeWidth: 2,
        zIndex: 2,
      ),
    };
  }

  Future<void> _focusService(NearbyService service) async {
    setState(() {
      _selectedPlaceId = service.placeId;
    });

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(service.latitude, service.longitude),
          zoom: 16,
        ),
      ),
    );
  }

  Future<void> _openDirections(NearbyService service) async {
    try {
      final locationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!locationServiceEnabled) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: AppText(
                'Yol tarifi için cihaz konumunu açmanız gerekiyor.',
              ),
            ),
          );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: AppText('Yol tarifi için konum izni gerekiyor.'),
            ),
          );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const AppText(
                'Konum izni kalıcı olarak kapatılmış. Ayarlardan izin vermelisiniz.',
              ),
              action: SnackBarAction(
                label: 'Ayarlar',
                onPressed: Geolocator.openAppSettings,
              ),
            ),
          );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final uri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': '${position.latitude},${position.longitude}',
        'destination': '${service.latitude},${service.longitude}',
        'travelmode': 'driving',
      });

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: AppText('Google Maps açılamadı.')),
          );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: AppText('Konum alınamadı veya yol tarifi açılamadı.'),
          ),
        );
    }
  }

  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();

      return '$meters m';
    }

    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String _formatRating(NearbyService service) {
    if (service.rating == null) {
      return 'Puan bilgisi yok';
    }

    final rating = service.rating!.toStringAsFixed(1);

    if (service.userRatingCount == null) {
      return '★ $rating';
    }

    return '★ $rating '
        '(${service.userRatingCount})';
  }

  @override
  Widget build(BuildContext context) {
    final selectedService = _selectedService;

    return Scaffold(
      appBar: AppBar(title: const AppText('Yakındaki Servisler')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.latitude, widget.longitude),
              zoom: 13,
            ),
            markers: _markers,
            circles: _selectionCircles,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            mapToolbarEnabled: false,
            onTap: (_) {
              if (_selectedPlaceId != null) {
                setState(() {
                  _selectedPlaceId = null;
                });
              }
            },
            style: _darkMapStyle,

            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
          ),
          if (_isLoading) const Positioned.fill(child: _LoadingOverlay()),
          if (!_isLoading && _errorMessage != null)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _ErrorCard(
                message: _errorMessage!,
                onRetry: _loadServices,
              ),
            ),
          if (!_isLoading && _errorMessage == null && _services.isEmpty)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _EmptyServicesCard(),
            ),
          if (!_isLoading && _errorMessage == null && selectedService != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _ServiceCard(
                service: selectedService,
                distance: _formatDistance(selectedService.distanceKm),
                rating: _formatRating(selectedService),
                onDirections: () => _openDirections(selectedService),
                onClose: () {
                  setState(() {
                    _selectedPlaceId = null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.distance,
    required this.rating,
    required this.onDirections,
    required this.onClose,
  });

  final NearbyService service;
  final String distance;
  final String rating;
  final VoidCallback onDirections;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.car_repair_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppText(
                    service.name.isEmpty ? 'Otomotiv Servisi' : service.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat'.tr,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppText(
              service.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                AppText(distance),
                const SizedBox(width: 16),
                Expanded(child: AppText(rating, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onDirections,
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const AppText('Yol Tarifi Al'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.70),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppText(
                message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const AppText('Tekrar Dene')),
          ],
        ),
      ),
    );
  }
}

class _EmptyServicesCard extends StatelessWidget {
  const _EmptyServicesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: AppText(
                'Bu araç ve hasar için '
                'yakında uygun servis bulunamadı.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
