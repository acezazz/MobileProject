import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/user_providers.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(user.name),
                  subtitle: Text(
                    '@${user.username} • ${user.role} • ${user.isSuspended ? 'suspended' : user.status}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _onAction(context, ref, value, user),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit_account',
                        child: Text('Edit account'),
                      ),
                      if (!user.isSuspended)
                        const PopupMenuItem(
                          value: 'suspend',
                          child: Text('Suspend'),
                        ),
                      if (user.isSuspended)
                        const PopupMenuItem(
                          value: 'unsuspend',
                          child: Text('Unsuspend'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed: $error')),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    UserModel user,
  ) async {
    final actorId = ref.read(authStateProvider).valueOrNull?.uid;
    if (actorId == null) return;

    bool ok = false;
    final notifier = ref.read(adminUserActionProvider.notifier);

    if (action == 'edit_account') {
      final result = await _showEditAccountDialog(
        context: context,
        user: user,
        isSelf: actorId == user.uid,
      );
      if (result == null) return;

      ok = await notifier.updateAccount(
        targetUserId: user.uid,
        actorAdminId: actorId,
        isSuspended: result.isSuspended,
        suspensionType: result.suspensionType,
        suspensionUntil: result.suspensionUntil,
      );
    } else if (action == 'suspend') {
      ok = await notifier.suspendUser(
        targetUserId: user.uid,
        actorAdminId: actorId,
        reason: 'Policy violation',
      );
    } else if (action == 'unsuspend') {
      ok = await notifier.unsuspendUser(
        targetUserId: user.uid,
        actorAdminId: actorId,
      );
    }

    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(adminUsersProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Action applied')));
      return;
    }

    var message = 'Action failed.';
    final actionState = ref.read(adminUserActionProvider);
    actionState.whenOrNull(
      error: (error, _) {
        message = 'Action failed: $error';
      },
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_AdminAccountEditResult?> _showEditAccountDialog({
    required BuildContext context,
    required UserModel user,
    required bool isSelf,
  }) {
    bool isSuspended = user.isSuspended;
    String suspensionType = user.suspensionType == 'temporary'
        ? 'temporary'
        : (user.isSuspended ? 'permanent' : 'none');
    DateTime? suspensionUntil = user.suspensionUntil;

    return showDialog<_AdminAccountEditResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User: @${user.username}'),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: user.email,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: isSuspended,
                    title: const Text('Suspended'),
                    onChanged: (value) {
                      setState(() {
                        isSuspended = value;
                        if (!isSuspended) {
                          suspensionType = 'none';
                          suspensionUntil = null;
                        }
                      });
                    },
                  ),
                  if (isSuspended) ...[
                    DropdownButtonFormField<String>(
                      initialValue: suspensionType == 'none'
                          ? 'permanent'
                          : suspensionType,
                      decoration: const InputDecoration(
                        labelText: 'Suspension type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'permanent',
                          child: Text('permanent'),
                        ),
                        DropdownMenuItem(
                          value: 'temporary',
                          child: Text('temporary'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          suspensionType = value;
                          if (value != 'temporary') {
                            suspensionUntil = null;
                          }
                        });
                      },
                    ),
                    if (suspensionType == 'temporary')
                      TextButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: now,
                            initialDate:
                                suspensionUntil ??
                                now.add(const Duration(days: 7)),
                            lastDate: now.add(const Duration(days: 3650)),
                          );
                          if (picked == null) return;
                          setState(() => suspensionUntil = picked);
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          suspensionUntil == null
                              ? 'Set suspension end date'
                              : 'Until: ${suspensionUntil!.toLocal().toString().split(' ').first}',
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    _AdminAccountEditResult(
                      isSuspended: isSuspended,
                      suspensionType: isSuspended ? suspensionType : 'none',
                      suspensionUntil:
                          isSuspended && suspensionType == 'temporary'
                          ? suspensionUntil
                          : null,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminAccountEditResult {
  final bool isSuspended;
  final String suspensionType;
  final DateTime? suspensionUntil;

  const _AdminAccountEditResult({
    required this.isSuspended,
    required this.suspensionType,
    required this.suspensionUntil,
  });
}
