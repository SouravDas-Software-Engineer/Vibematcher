import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/constants.dart';
import '../widgets/glass_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              const Center(
                child: Icon(FontAwesomeIcons.bolt, color: AppColors.accent, size: 80),
              ),
              const SizedBox(height: 24),
              const Text(
                "VibeMatcher",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
              const Text(
                "v1.0.0 (Native Mobile)",
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              _buildInfoCard(
                "Experience music like never before with high-fidelity streaming, personalized recommendations, and a premium Glassmorphic aesthetic.",
              ),
              const SizedBox(height: 24),
              _buildInfoCard(
                "Developed by the VibeMatcher Team.\npowered by FastAPI & Flutter.",
              ),
              const SizedBox(height: 48),
              _buildLink("Visit Website", FontAwesomeIcons.globe),
              _buildLink("Follow us on GitHub", FontAwesomeIcons.github),
              _buildLink("Support the Project", FontAwesomeIcons.heart),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(height: 1.5, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildLink(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {},
        tileColor: Colors.white.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: AppColors.textSecondary, size: 18),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
      ),
    );
  }
}
