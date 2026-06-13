import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/match_repository.dart';

/// Manage saved teams for quick match setup.
class SavedTeamsPage extends StatefulWidget {
  const SavedTeamsPage({super.key});

  @override
  State<SavedTeamsPage> createState() => _SavedTeamsPageState();
}

class _SavedTeamsPageState extends State<SavedTeamsPage> {
  final _repository = getIt<MatchRepository>();
  List<SavedTeam> _teams = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _syncTeamsWithCloud() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      // First, push any local ones to ensure they are on cloud
      await _repository.pushAllSavedTeamsToCloud();
      // Then pull from cloud
      final importedCount = await _repository.pullSavedTeamsFromCloud();
      _showSuccess(importedCount > 0 
          ? 'Sync complete! Imported $importedCount team(s) from cloud.'
          : 'Sync complete! All teams are up to date.');
      await _loadTeams();
    } catch (e) {
      _showError('Sync failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }


  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    try {
      final teams = await _repository.getAllSavedTeams();
      setState(() {
        _teams = teams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading teams: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentTeal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  void _confirmDeleteTeam(SavedTeam team) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Saved Team?'),
        content: Text('Are you sure you want to delete "${team.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.deleteSavedTeam(team.id);
                _showSuccess('Team "${team.name}" deleted successfully.');
                _loadTeams();
              } catch (e) {
                _showError('Failed to delete team: $e');
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openTeamForm({SavedTeam? teamToEdit}) async {
    final nameCtrl = TextEditingController(text: teamToEdit?.name ?? '');
    final playerCtrls = List.generate(
      11,
      (_) => TextEditingController(),
    );

    if (teamToEdit != null) {
      final existingPlayers = await _repository.getSavedTeamPlayers(teamToEdit.id);
      for (int i = 0; i < playerCtrls.length; i++) {
        if (i < existingPlayers.length) {
          playerCtrls[i].text = existingPlayers[i].name;
        }
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sheet header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: AppTheme.accentTeal,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        teamToEdit == null ? 'Create Saved Team' : 'Edit Saved Team',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Team Name',
                            hintText: 'e.g. Bhaga XI',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.groups),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Icon(Icons.person_outline, color: AppTheme.accentTeal),
                            SizedBox(width: 8),
                            Text(
                              'Players (Min 2, Max 11)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Provide at least 2 player names. Empty fields are ignored.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: playerCtrls.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: TextFormField(
                                controller: playerCtrls[index],
                                decoration: InputDecoration(
                                  labelText: 'Player ${index + 1}',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Sheet actions
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final teamName = nameCtrl.text.trim();
                      if (teamName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a team name.')),
                        );
                        return;
                      }

                      final players = playerCtrls
                          .map((c) => c.text.trim())
                          .where((name) => name.isNotEmpty)
                          .toList();

                      if (players.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('A team must have at least 2 players.')),
                        );
                        return;
                      }

                      try {
                        if (teamToEdit == null) {
                          await _repository.createSavedTeam(
                            name: teamName,
                            playerNames: players,
                          );
                          _showSuccess('Team "$teamName" created successfully!');
                        } else {
                          await _repository.updateSavedTeam(
                            teamId: teamToEdit.id,
                            name: teamName,
                            playerNames: players,
                          );
                          _showSuccess('Team "$teamName" updated successfully!');
                        }
                        Navigator.pop(context);
                        _loadTeams();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save team: $e')),
                        );
                      }
                    },
                    child: Text(
                      teamToEdit == null ? 'CREATE TEAM ✓' : 'SAVE CHANGES ✓',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Teams'),
        actions: [
          _isSyncing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sync Teams with Cloud',
                  onPressed: _syncTeamsWithCloud,
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _teams.isEmpty
              ? _buildEmptyState()
              : _buildTeamsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTeamForm(),
        backgroundColor: AppTheme.accentTeal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 80,
                color: AppTheme.accentTeal,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Saved Teams Yet',
              style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Create teams with player rosters to quickly start matches and auto-fill rosters later.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _openTeamForm(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('ADD TEAM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teams.length,
      itemBuilder: (context, index) {
        final team = _teams[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.accentTeal.withValues(alpha: 0.1),
              child: const Icon(Icons.shield, color: AppTheme.accentTeal),
            ),
            title: Text(
              team.name,
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: FutureBuilder<List<SavedTeamPlayer>>(
              future: _repository.getSavedTeamPlayers(team.id),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Text(
                  '$count players • Updated ${_formatDate(team.updatedAt)}',
                  style: AppTheme.bodySmall,
                );
              },
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: AppTheme.accentTeal, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
              onSelected: (val) {
                if (val == 'edit') {
                  _openTeamForm(teamToEdit: team);
                } else if (val == 'delete') {
                  _confirmDeleteTeam(team);
                }
              },
            ),
            children: [
              const Divider(),
              FutureBuilder<List<SavedTeamPlayer>>(
                future: _repository.getSavedTeamPlayers(team.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No players in this team'),
                    );
                  }
                  final players = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey[200],
                          child: Text(
                            '${player.orderIndex}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        ),
                        title: Text(
                          player.name,
                          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                        ),
                        trailing: Icon(
                          Icons.bar_chart_outlined,
                          size: 18,
                          color: AppTheme.accentTeal.withValues(alpha: 0.7),
                        ),
                        onTap: () => context.push('/player/stats/${Uri.encodeComponent(player.name)}'),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
