import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/app/theme/tokens.dart';
import 'package:shopeespot/core/widgets/app_button.dart';
import 'package:shopeespot/core/widgets/app_chip.dart';
import 'package:shopeespot/core/widgets/app_sheet_scaffold.dart';

void main() {
  group('AppTokens and AppTheme', () {
    test('Tokens match DESIGN.md specifications', () {
      const light = AppTokens.light;
      expect(light.background, const Color(0xFFFFFFFF));
      expect(light.surface, const Color(0xFFFFFFFF));
      expect(light.surfaceMuted, const Color(0xFFF5F5F5));
      expect(light.border, const Color(0xFFE5E5E5));
      expect(light.textPrimary, const Color(0xFF111111));
      expect(light.textSecondary, const Color(0xFF737373));
      expect(light.textDisabled, const Color(0xFFA3A3A3));
      expect(light.actionFill, const Color(0xFF111111));
      expect(light.actionOnFill, const Color(0xFFFFFFFF));
      expect(light.danger, const Color(0xFFB42318));
      expect(light.markerShopeeFood, const Color(0xFF1E9E57));
      expect(light.markerSpx, const Color(0xFF1F6FEB));
      expect(light.markerIcon, const Color(0xFFFFFFFF));

      const dark = AppTokens.dark;
      expect(dark.background, const Color(0xFF0B0B0B));
      expect(dark.surface, const Color(0xFF161616));
      expect(dark.surfaceMuted, const Color(0xFF1F1F1F));
      expect(dark.border, const Color(0xFF2A2A2A));
      expect(dark.textPrimary, const Color(0xFFF5F5F5));
      expect(dark.textSecondary, const Color(0xFFA3A3A3));
      expect(dark.textDisabled, const Color(0xFF5C5C5C));
      expect(dark.actionFill, const Color(0xFFF5F5F5));
      expect(dark.actionOnFill, const Color(0xFF111111));
      expect(dark.danger, const Color(0xFFF97066));
      expect(dark.markerShopeeFood, const Color(0xFF3DBE79));
      expect(dark.markerSpx, const Color(0xFF5B9BFF));
      expect(dark.markerIcon, const Color(0xFF0B0B0B));
    });

    Widget buildTestHost({required ThemeData theme, required Widget child}) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(body: child),
      );
    }

    testWidgets('AppButton renders all variants in light and dark mode', (
      tester,
    ) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(
          buildTestHost(
            theme: theme,
            child: Column(
              children: [
                AppButton.primary(label: 'Utama', onPressed: () {}),
                AppButton.outline(label: 'Outline', onPressed: () {}),
                AppButton.text(label: 'Teks', onPressed: () {}),
                AppButton.danger(label: 'Hapus', onPressed: () {}),
              ],
            ),
          ),
        );

        expect(find.text('Utama'), findsOneWidget);
        expect(find.text('Outline'), findsOneWidget);
        expect(find.text('Teks'), findsOneWidget);
        expect(find.text('Hapus'), findsOneWidget);
      }
    });

    testWidgets('AppChip renders active and inactive states', (tester) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(
          buildTestHost(
            theme: theme,
            child: Row(
              children: [
                AppChip(label: 'Semua', isSelected: true, onTap: () {}),
                AppChip(label: 'ShopeeFood', isSelected: false, onTap: () {}),
              ],
            ),
          ),
        );

        expect(find.text('Semua'), findsOneWidget);
        expect(find.text('ShopeeFood'), findsOneWidget);
      }
    });

    testWidgets('AppSheetScaffold renders title and content without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestHost(
          theme: AppTheme.light(),
          child: AppSheetScaffold(
            title: 'Detail Spot',
            onClose: () {},
            child: const Text('Isi Sheet'),
          ),
        ),
      );

      expect(find.text('Detail Spot'), findsOneWidget);
      expect(find.text('Isi Sheet'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
