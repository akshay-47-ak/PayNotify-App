import 'package:flutter/material.dart';

import '../models/device_session.dart';
import '../ui/app_theme.dart';
import '../widgets/app_logo.dart';

class MainScreen extends StatelessWidget {
  final DeviceSession session;
  final VoidCallback onOpenQr;
  final VoidCallback onOpenProfile;
  final VoidCallback onLogout;

  const MainScreen({
    super.key,
    required this.session,
    required this.onOpenQr,
    required this.onOpenProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PayNotify"),
        actions: [
          IconButton(
            tooltip: "Logout",
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppLayout.pagePadding(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 80)),
                  const SizedBox(height: 20),
                  Text(
                    "Welcome, ${session.deviceName.isEmpty ? "Device" : session.deviceName}",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.enterpriseName.isEmpty
                        ? session.enterpriseCode
                        : session.enterpriseName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _ActionCard(
                    icon: Icons.qr_code_2,
                    title: "QR Display",
                    subtitle: "Open the live QR payment screen.",
                    onTap: onOpenQr,
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.account_circle,
                    title: "Profile",
                    subtitle: "View enterprise, terminal, and device details.",
                    onTap: onOpenProfile,
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
