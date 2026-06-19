import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cric_local/app/theme.dart';
import 'package:cric_local/app/di.dart';
import 'package:cric_local/core/enums.dart';
import 'package:cric_local/features/match/data/models/models.dart';
import 'package:cric_local/features/match/data/repositories/match_repository.dart';
import 'package:cric_local/core/services/sync_service.dart';

class GlobalSearchDelegate extends SearchDelegate {
  final List<MatchModel> localMatches;
  final List<MatchModel> liveMatches;

  GlobalSearchDelegate({
    required this.localMatches,
    required this.liveMatches,
  });

  @override
  String get searchFieldLabel => 'Search players, teams, matches...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildSuggestionsList();
    }
    return _buildSearchResults();
  }

  Widget _buildSuggestionsList() {
    // Show some recent or default suggestions
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Suggested searches', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        ),
        _suggestionTile('Live Matches', Icons.live_tv),
        _suggestionTile('Recent Players', Icons.person),
        _suggestionTile('Teams', Icons.groups),
      ],
    );
  }

  Widget _suggestionTile(String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accentTeal),
      title: Text(label),
      onTap: () {
        query = label;
        showResults(null as dynamic); // Trigger search
      },
    );
  }

  Widget _buildSearchResults() {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return const SizedBox.shrink();

    return FutureBuilder(
      future: _performSearch(lowerQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final results = snapshot.data as Map<String, List<dynamic>>;
        final matches = results['matches'] as List<MatchModel>;
        final players = results['players'] as List<PlayerModel>;
        final teams = results['teams'] as List<String>;

        if (matches.isEmpty && players.isEmpty && teams.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: AppTheme.textHint),
                const SizedBox(height: 16),
                Text('No results found for "$query"', style: AppTheme.bodyMedium),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (matches.isNotEmpty) ...[
              _buildSectionHeader('Matches'),
              ...matches.map((m) => _matchTile(context, m)),
            ],
            if (teams.isNotEmpty) ...[
              _buildSectionHeader('Teams'),
              ...teams.map((t) => _teamTile(context, t)),
            ],
            if (players.isNotEmpty) ...[
              _buildSectionHeader('Players'),
              ...players.map((p) => _playerTile(context, p)),
            ],
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title.toUpperCase(), 
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal, letterSpacing: 1)),
    );
  }

  Widget _matchTile(BuildContext context, MatchModel m) {
    bool isLive = m.status == MatchStatus.live;
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: isLive ? AppTheme.liveBadge : AppTheme.backgroundGray,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.sports_cricket, size: 20, color: isLive ? Colors.white : AppTheme.textSecondary),
      ),
      title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${m.team1Name} vs ${m.team2Name} • ${m.venue ?? "Unknown Venue"}', style: AppTheme.bodySmall),
      trailing: isLive 
          ? Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppTheme.liveBadge, borderRadius: BorderRadius.circular(4)), child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
          : const Icon(Icons.chevron_right),
      onTap: () {
        final isLocal = localMatches.any((lm) => lm.id == m.id);
        if (isLocal) {
          context.push('/match/${m.id}');
        } else {
          context.push('/live/${m.id}');
        }
      },
    );
  }

  Widget _teamTile(BuildContext context, String teamName) {
    return ListTile(
      leading: const CircleAvatar(radius: 20, backgroundColor: AppTheme.primaryBlue, child: Icon(Icons.groups, color: Colors.white, size: 20)),
      title: Text(teamName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Team', style: AppTheme.bodySmall),
      onTap: () {
        query = teamName;
        showResults(null as dynamic);
      },
    );
  }

  Widget _playerTile(BuildContext context, PlayerModel p) {
    return ListTile(
      leading: const CircleAvatar(radius: 20, backgroundColor: AppTheme.accentTealLight, child: Icon(Icons.person, color: AppTheme.accentTeal, size: 20)),
      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Plays for ${p.teamName}', style: AppTheme.bodySmall),
      onTap: () {
        // Find existing match for this player to show stats or something
        context.push('/live/${p.matchId}');
      },
    );
  }

  Future<Map<String, List<dynamic>>> _performSearch(String q) async {
    final repo = getIt<MatchRepository>();
    
    // 1. Filter matches
    final allMatches = [...localMatches, ...liveMatches];
    final matchedMatches = allMatches.where((MatchModel m) => 
      m.title.toLowerCase().contains(q) || 
      m.team1Name.toLowerCase().contains(q) || 
      m.team2Name.toLowerCase().contains(q) ||
      (m.venue?.toLowerCase().contains(q) ?? false)
    ).toList();

    // 2. Extract teams
    final matchedTeams = <String>{};
    for (var m in allMatches) {
      if (m.team1Name.toLowerCase().contains(q)) matchedTeams.add(m.team1Name);
      if (m.team2Name.toLowerCase().contains(q)) matchedTeams.add(m.team2Name);
    }

    // 3. Search Players from local DB
    final players = await repo.searchPlayers(q);

    return {
      'matches': matchedMatches,
      'teams': matchedTeams.toList(),
      'players': players,
    };
  }
}
