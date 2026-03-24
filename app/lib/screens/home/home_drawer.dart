import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/pet_provider.dart';
import '../../router/app_router.dart';
import '../../config/theme.dart';

class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final pets = ref.watch(petListProvider).valueOrNull ?? [];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // User header
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              accountName: Text(user?.displayName ?? 'Pet Owner'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: user?.photoUrl != null
                    ? NetworkImage(user!.photoUrl!)
                    : null,
                child: user?.photoUrl == null
                    ? const Icon(Icons.person, color: AppColors.primary)
                    : null,
              ),
            ),
            // Navigation items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    title: 'Home',
                    onTap: () {
                      Navigator.pop(context);
                      context.go(Routes.home);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.map_outlined,
                    title: 'Live Map',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(Routes.liveMap);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.fence_outlined,
                    title: 'Geofences',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(Routes.geofenceList);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.directions_run,
                    title: 'Activity',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(Routes.activity);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Health',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(Routes.health);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.location_searching,
                    title: 'Find Pet',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(Routes.findPet);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.devices_outlined,
                    title: 'Device',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(Routes.device);
                    },
                  ),
                  const Divider(),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(Routes.settings);
                    },
                  ),
                ],
              ),
            ),
            // Logout
            const Divider(),
            _DrawerItem(
              icon: Icons.logout,
              title: 'Sign Out',
              color: AppColors.error,
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go(Routes.login);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: color != null ? TextStyle(color: color) : null,
      ),
      onTap: onTap,
      dense: true,
    );
  }
}
