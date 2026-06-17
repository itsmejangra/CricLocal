import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../app/di.dart';
import '../../../match/data/repositories/match_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController(text: 'Cricket Fan');
  final _phoneController = TextEditingController(text: '9876543210');
  
  // Simulated stats - in a real app these would come from an aggregate query
  int totalRuns = 0;
  int totalWickets = 0;
  int totalMatches = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final repo = getIt<MatchRepository>();
    final matches = await repo.getAllMatches();
    // Simplified simulation
    setState(() {
      totalMatches = matches.length;
      totalRuns = matches.length * 42; // Placeholder logic
      totalWickets = matches.length * 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionTitle('Basic Information'),
                  const SizedBox(height: 16),
                  _buildTextField('Display Name', _nameController, Icons.person_outline),
                  const SizedBox(height: 16),
                  _buildTextField('Phone Number', _phoneController, Icons.phone_android_outlined),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Lifetime Statistics'),
                  const SizedBox(height: 16),
                  _buildStatsGrid(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Account Status'),
                  const SizedBox(height: 16),
                  _buildStatusCard(),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully!')));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.accentTeal, AppTheme.primaryBlue],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Stack(
                children: [
                   const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 64, color: AppTheme.accentTeal),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Completeness: 25%',
                style: AppTheme.bodySmall.copyWith(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.accentTeal),
        filled: true,
        fillColor: AppTheme.backgroundGray.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _statBox('Matches', '$totalMatches', Colors.blue),
        const SizedBox(width: 12),
        _statBox('Runs', '$totalRuns', Colors.orange),
        const SizedBox(width: 12),
        _statBox('Wickets', '$totalWickets', Colors.purple),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(value, style: AppTheme.headlineSmall.copyWith(color: color, fontWeight: FontWeight.bold)),
            Text(label, style: AppTheme.bodySmall.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Free Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Upgrade to PRO for advanced analytics & unlimited live streaming.', style: AppTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.amber),
        ],
      ),
    );
  }
}
