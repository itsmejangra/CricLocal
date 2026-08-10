
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/match_repository.dart';

class MatchFeesPage extends StatefulWidget {
  final String matchId;
  const MatchFeesPage({super.key, required this.matchId});

  @override
  State<MatchFeesPage> createState() => _MatchFeesPageState();
}

class _MatchFeesPageState extends State<MatchFeesPage> {
  final _repo = getIt<MatchRepository>();
  List<MatchFee> _fees = [];
  List<PlayerModel> _players = [];
  bool _loading = true;
  double _defaultFee = 100.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final fees = await _repo.getMatchFees(widget.matchId);
    final players = await _repo.getAllPlayersForMatch(widget.matchId);
    
    if (mounted) {
      setState(() {
        _fees = fees;
        _players = players;
        _loading = false;
      });
    }
  }

  Future<void> _initializeFees() async {
    final controller = TextEditingController(text: _defaultFee.toStringAsFixed(0));
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Match Fee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the default fee amount per player:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text) ?? 0.0),
            child: const Text('INITIALIZE'),
          ),
        ],
      ),
    );

    if (amount != null) {
      setState(() => _loading = true);
      await _repo.initializeMatchFees(widget.matchId, amount);
      await _loadData();
    }
  }

  Future<void> _togglePaid(MatchFee fee) async {
    final newStatus = fee.status == 'paid' ? 'pending' : 'paid';
    final newPaid = newStatus == 'paid' ? fee.amountDue : 0.0;
    
    final updated = fee.copyWith(
      status: newStatus,
      amountPaid: newPaid,
    );
    
    await _repo.updateMatchFee(updated);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final totalCollected = _fees.fold(0.0, (sum, f) => sum + f.amountPaid);
    final totalExpected = _fees.fold(0.0, (sum, f) => sum + f.amountDue);

    if (_fees.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Match Fees')),
        body: _buildEmptyState(),
      );
    }

    // Get unique team names from players
    final teams = _players.map((p) => p.teamName).toSet().toList();
    // Sort to ensure consistent order (Team 1 then Team 2)
    teams.sort();

    return DefaultTabController(
      length: teams.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Match Fees'),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, letterSpacing: 1.1, fontSize: 13),
            tabs: teams.map((team) => Tab(text: team.toUpperCase())).toList(),
          ),
        ),
        body: TabBarView(
          children: teams.map((teamName) {
            final teamPlayers = _players.where((p) => p.teamName == teamName).toList();
            final teamFees = _fees.where((f) => teamPlayers.any((p) => p.id == f.playerId)).toList();
            
            final teamCollected = teamFees.fold(0.0, (sum, f) => sum + f.amountPaid);
            final teamExpected = teamFees.fold(0.0, (sum, f) => sum + f.amountDue);

            return Column(
              children: [
                _buildSummaryHeader(teamCollected, teamExpected),
                Expanded(
                  child: ListView.builder(
                    itemCount: teamPlayers.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final player = teamPlayers[index];
                      final fee = _fees.firstWhere((f) => f.playerId == player.id,
                        orElse: () => MatchFee(id: '', matchId: '', playerId: '', updatedAt: ''));
                      
                      if (fee.id.isEmpty) return const SizedBox();

                      return _buildPlayerFeeItem(player, fee);
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payments_outlined, size: 80, color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text('Match fees not initialized', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Setup fees for all participating players.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initializeFees,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('INITIALIZE MATCH FEES', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(double collected, double expected) {
    final progress = expected > 0 ? collected / expected : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryCol('COLLECTED', '₹${collected.toStringAsFixed(0)}', Colors.white),
              _summaryCol('EXPECTED', '₹${expected.toStringAsFixed(0)}', Colors.white.withValues(alpha: 0.7)),
              _summaryCol('PENDING', '₹${(expected - collected).toStringAsFixed(0)}', AppTheme.accentTeal),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% Collected',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _summaryCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
      ],
    );
  }

  Widget _buildPlayerFeeItem(PlayerModel player, MatchFee fee) {
    final isPaid = fee.status == 'paid';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
          child: Text(player.name[0], style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(player.teamName, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('₹${fee.amountDue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(
                isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isPaid ? AppTheme.winGreen : AppTheme.textSecondary.withValues(alpha: 0.3),
                size: 32,
              ),
              onPressed: () => _togglePaid(fee),
            ),
          ],
        ),
      ),
    );
  }
}
