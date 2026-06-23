import 'package:flutter/material.dart';

import '../models/device_session.dart';
import '../ui/app_theme.dart';
import '../widgets/app_logo.dart';

class ProfilePage extends StatelessWidget {
  final DeviceSession session;

  const ProfilePage({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
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
                  const Center(child: AppLogo(size: 72)),
                  const SizedBox(height: 20),
                  Text(
                    session.deviceName.isEmpty
                        ? "Device Profile"
                        : session.deviceName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Terminal ${session.terminalId.isEmpty ? "-" : session.terminalId}",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileRow(
                            label: "Enterprise",
                            value: session.enterpriseCode,
                          ),
                          _ProfileRow(
                            label: "Enterprise Name",
                            value: session.enterpriseName,
                          ),
                          _ProfileRow(label: "Role", value: session.role),
                          _ProfileRow(
                            label: "Terminal ID",
                            value: session.terminalId,
                          ),
                          _ProfileRow(
                            label: "Device Name",
                            value: session.deviceName,
                          ),
                          _ProfileRow(
                            label: "Device ID",
                            value: session.deviceIdentifier,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
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

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _ProfileRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? "-" : value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
