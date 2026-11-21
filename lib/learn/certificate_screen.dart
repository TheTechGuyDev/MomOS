import 'package:material_ui/material_ui.dart';

import '../core/profile_service.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import 'content.dart';

class CertificateScreen extends StatelessWidget {
  final Track track;
  final DateTime earnedOn;
  const CertificateScreen({super.key, required this.track, required this.earnedOn});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Certificate')),
      body: FutureBuilder<Profile?>(
        future: ProfileService.me(),
        builder: (context, snap) {
          final name = snap.data?.displayName ?? '';
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                AspectRatio(
                  aspectRatio: 0.75,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: const Color(0xFFFFFBF7), borderRadius: BorderRadius.circular(18)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/logo.png', width: 56, height: 56)),
                        const SizedBox(height: 12),
                        Text('CERTIFICATE OF COMPLETION',
                            textAlign: TextAlign.center,
                            style: t.labelLarge?.copyWith(letterSpacing: 2, fontWeight: FontWeight.w900, color: AppColors.secondary)),
                        const SizedBox(height: 20),
                        Text('This certifies that', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                        const SizedBox(height: 6),
                        Text(name, textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('has completed', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                        const SizedBox(height: 10),
                        Text('${track.emoji}  ${track.title}',
                            textAlign: TextAlign.center, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.primary)),
                        const SizedBox(height: 6),
                        Text('${track.lessons.length} lessons and quizzes',
                            style: t.bodySmall?.copyWith(color: AppColors.muted)),
                        const Spacer(),
                        Text(shortDate(earnedOn), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                        Text('MomOS Learn', style: t.bodySmall?.copyWith(color: AppColors.muted)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Take a screenshot to share it on WhatsApp or LinkedIn 🎉',
                    textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
