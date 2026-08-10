import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';

import '../../data/models/models.dart';

import '../bloc/scoring_bloc.dart';
import '../bloc/scoring_event_state.dart';
import '../widgets/live_tab.dart';
import '../widgets/scorecard_tab.dart';
import '../widgets/insights_tab.dart';
import '../widgets/commentary_tab.dart';
import '../widgets/mvp_tab.dart';
import '../widgets/match_result_tab.dart';

class MatchDetailPage extends StatefulWidget {
  final String matchId;
  final int initialTabIndex;
  const MatchDetailPage({super.key, required this.matchId, this.initialTabIndex = 2});
  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> with SingleTickerProviderStateMixin {
  late final ScoringBloc _bloc;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ScoringBloc>()..add(LoadMatch(widget.matchId));
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 5),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _bloc.close();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<ScoringBloc, ScoringState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: AppTheme.wicketRed,
              foregroundColor: Colors.white,
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
              title: const Text('Individual match'),
              actions: [
                IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            ),
            body: Column(
              children: [
                Material(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppTheme.textPrimary,
                    unselectedLabelColor: AppTheme.textHint,
                    indicatorColor: AppTheme.wicketRed,
                    indicatorWeight: 3,
                    dividerColor: AppTheme.cardBorder,
                    tabs: [
                      const Tab(text: 'Summary'),
                      const Tab(text: 'Scorecard'),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Insights'),
                            if (_tabController.index == 2) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppTheme.wicketRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Tab(text: 'Comms'),
                      const Tab(text: 'Squads'),
                      const Tab(text: 'MVP'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      state is MatchCompleted
                          ? MatchResultTab(state: state)
                          : LiveTab(state: state, matchId: widget.matchId),
                      ScorecardTab(state: state),
                      InsightsTab(state: state),
                      CommentaryTab(state: state, matchId: widget.matchId),
                      _buildSquadsTab(state),
                      MvpTab(state: state),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSquadsTab(ScoringState state) {
    List<PlayerModel> players = [];
    MatchModel? match;

    if (state is MatchLoaded) {
      players = state.allPlayers;
      match = state.match;
    } else if (state is ScoringActive) {
      players = state.allPlayers;
      match = state.match;
    } else if (state is InningsBreak) {
      players = state.allPlayers;
      match = state.match;
    } else if (state is MatchCompleted) {
      players = state.allPlayers;
      match = state.match;
    }

    if (match == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final team1Players = players.where((p) => p.teamName == match!.team1Name).toList();
    final team2Players = players.where((p) => p.teamName == match!.team2Name).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(match.team1Name, style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...team1Players.map((p) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(p.name),
            )),
        const SizedBox(height: 24),
        Text(match.team2Name, style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...team2Players.map((p) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(p.name),
            )),
        if (players.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: Text('No squad data available yet.', style: TextStyle(color: AppTheme.textSecondary))),
          ),
      ],
    );
  }
}
