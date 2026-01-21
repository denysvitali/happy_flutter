import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/api/websocket_client.dart';
import '../../core/utils/utils.dart';

/// Sessions list screen
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final connectionStatus = ref.watch(connectionNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          ConnectionStatusBadge(status: connectionStatus),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showNewSessionDialog(context),
          ),
        ],
      ),
      body: sessions.isEmpty
          ? const EmptySessionsView()
          : RefreshIndicator(
              onRefresh: () => refreshSessions(ref),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions.values.elementAt(index);
                  return SessionCard(session: session);
                },
              ),
            ),
    );
  }

  Future<void> refreshSessions(WidgetRef ref) async {
    // Implement session refresh
  }

  void showNewSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NewSessionDialog(),
    );
  }
}

/// Session card widget
class SessionCard extends StatelessWidget {
  final Session session;

  const SessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          // Navigate to chat screen
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.metadata?.path ?? 'Unknown',
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (session.active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.computer,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    session.metadata?.host ?? 'Unknown',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatTimestamp(session.updatedAt, relative: true),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              if (session.thinking) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thinking...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty sessions view
class EmptySessionsView extends StatelessWidget {
  const EmptySessionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No sessions yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new session to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const NewSessionDialog(),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('New Session'),
          ),
        ],
      ),
    );
  }
}

/// Connection status badge
class ConnectionStatusBadge extends StatelessWidget {
  final ConnectionStatus status;

  const ConnectionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectionStatus.connected => Colors.green,
      ConnectionStatus.connecting => Colors.orange,
      ConnectionStatus.error => Colors.red,
      ConnectionStatus.disconnected => Colors.grey,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.circle, size: 12, color: color),
    );
  }
}

/// New session dialog
class NewSessionDialog extends StatefulWidget {
  const NewSessionDialog({super.key});

  @override
  State<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<NewSessionDialog> {
  String? _selectedPath;
  String? _selectedMachine;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Machine'),
            value: _selectedMachine,
            items: const [
              DropdownMenuItem(value: null, child: Text('Select machine')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedMachine = value;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Path',
              hintText: '/path/to/project',
            ),
            onChanged: (value) {
              setState(() {
                _selectedPath = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _selectedPath != null ? () => createSession(context) : null,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void createSession(BuildContext context) {
    // Implement session creation
    Navigator.pop(context);
  }
}
