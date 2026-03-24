import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_collar_tracker/screens/home/widgets/pet_status_card.dart';
import 'package:smart_collar_tracker/models/pet.dart';
import 'package:smart_collar_tracker/models/device.dart';
import 'package:smart_collar_tracker/models/location.dart';
import 'package:smart_collar_tracker/providers/device_provider.dart';
import 'package:smart_collar_tracker/providers/location_provider.dart';
import 'package:smart_collar_tracker/config/theme.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Pet _makePet({
  String id = 'pet_1',
  String name = 'Buddy',
  String breed = 'Labrador',
}) {
  return Pet(
    id: id,
    ownerId: 'owner_1',
    name: name,
    breed: breed,
    species: 'dog',
    weight: 25.0,
    birthDate: DateTime(2020, 6, 15),
    createdAt: DateTime(2022, 1, 1),
    updatedAt: DateTime(2022, 1, 1),
  );
}

CollarDevice _makeDevice({bool connected = true, int battery = 80}) {
  return CollarDevice(
    id: 'device_1',
    petId: 'pet_1',
    name: 'PetCollar-001',
    firmwareVersion: '1.0.0',
    hardwareVersion: '1.0',
    batteryLevel: battery,
    isConnected: connected,
    createdAt: DateTime(2022, 1, 1),
    updatedAt: DateTime(2022, 1, 1),
  );
}

PetLocation _makeLocation() {
  return PetLocation(
    id: 'loc_1',
    petId: 'pet_1',
    latitude: 37.7749,
    longitude: -122.4194,
    timestamp: DateTime.now(),
    source: LocationSource.gps,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PetStatusCard', () {
    testWidgets('renders pet name and breed', (tester) async {
      final pet = _makePet();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProvider.overrideWith(
              (ref) => AsyncValue.data(_makeDevice()),
            ),
            selectedPetLocationProvider.overrideWith(
              (ref) => AsyncValue.data(_makeLocation()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: PetStatusCard(pet: pet)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Buddy'), findsOneWidget);
      expect(find.textContaining('Labrador'), findsOneWidget);
    });

    testWidgets('shows Online status when connected', (tester) async {
      final pet = _makePet();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProvider.overrideWith(
              (ref) => AsyncValue.data(_makeDevice(connected: true)),
            ),
            selectedPetLocationProvider.overrideWith(
              (ref) => AsyncValue.data(_makeLocation()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: PetStatusCard(pet: pet)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('shows Offline status when disconnected', (tester) async {
      final pet = _makePet();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProvider.overrideWith(
              (ref) => AsyncValue.data(_makeDevice(connected: false)),
            ),
            selectedPetLocationProvider.overrideWith(
              (ref) => AsyncValue.data(null),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: PetStatusCard(pet: pet)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('shows battery percentage from device', (tester) async {
      final pet = _makePet();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProvider.overrideWith(
              (ref) => AsyncValue.data(_makeDevice(battery: 65)),
            ),
            selectedPetLocationProvider.overrideWith(
              (ref) => AsyncValue.data(_makeLocation()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: PetStatusCard(pet: pet)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('65%'), findsOneWidget);
    });

    testWidgets('shows -- for battery when device data is null', (tester) async {
      final pet = _makePet();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProvider.overrideWith(
              (ref) => const AsyncValue.data(null),
            ),
            selectedPetLocationProvider.overrideWith(
              (ref) => const AsyncValue.data(null),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: PetStatusCard(pet: pet)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('--'), findsWidgets);
    });

    testWidgets('renders pet avatar icon when no photo URL', (tester) async {
      final pet = _makePet();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProvider.overrideWith(
              (ref) => const AsyncValue.data(null),
            ),
            selectedPetLocationProvider.overrideWith(
              (ref) => const AsyncValue.data(null),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: PetStatusCard(pet: pet)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.pets), findsOneWidget);
    });
  });
}
