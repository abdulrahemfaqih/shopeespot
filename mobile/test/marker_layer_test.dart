import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/widgets/category_marker.dart';
import 'package:shopeespot/features/map/domain/clustering.dart';
import 'package:shopeespot/features/map/presentation/widgets/spot_markers_layer.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';

void main() {
  group('Clustering domain logic', () {
    final now = DateTime.utc(2026, 10, 4, 10, 0);

    test('excludes deleted spots and spots outside bounding box', () {
      final spots = [
        Spot(
          id: 'spot-in',
          name: 'Inside Spot',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
          createdAt: now,
          updatedAt: now,
        ),
        Spot(
          id: 'spot-deleted',
          name: 'Deleted Spot',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
          deletedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        Spot(
          id: 'spot-outside',
          name: 'Outside Spot',
          category: Category.shopeefood,
          latitude: -7.5,
          longitude: 110.0,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final clusters = computeMapClusters(
        spots: spots,
        minLat: -6.3,
        maxLat: -6.1,
        minLng: 106.7,
        maxLng: 106.9,
        zoom: 16.0,
      );

      expect(clusters.length, 1);
      expect(clusters.first.spot?.id, 'spot-in');
      expect(clusters.first.isCluster, false);
    });

    test('no clustering at zoom >= 15', () {
      final spots = [
        Spot(
          id: 'spot-1',
          name: 'Spot 1',
          category: Category.shopeefood,
          latitude: -6.2001,
          longitude: 106.8001,
          createdAt: now,
          updatedAt: now,
        ),
        Spot(
          id: 'spot-2',
          name: 'Spot 2',
          category: Category.spx,
          latitude: -6.2002,
          longitude: 106.8002,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final clusters = computeMapClusters(
        spots: spots,
        minLat: -6.3,
        maxLat: -6.1,
        minLng: 106.7,
        maxLng: 106.9,
        zoom: 15.0,
      );

      expect(clusters.length, 2);
      expect(clusters.every((c) => !c.isCluster), true);
    });

    test('clusters nearby spots at zoom < 15', () {
      final spots = [
        Spot(
          id: 'spot-1',
          name: 'Spot 1',
          category: Category.shopeefood,
          latitude: -6.2001,
          longitude: 106.8001,
          createdAt: now,
          updatedAt: now,
        ),
        Spot(
          id: 'spot-2',
          name: 'Spot 2',
          category: Category.spx,
          latitude: -6.2002,
          longitude: 106.8002,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final clusters = computeMapClusters(
        spots: spots,
        minLat: -6.3,
        maxLat: -6.1,
        minLng: 106.7,
        maxLng: 106.9,
        zoom: 12.0,
      );

      expect(clusters.length, 1);
      expect(clusters.first.isCluster, true);
      expect(clusters.first.count, 2);
      expect(clusters.first.spotIds, containsAll(['spot-1', 'spot-2']));
    });

    test(
      'single unmerged spot keeps exact original coordinates (pure function)',
      () {
        final singleSpot = Spot(
          id: 'spot-orig',
          name: 'Spot Original',
          category: Category.shopeefood,
          latitude: -6.208812,
          longitude: 106.845634,
          createdAt: now,
          updatedAt: now,
        );

        final clusters = computeMapClusters(
          spots: [singleSpot],
          minLat: -6.3,
          maxLat: -6.1,
          minLng: 106.7,
          maxLng: 106.9,
          zoom: 12.0,
        );

        expect(clusters.length, 1);
        final item = clusters.first;
        expect(item.isCluster, false);
        expect(item.count, 1);
        expect(item.spot?.id, 'spot-orig');
        expect(item.latitude, equals(-6.208812));
        expect(item.longitude, equals(106.845634));
      },
    );

    test('performance test with 2,000 seeded spots', () {
      final rng = Random(42);
      final seedSpots = List.generate(2000, (i) {
        return Spot(
          id: 'seed-spot-$i',
          name: 'Warung Nasi $i',
          category: i % 3 == 0 ? Category.spx : Category.shopeefood,
          latitude: -6.2 + (rng.nextDouble() - 0.5) * 0.1,
          longitude: 106.8 + (rng.nextDouble() - 0.5) * 0.1,
          createdAt: now,
          updatedAt: now,
        );
      });

      final stopwatch = Stopwatch()..start();
      final clusters = computeMapClusters(
        spots: seedSpots,
        minLat: -6.3,
        maxLat: -6.1,
        minLng: 106.7,
        maxLng: 106.9,
        zoom: 13.0,
      );
      stopwatch.stop();

      expect(clusters, isNotEmpty);
      // Execution must be fast (< 30 ms) to guarantee 60 fps
      expect(stopwatch.elapsedMilliseconds, lessThan(30));
    });
  });

  group('CategoryMarker widget', () {
    testWidgets('renders ShopeeFood and SPX icons correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Column(
              children: [
                CategoryMarker(
                  category: Category.shopeefood,
                  name: 'Resto Enak',
                  showLabel: true,
                ),
                CategoryMarker(
                  category: Category.spx,
                  name: 'SPX Hub',
                  showLabel: false,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      expect(find.text('Resto Enak'), findsOneWidget);
      expect(find.text('SPX Hub'), findsNothing); // showLabel is false
    });
  });

  group('SpotMarkersLayer widget', () {
    testWidgets('renders inside FlutterMap without error', (tester) async {
      final now = DateTime.utc(2026, 10, 4, 10, 0);
      final spots = [
        Spot(
          id: 'spot-1',
          name: 'Warung A',
          category: Category.shopeefood,
          latitude: -6.2088,
          longitude: 106.8456,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      late MapCamera capturedCamera;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(-6.2088, 106.8456),
                initialZoom: 16.0,
                onMapReady: () {},
              ),
              children: [
                Builder(
                  builder: (context) {
                    capturedCamera = MapCamera.of(context);
                    return SpotMarkersLayer(
                      spots: spots,
                      camera: capturedCamera,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CategoryMarker), findsOneWidget);
      expect(find.text('Warung A'), findsOneWidget);
    });

    testWidgets('marker bottom tip anchors at spot coordinate', (tester) async {
      final now = DateTime.utc(2026, 10, 4, 10, 0);
      const coord = LatLng(-6.2088, 106.8456);
      final spots = [
        Spot(
          id: 'spot-1',
          name: 'Warung A',
          category: Category.shopeefood,
          latitude: coord.latitude,
          longitude: coord.longitude,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FlutterMap(
              options: const MapOptions(
                initialCenter: coord,
                initialZoom: 16.0,
              ),
              children: [
                Builder(
                  builder: (context) => SpotMarkersLayer(
                    spots: spots,
                    camera: MapCamera.of(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      final mapCenter = tester.getCenter(find.byType(FlutterMap));
      final markerRect = tester.getRect(find.byType(CategoryMarker));
      expect(markerRect.bottomCenter, equals(mapCenter));
    });
  });
}
