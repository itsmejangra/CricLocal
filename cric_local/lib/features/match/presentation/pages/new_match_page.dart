import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../core/enums.dart';
import '../../data/repositories/match_repository.dart';

class NewMatchPage extends StatefulWidget {
  const NewMatchPage({super.key});
  @override
  State<NewMatchPage> createState() => _NewMatchPageState();
}

class _NewMatchPageState extends State<NewMatchPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _team1Ctrl = TextEditingController();
  final _team2Ctrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _oversCtrl = TextEditingController(text: '20');
  final _playersCtrl = TextEditingController(text: '11');
  String? _tossWinner;
  TossDecision _tossDecision = TossDecision.bat;
  bool _loading = false;
  final List<TextEditingController> _team1Players = List.generate(11, (_) => TextEditingController());
  final List<TextEditingController> _team2Players = List.generate(11, (_) => TextEditingController());
  int _step = 0;

  @override
  void dispose() {
    _titleCtrl.dispose(); _team1Ctrl.dispose(); _team2Ctrl.dispose();
    _venueCtrl.dispose(); _oversCtrl.dispose(); _playersCtrl.dispose();
    for (final c in _team1Players) { c.dispose(); }
    for (final c in _team2Players) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'New Match' : _step == 1 ? '${_team1Ctrl.text} Players' : '${_team2Ctrl.text} Players'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {
          if (_step > 0) { setState(() => _step--); } else if (context.canPop()) { context.pop(); } else { context.go('/'); }
        }),
      ),
      body: _step == 0 ? _buildMatchForm() : _buildPlayerForm(),
    );
  }

  Widget _buildMatchForm() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _field(_titleCtrl, 'Match Title', 'e.g., Match of Complaints', Icons.title),
      const SizedBox(height: 12),
      _field(_team1Ctrl, 'Team 1', 'e.g., KORIGAWA DHARI XI', Icons.groups, onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      _field(_team2Ctrl, 'Team 2', 'e.g., Lion Cycle', Icons.groups_outlined, onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _field(_oversCtrl, 'Overs', '20', Icons.timer, num: true)),
        const SizedBox(width: 12),
        Expanded(child: _field(_playersCtrl, 'Players', '11', Icons.person, num: true)),
      ]),
      const SizedBox(height: 12),
      _field(_venueCtrl, 'Venue', 'Optional', Icons.location_on, req: false),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Toss', style: AppTheme.titleMedium),
        const SizedBox(height: 12),
        Text('Toss Winner:', style: AppTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(children: [
          if (_team1Ctrl.text.isNotEmpty) Expanded(child: GestureDetector(
            onTap: () => setState(() => _tossWinner = _team1Ctrl.text),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(color: _tossWinner == _team1Ctrl.text ? AppTheme.primaryRed.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(8), border: Border.all(color: _tossWinner == _team1Ctrl.text ? AppTheme.primaryRed : AppTheme.cardBorder, width: _tossWinner == _team1Ctrl.text ? 2 : 1)),
              child: Center(child: Text(_team1Ctrl.text, style: AppTheme.bodyMedium.copyWith(fontWeight: _tossWinner == _team1Ctrl.text ? FontWeight.w700 : FontWeight.w400, color: _tossWinner == _team1Ctrl.text ? AppTheme.primaryRed : AppTheme.textPrimary), overflow: TextOverflow.ellipsis))))),
          if (_team1Ctrl.text.isNotEmpty && _team2Ctrl.text.isNotEmpty) const SizedBox(width: 12),
          if (_team2Ctrl.text.isNotEmpty) Expanded(child: GestureDetector(
            onTap: () => setState(() => _tossWinner = _team2Ctrl.text),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(color: _tossWinner == _team2Ctrl.text ? AppTheme.primaryRed.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(8), border: Border.all(color: _tossWinner == _team2Ctrl.text ? AppTheme.primaryRed : AppTheme.cardBorder, width: _tossWinner == _team2Ctrl.text ? 2 : 1)),
              child: Center(child: Text(_team2Ctrl.text, style: AppTheme.bodyMedium.copyWith(fontWeight: _tossWinner == _team2Ctrl.text ? FontWeight.w700 : FontWeight.w400, color: _tossWinner == _team2Ctrl.text ? AppTheme.primaryRed : AppTheme.textPrimary), overflow: TextOverflow.ellipsis))))),
          if (_team1Ctrl.text.isEmpty && _team2Ctrl.text.isEmpty) Text('Enter team names first', style: AppTheme.bodySmall),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text('Elected to: ', style: AppTheme.bodyMedium), const SizedBox(width: 12),
          ChoiceChip(label: const Text('Bat'), selected: _tossDecision == TossDecision.bat, selectedColor: AppTheme.accentTeal, onSelected: (_) => setState(() => _tossDecision = TossDecision.bat)),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('Bowl'), selected: _tossDecision == TossDecision.bowl, selectedColor: AppTheme.accentTeal, onSelected: (_) => setState(() => _tossDecision = TossDecision.bowl)),
        ]),
      ]))),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: () { if (_formKey.currentState!.validate()) setState(() => _step = 1); },
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        child: const Text('Next: Add Players →', style: TextStyle(fontSize: 16))),
    ])));
  }

  Widget _buildPlayerForm() {
    final ctrls = _step == 1 ? _team1Players : _team2Players;
    final count = (int.tryParse(_playersCtrl.text) ?? 11).clamp(2, 11);
    return Column(children: [
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: count, itemBuilder: (_, i) =>
        Padding(padding: const EdgeInsets.only(bottom: 8), child: TextFormField(controller: ctrls[i],
          decoration: InputDecoration(labelText: 'Player ${i + 1}', prefixIcon: const Icon(Icons.person_outline), border: const OutlineInputBorder(), filled: true, fillColor: Colors.white))))),
      Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _loading ? null : () { if (_step == 1) setState(() => _step = 2); else _createMatch(); },
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(_step == 1 ? 'Next: ${_team2Ctrl.text} Players →' : 'Create Match ✓', style: const TextStyle(fontSize: 16))))),
    ]);
  }

  Widget _field(TextEditingController c, String label, String hint, IconData icon, {bool num = false, bool req = true, ValueChanged<String>? onChanged}) {
    return TextFormField(controller: c, keyboardType: num ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon), border: const OutlineInputBorder(), filled: true, fillColor: Colors.white),
      onChanged: onChanged,
      validator: req ? (v) => v == null || v.isEmpty ? 'Required' : null : null);
  }

  Future<void> _createMatch() async {
    setState(() => _loading = true);
    try {
      final repo = getIt<MatchRepository>();
      final match = await repo.createMatch(title: _titleCtrl.text, team1Name: _team1Ctrl.text, team2Name: _team2Ctrl.text,
        totalOvers: int.tryParse(_oversCtrl.text) ?? 20, playersPerSide: int.tryParse(_playersCtrl.text) ?? 11,
        venue: _venueCtrl.text.isEmpty ? null : _venueCtrl.text, tossWinner: _tossWinner, tossDecision: _tossWinner != null ? _tossDecision : null);
      final count = (int.tryParse(_playersCtrl.text) ?? 11).clamp(2, 11);
      for (int i = 0; i < count; i++) {
        final t1Name = _team1Players[i].text.trim().isNotEmpty ? _team1Players[i].text.trim() : 'Player ${i + 1}';
        await repo.addPlayer(name: t1Name, teamName: _team1Ctrl.text, matchId: match.id, battingOrder: i + 1);
        final t2Name = _team2Players[i].text.trim().isNotEmpty ? _team2Players[i].text.trim() : 'Player ${i + 1}';
        await repo.addPlayer(name: t2Name, teamName: _team2Ctrl.text, matchId: match.id, battingOrder: i + 1);
      }
      if (mounted) context.go('/match/${match.id}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }
}
