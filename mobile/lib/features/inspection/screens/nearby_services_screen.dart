import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  final NearbyServiceService _nearbyServiceService =
      const NearbyServiceService();

  GoogleMapController? _mapController;

  List<NearbyService> _services = const [];

  bool _isLoading = true;

  String? _errorMessage;

  String? _selectedPlaceId;

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
        infoWindow: const InfoWindow(title: 'İnceleme Konumu'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };

    for (final service in _services) {
      markers.add(
        Marker(
          markerId: MarkerId(service.placeId),
          position: LatLng(service.latitude, service.longitude),
          infoWindow: InfoWindow(title: service.name, snippet: service.address),
          onTap: () {
            setState(() {
              _selectedPlaceId = service.placeId;
            });
          },
        ),
      );
    }

    return markers;
  }

  Future<void> _focusService(NearbyService service) async {
    setState(() {
      _selectedPlaceId = service.placeId;
    });

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(service.latitude, service.longitude),
          zoom: 15,
        ),
      ),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Yakındaki Servisler')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.latitude, widget.longitude),
              zoom: 13,
            ),
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
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
          if (!_isLoading && _services.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: SizedBox(
                height: 176,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _services.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final service = _services[index];

                    return _ServiceCard(
                      service: service,
                      selected: _selectedPlaceId == service.placeId,
                      distance: _formatDistance(service.distanceKm),
                      rating: _formatRating(service),
                      onTap: () => _focusService(service),
                    );
                  },
                ),
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
    required this.selected,
    required this.distance,
    required this.rating,
    required this.onTap,
  });

  final NearbyService service;
  final bool selected;
  final String distance;
  final String rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 290,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: selected ? 8 : 3,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
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
                      child: Text(
                        service.name.isEmpty
                            ? 'Otomotiv Servisi'
                            : service.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  service.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(distance),
                    const SizedBox(width: 16),
                    Text(rating),
                  ],
                ),
              ],
            ),
          ),
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
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
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
              child: Text(
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
