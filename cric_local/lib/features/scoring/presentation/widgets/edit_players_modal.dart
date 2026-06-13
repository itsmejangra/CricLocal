import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/theme.dart';
import '../../../match/data/models/models.dart';
import '../../../match/presentation/bloc/scoring_bloc.dart';
import '../../../match/presentation/bloc/scoring_event_state.dart';

void showEditPlayersModal(BuildContext context, ScoringBloc bloc) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return BlocProvider.value(
        value: bloc,
        child: const EditPlayersModal(),
      );
    },
  );
}

class EditPlayersModal extends StatefulWidget {
  const EditPlayersModal({super.key});

  @override
  State<EditPlayersModal> createState() => _EditPlayersModalState();
}

class _EditPlayersModalState extends State<EditPlayersModal> with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScoringBloc, ScoringState>(
      builder: (context, state) {
        List<PlayerModel> players = [];
        String team1Name = '';
        String team2Name = '';

        if (state is ScoringActive) {
          players = state.allPlayers;
          team1Name = state.match.team1Name;
          team2Name = state.match.team2Name;
        } else if (state is InningsBreak) {
          players = state.allPlayers;
          team1Name = state.match.team1Name;
          team2Name = state.match.team2Name;
        } else if (state is MatchLoaded) {
          players = state.allPlayers;
          team1Name = state.match.team1Name;
          team2Name = state.match.team2Name;
        } else {
          return const Center(child: CircularProgressIndicator());
        }

        final team1Players = players.where((p) => p.teamName == team1Name).toList();
        final team2Players = players.where((p) => p.teamName == team2Name).toList();

        _tabController ??= TabController(length: 2, vsync: this);

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Manage Players',
                      style: AppTheme.headlineMedium.copyWith(fontSize: 22),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryRed,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryRed,
                tabs: [
                  Tab(text: team1Name),
                  Tab(text: team2Name),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPlayerList(context, team1Players),
                    _buildPlayerList(context, team2Players),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerList(BuildContext context, List<PlayerModel> players) {
    if (players.isEmpty) {
      return const Center(
        child: Text('No players added to this team yet.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: players.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final player = players[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            player.name,
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: player.isCaptain || player.isKeeper
              ? Text(
                  [
                    if (player.isCaptain) 'Captain',
                    if (player.isKeeper) 'Wicketkeeper'
                  ].join(' & '),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.accentTeal),
                )
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryRed),
            onPressed: () => _showRenameDialog(context, player),
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, PlayerModel player) {
    final controller = TextEditingController(text: player.name);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Player'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Player Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty && newName != player.name) {
                  context.read<ScoringBloc>().add(
                        RenamePlayer(playerId: player.id, newName: newName),
                      );
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('SAVE', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
