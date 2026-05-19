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
import '../widgets/match_result_tab.dart';

class MatchDetailPage extends StatefulWidget {
  final String matchId;
  const MatchDetailPage({super.key, required this.matchId});
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
    _tabController = TabController(length: 5, vsync: this, initialIndex: 1);
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
            appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
              title: const Text('Individual match'),
              actions: [
                IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
              bottom: TabBar(controller: _tabController, isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppTheme.primaryRed, unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primaryRed,
                tabs: [
                  const Tab(text: 'Info'),
                  Tab(text: state is MatchCompleted ? 'Result' : 'Live'),
                  const Tab(text: 'Scorecard'),
                  const Tab(text: 'Insights'),
                  const Tab(text: 'Comms'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(state),
                state is MatchCompleted 
                    ? MatchResultTab(state: state) 
                    : LiveTab(state: state, matchId: widget.matchId),
                ScorecardTab(state: state),
                InsightsTab(state: state),
                CommentaryTab(state: state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTab(ScoringState state) {
    MatchModel? match;
    if (state is MatchLoaded) match = state.match;
    if (state is ScoringActive) match = state.match;
    if (state is InningsCompleted) match = state.match;
    if (state is MatchCompleted) match = state.match;
    if (match == null) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(match.title, style: AppTheme.titleLarge),
          const SizedBox(height: 8),
          _infoRow('Format', match.format.displayName),
          _infoRow('Overs', '${match.totalOvers}'),
          _infoRow('Venue', match.venue ?? 'Not specified'),
          _infoRow('Date', '${match.matchDate.day}/${match.matchDate.month}/${match.matchDate.year}'),
          _infoRow('Status', match.status.displayName),
          if (match.tossSummary.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(match.tossSummary, style: AppTheme.bodyMedium.copyWith(color: AppTheme.accentTeal))),
        ]))),
        const SizedBox(height: 16),
        Text('${match.team1Name} vs ${match.team2Name}', style: AppTheme.titleMedium),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: AppTheme.bodySmall)),
        Expanded(child: Text(value, style: AppTheme.bodyMedium)),
      ]));
  }
}
