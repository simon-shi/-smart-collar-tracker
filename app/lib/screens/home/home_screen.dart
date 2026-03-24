import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/pet_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/notification_provider.dart';
import '../../router/app_router.dart';
import '../../config/theme.dart';
import 'widgets/pet_status_card.dart';
import 'widgets/mini_map_widget.dart';
import 'widgets/activity_summary_widget.dart';
import 'widgets/alert_banner_widget.dart';
import 'home_drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPet = ref.watch(selectedPetProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.pets, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              selectedPet?.name ?? 'Smart Collar',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Notification badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Pet switcher
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => context.push(Routes.petSwitcher),
          ),
        ],
      ),
      drawer: const HomeDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(petListProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alert banner
              const AlertBannerWidget(),
              // Pet status card
              if (selectedPet != null) PetStatusCard(pet: selectedPet),
              const SizedBox(height: 16),
              // Mini map
              MiniMapWidget(onTap: () => context.push(Routes.liveMap)),
              const SizedBox(height: 16),
              // Activity summary
              ActivitySummaryWidget(
                onTap: () => context.push(Routes.activity),
              ),
              const SizedBox(height: 16),
              // Quick actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _QuickActionButton(
                    icon: Icons.location_searching,
                    label: 'Find Pet',
                    onTap: () => context.push(Routes.findPet),
                  ),
                  _QuickActionButton(
                    icon: Icons.fence,
                    label: 'Geofences',
                    onTap: () => context.push(Routes.geofenceList),
                  ),
                  _QuickActionButton(
                    icon: Icons.directions_run,
                    label: 'Activity',
                    onTap: () => context.push(Routes.activity),
                  ),
                  _QuickActionButton(
                    icon: Icons.health_and_safety,
                    label: 'Health',
                    onTap: () => context.push(Routes.health),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.liveMap),
        icon: const Icon(Icons.map),
        label: const Text('Live Map'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
