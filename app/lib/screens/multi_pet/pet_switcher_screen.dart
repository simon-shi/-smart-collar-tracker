import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/pet_provider.dart';
import '../../models/pet.dart';
import '../../config/theme.dart';
import '../../widgets/common/empty_state.dart';

class PetSwitcherScreen extends ConsumerWidget {
  const PetSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petListProvider);
    final selectedPetId = ref.watch(selectedPetIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Pets')),
      body: petsAsync.when(
        data: (pets) {
          if (pets.isEmpty) {
            return EmptyState(
              title: 'No Pets Yet',
              subtitle: 'Add your first pet to get started',
              icon: Icons.pets,
              action: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.add),
                label: const Text('Add Pet'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pets.length,
            itemBuilder: (context, index) {
              final pet = pets[index];
              final isSelected = pet.id == selectedPetId;
              return _PetCard(
                pet: pet,
                isSelected: isSelected,
                onTap: () {
                  ref.read(selectedPetIdProvider.notifier).state = pet.id;
                  Navigator.of(context).pop();
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pop();
          // Navigate to add pet
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Pet'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet pet;
  final bool isSelected;
  final VoidCallback onTap;

  const _PetCard({
    required this.pet,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage:
              pet.photoUrl != null ? NetworkImage(pet.photoUrl!) : null,
          child: pet.photoUrl == null
              ? const Icon(Icons.pets, color: AppColors.primary)
              : null,
        ),
        title: Text(
          pet.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          pet.breed.isNotEmpty
              ? '${pet.breed} · ${pet.ageDisplay}'
              : pet.ageDisplay,
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      ),
    );
  }
}
