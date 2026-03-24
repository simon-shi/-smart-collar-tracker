import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/pet_provider.dart';
import '../../models/pet.dart';
import '../../router/app_router.dart';
import '../../utils/validators.dart';
import '../../widgets/common/loading_overlay.dart';

class AddPetScreen extends ConsumerStatefulWidget {
  const AddPetScreen({super.key});

  @override
  ConsumerState<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends ConsumerState<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  PetType _petType = PetType.dog;
  PetGender _gender = PetGender.unknown;
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 365));
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final petData = {
      'name': _nameController.text.trim(),
      'type': _petType.name,
      'breed': _breedController.text.trim(),
      'gender': _gender.name,
      'birthDate': _birthDate.toIso8601String(),
      'weightKg': double.parse(_weightController.text.trim()),
    };

    final pet = await ref.read(petListProvider.notifier).createPet(petData);
    if (mounted) {
      setState(() => _isLoading = false);
      if (pet != null) {
        context.go(Routes.home);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add pet. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Your Pet'),
          actions: [
            TextButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Skip'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pet type
                  Text('Pet Type',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _PetTypeButton(
                        type: PetType.dog,
                        selected: _petType == PetType.dog,
                        onTap: () => setState(() => _petType = PetType.dog),
                      ),
                      const SizedBox(width: 12),
                      _PetTypeButton(
                        type: PetType.cat,
                        selected: _petType == PetType.cat,
                        onTap: () => setState(() => _petType = PetType.cat),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Name
                  TextFormField(
                    controller: _nameController,
                    validator: Validators.petName,
                    decoration: const InputDecoration(
                      labelText: 'Pet Name *',
                      prefixIcon: Icon(Icons.pets),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Breed
                  TextFormField(
                    controller: _breedController,
                    decoration: const InputDecoration(
                      labelText: 'Breed',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Weight
                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    validator: Validators.weight,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg) *',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Gender
                  Text('Gender', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<PetGender>(
                    segments: const [
                      ButtonSegment(
                        value: PetGender.male,
                        label: Text('Male'),
                        icon: Icon(Icons.male),
                      ),
                      ButtonSegment(
                        value: PetGender.female,
                        label: Text('Female'),
                        icon: Icon(Icons.female),
                      ),
                      ButtonSegment(
                        value: PetGender.unknown,
                        label: Text('Unknown'),
                      ),
                    ],
                    selected: {_gender},
                    onSelectionChanged: (v) =>
                        setState(() => _gender = v.first),
                  ),
                  const SizedBox(height: 16),
                  // Birth date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cake_outlined),
                    title: const Text('Birth Date'),
                    subtitle: Text(
                      '${_birthDate.year}-${_birthDate.month.toString().padLeft(2, '0')}-${_birthDate.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _birthDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _birthDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Add Pet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PetTypeButton extends StatelessWidget {
  final PetType type;
  final bool selected;
  final VoidCallback onTap;

  const _PetTypeButton({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isdog = type == PetType.dog;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Column(
            children: [
              Icon(
                isdog ? Icons.pets : Icons.set_meal,
                size: 32,
                color: selected ? Colors.white : null,
              ),
              const SizedBox(height: 4),
              Text(
                isdog ? 'Dog' : 'Cat',
                style: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
