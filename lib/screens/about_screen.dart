import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<PackageInfo> _getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق')),
      body: FutureBuilder<PackageInfo>(
        future: _getPackageInfo(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final version = info?.version ?? '---';
          final buildNumber = info?.buildNumber ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFF97316,
                            ).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('SunmiPrint', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'الإصدار $version+$buildNumber',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const _Section(title: 'المطور'),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(
                      0xFFF97316,
                    ).withValues(alpha: 0.1),
                    child: const Text(
                      'INB',
                      style: TextStyle(
                        color: Color(0xFFF97316),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: const Text('CODE-NAME-IN-B'),
                  subtitle: const Text('مطور تطبيقات Flutter'),
                  trailing: const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: Color(0xFFF97316),
                  ),
                  onTap: () => _launchUrl(AppConstants.developerGitHubUrl),
                ),
              ),
              const SizedBox(height: 12),

              const _Section(title: 'روابط المطور'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.code_rounded,
                          color: Color(0xFFF97316),
                          size: 20,
                        ),
                      ),
                      title: const Text('GitHub'),
                      subtitle: const Text('github.com/CODE-NAME-IN-B'),
                      trailing: const Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: Color(0xFFF97316),
                      ),
                      onTap: () => _launchUrl(AppConstants.developerGitHubUrl),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.language_rounded,
                          color: Color(0xFFF97316),
                          size: 20,
                        ),
                      ),
                      title: const Text('الموقع الإلكتروني'),
                      subtitle: const Text('mindeset.vercel.app'),
                      trailing: const Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: Color(0xFFF97316),
                      ),
                      onTap: () => _launchUrl(AppConstants.developerWebsiteUrl),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFF97316),
                          size: 20,
                        ),
                      ),
                      title: const Text('ادعمني على Ko-fi'),
                      subtitle: const Text('ko-fi.com/codenameibn'),
                      trailing: const Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: Color(0xFFF97316),
                      ),
                      onTap: () => _launchUrl(AppConstants.developerKofiUrl),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const _Section(title: 'معلومات الإصدار'),
              Card(
                child: Column(
                  children: [
                    _InfoTile(
                      label: 'اسم الحزمة',
                      value: info?.packageName ?? '---',
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _InfoTile(
                      label: 'إصدار التطبيق',
                      value: '$version+$buildNumber',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const _Section(title: 'التقنيات المستخدمة'),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TechChip(label: 'Flutter'),
                      _TechChip(label: 'Material 3'),
                      _TechChip(label: 'Riverpod'),
                      _TechChip(label: 'Hive'),
                      _TechChip(label: 'Sunmi SDK'),
                      _TechChip(label: 'BLE'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: Text(
                  '© 2026 CODE-NAME-IN-B\nجميع الحقوق محفوظة',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;
  const _TechChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFFF97316),
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: const Color(0xFFFFF3E0),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
