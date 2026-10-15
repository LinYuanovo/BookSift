import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repo/database_provider.dart';

// M3 P2-3 · 12 主题色（对标扫书宝典 utw_themelist）。
//
// 色值出处：`work/baodian_v310/decrypt/scripts/index.iyu:1990-2001`（12 档 hex 全表）；
// 默认档 = 陶土珊瑚（设计系统 §2.1，与 AppColors.light/dark 既有 accent 四槽逐值一致）。
// 设计稿 07 屏 swatch 行（index.html:1686–1696）其余 6 枚为占位色，不取。
//
// 推导规则（每档由 seed hex 推出 light/dark 两套四槽）：
// - accent      = seed 适配亮度：浅色模式若黑白双 onAccent 候选均 <4.6 则逐步压暗（白字优先，
//                 与默认档深棕字同向）；深色模式提亮到对深底 ≥3.0（UI 填充档）且 onAccent ≥4.6。
// - onAccent    = 白(#FFFDF8)/近黑(#1F1E1B) 按对比度自动选（两者对比度积恒 >16，适配后必有一者 ≥4.6）。
// - accentSoft  = 浅色 = raised 底 16% seed 浅阶；深色 = canvas 底 25% seed 暗染
//                 （默认档 #F6E7DF / #453025 同构；不透明，全槽 a=1 与 theme_tokens_test 口径一致）。
// - accentStrong= 浅色在 accent 基础上再压暗（至少 ΔL 0.05 分离），深色提亮，
//                 直到对 surface 与 accentSoft 双底 ≥4.6（文字档，红线 4.5 + 0.1 缓冲）。
//
// 对比度自检函数 [relativeLuminance] / [contrastRatio] / [pickOnAccentColor] 纯 Dart，可单测。

/// WCAG 2.1 相对亮度（sRGB 通道线性化）。
double relativeLuminance(Color color) {
  double channel(double s) => s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// WCAG 2.1 对比度 (L1+0.05)/(L2+0.05)。
double contrastRatio(Color a, Color b) {
  final double la = relativeLuminance(a);
  final double lb = relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

// 推导用底色常量（与 app_colors.dart 的 light/dark 常量同源）。
const Color _lightSurface = Color(0xFFFAF9F5); // AppColors.light.surface
const Color _lightRaised = Color(0xFFFFFDF8); // AppColors.light.surfaceRaised
const Color _darkSurface = Color(0xFF201F1C); // AppColors.dark.surface
const Color _darkCanvas = Color(0xFF171614); // AppColors.dark.canvas

// onAccent 双候选：设计白（index.html:566 `.swatch .ic{color:#FFFDF8}`）与 text 近黑。
const Color _candidateWhite = Color(0xFFFFFDF8);
const Color _candidateBlack = Color(0xFF1F1E1B);

/// onAccent 自动选色：白/近黑取对比度更高者。
Color pickOnAccentColor(Color background) =>
    contrastRatio(_candidateWhite, background) >= contrastRatio(_candidateBlack, background)
        ? _candidateWhite
        : _candidateBlack;

double _maxOnContrast(Color background) =>
    math.max(contrastRatio(_candidateWhite, background), contrastRatio(_candidateBlack, background));

/// 一个亮度模式下的 accent 四槽。
@immutable
class AccentPalette {
  const AccentPalette({
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.onAccent,
  });

  /// 品牌填充（按钮/指示器/进度/开关）。
  final Color accent;

  /// 文字级强调（链接/选中文字；对 surface 与 accentSoft 双底 ≥4.5）。
  final Color accentStrong;

  /// 选中态染底（不透明浅阶/暗染）。
  final Color accentSoft;

  /// accent 填充上的文字（≥4.5）。
  final Color onAccent;
}

/// 浅色四槽推导（见文件头规则）。
AccentPalette deriveLightPalette(Color seed) {
  Color accent = seed;
  HSLColor hsl = HSLColor.fromColor(seed);
  for (int i = 0; i < 60 && _maxOnContrast(accent) < 4.6; i++) {
    hsl = hsl.withLightness(math.max(0.0, hsl.lightness - 0.01));
    accent = hsl.toColor();
  }
  final Color accentSoft = Color.lerp(_lightRaised, accent, 0.16)!;
  final double accentL = HSLColor.fromColor(accent).lightness;
  HSLColor strongHsl = HSLColor.fromColor(accent);
  Color accentStrong = accent;
  for (int i = 0; i < 80; i++) {
    strongHsl = strongHsl.withLightness(math.max(0.0, strongHsl.lightness - 0.01));
    accentStrong = strongHsl.toColor();
    if (accentL - strongHsl.lightness >= 0.05 &&
        contrastRatio(accentStrong, _lightSurface) >= 4.6 &&
        contrastRatio(accentStrong, accentSoft) >= 4.6) {
      break;
    }
  }
  return AccentPalette(
    accent: accent,
    accentStrong: accentStrong,
    accentSoft: accentSoft,
    onAccent: pickOnAccentColor(accent),
  );
}

/// 深色四槽推导（见文件头规则；neon 档 accent 可能 == accentStrong，属预期）。
AccentPalette deriveDarkPalette(Color seed) {
  Color accent = seed;
  HSLColor hsl = HSLColor.fromColor(seed);
  for (int i = 0; i < 80; i++) {
    if (contrastRatio(accent, _darkSurface) >= 3.0 && _maxOnContrast(accent) >= 4.6) {
      break;
    }
    hsl = hsl.withLightness(math.min(0.95, hsl.lightness + 0.01));
    accent = hsl.toColor();
  }
  final Color accentSoft = Color.lerp(_darkCanvas, accent, 0.25)!;
  HSLColor strongHsl = HSLColor.fromColor(accent);
  Color accentStrong = accent;
  for (int i = 0; i < 80; i++) {
    if (contrastRatio(accentStrong, _darkSurface) >= 4.6 && contrastRatio(accentStrong, accentSoft) >= 4.6) {
      break;
    }
    strongHsl = strongHsl.withLightness(math.min(0.97, strongHsl.lightness + 0.01));
    accentStrong = strongHsl.toColor();
  }
  return AccentPalette(
    accent: accent,
    accentStrong: accentStrong,
    accentSoft: accentSoft,
    onAccent: pickOnAccentColor(accent),
  );
}

/// 主题色档（13 档：default 陶土珊瑚 + 对标宝典 12 色）。
///
/// [seed] 是 swatch 圆片的原色（设计 07：`background:#D97757` 等原始 hex，深浅模式不变）；
/// [light]/[dark] 是注入 AppColors accent 四槽与 ColorScheme seed 的适配结果。
@immutable
class AppAccentTheme {
  const AppAccentTheme._({
    required this.id,
    required this.label,
    required this.seed,
    required this.light,
    required this.dark,
  });

  factory AppAccentTheme.derived({required String id, required String label, required Color seed}) =>
      AppAccentTheme._(
        id: id,
        label: label,
        seed: seed,
        light: deriveLightPalette(seed),
        dark: deriveDarkPalette(seed),
      );

  /// settings 持久化取值（未知 id 回落 [defaults]）。
  final String id;

  /// 中文名（swatch tooltip / semantics）。
  final String label;

  /// 原始 seed hex（swatch 圆片色）。
  final Color seed;

  final AccentPalette light;
  final AccentPalette dark;

  /// 默认档 = 陶土珊瑚，四槽逐值 == AppColors.light/dark 既有常量（兼容性不变式，
  /// test/theme_accent_test.dart 有断言；theme_tokens_test 的 5.77/7.23 实测值同源）。
  static const AppAccentTheme defaults = AppAccentTheme._(
    id: 'default',
    label: '陶土珊瑚',
    seed: Color(0xFFD97757),
    light: AccentPalette(
      accent: Color(0xFFD97757),
      accentStrong: Color(0xFFA64E2C),
      accentSoft: Color(0xFFF6E7DF),
      onAccent: Color(0xFF241209),
    ),
    dark: AccentPalette(
      accent: Color(0xFFE59A76),
      accentStrong: Color(0xFFEEB292),
      accentSoft: Color(0xFF453025),
      onAccent: Color(0xFF201F1C),
    ),
  );

  /// swatch 选中勾色（设计 566：`.swatch .ic{color:#FFFDF8}` 固定白，不随档位变）。
  static const Color swatchCheckColor = Color(0xFFFFFDF8);

  /// 全 13 档（顺序 = 设置页 swatch 行顺序：默认档在首，12 色按宝典 index.iyu:1990-2001 原序）。
  static final List<AppAccentTheme> all = List<AppAccentTheme>.unmodifiable(<AppAccentTheme>[
    defaults,
    AppAccentTheme.derived(id: 'wai_ba_huang', label: '歪吧黄', seed: const Color(0xFFF4C300)),
    AppAccentTheme.derived(id: 'mao_zi_lv', label: '帽子绿', seed: const Color(0xFF00EB10)),
    AppAccentTheme.derived(id: 'shao_nv_fen', label: '少女粉', seed: const Color(0xFFFB7299)),
    AppAccentTheme.derived(id: 'ji_lao_zi', label: '基佬紫', seed: const Color(0xFF9C27B0)),
    AppAccentTheme.derived(id: 'pang_ci_lan', label: '胖次蓝', seed: const Color(0xFF2196F3)),
    AppAccentTheme.derived(id: 'yi_ma_hong', label: '姨妈红', seed: const Color(0xFFE5353E)),
    AppAccentTheme.derived(id: 'fei_lu_lv', label: '飞卢绿', seed: const Color(0xFF11850A)),
    AppAccentTheme.derived(id: 'xi_rang_lan', label: '息壤蓝', seed: const Color(0xFF2964AF)),
    AppAccentTheme.derived(id: 'duo_kan_cheng', label: '多看橙', seed: const Color(0xFFED902F)),
    AppAccentTheme.derived(id: 'chen_sha_se', label: '辰沙色', seed: const Color(0xFFAE5E53)),
    AppAccentTheme.derived(id: 'cheng_de_hui', label: '承德灰', seed: const Color(0xFF747570)),
    AppAccentTheme.derived(id: 'bai_cao_shuang', label: '百草霜', seed: const Color(0xFF505050)),
  ]);

  /// id → 档位；null/未知一律回落 [defaults]。
  static AppAccentTheme of(String? id) {
    for (final AppAccentTheme a in all) {
      if (a.id == id) {
        return a;
      }
    }
    return defaults;
  }
}

// ── 持久化 + provider（settings 表 KV）─────────────────────────────────────

/// 主题色 settings 键（新键放本文件，core/constants.dart 的 SettingsKeys 只读不改）。
abstract final class AccentSettingsKeys {
  static const String themeAccent = 'theme_accent';
}

/// KV 持久化端口（与 FontSettingsStore 同构；widget 测试用内存 fake 注入）。
abstract interface class AccentStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// drift settings 表实现（复用 lib/data 的 AppDatabase，只 import 不修改）。
final class DriftAccentStore implements AccentStore {
  DriftAccentStore(this._db);

  final AppDatabase _db;

  @override
  Future<String?> read(String key) async {
    final Setting? row =
        await (_db.select(_db.settings)..where((Settings t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String key, String value) =>
      _db.into(_db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

final Provider<AccentStore> accentStoreProvider =
    Provider<AccentStore>((Ref ref) => DriftAccentStore(ref.watch(appDatabaseProvider)));

/// 当前主题色档。读取失败（widget 测试哨兵 / 首启竞态 / path_provider 缺失）一律回落
/// [AppAccentTheme.defaults]，不阻断 UI —— 与 collectSettingsProvider 同策略。
final FutureProvider<AppAccentTheme> accentThemeProvider = FutureProvider<AppAccentTheme>((Ref ref) async {
  try {
    final AccentStore store = ref.watch(accentStoreProvider);
    final String? id = await store.read(AccentSettingsKeys.themeAccent);
    return AppAccentTheme.of(id);
  } catch (_) {
    return AppAccentTheme.defaults;
  }
});

/// 切换写入：写 settings → invalidate 读取侧 → 全 App 实时换色（app.dart 顶层 watch）。
final class AccentController {
  const AccentController(this._ref);

  final Ref _ref;

  Future<void> select(String id) async {
    final AccentStore store = _ref.read(accentStoreProvider);
    await store.write(AccentSettingsKeys.themeAccent, id);
    _ref.invalidate(accentThemeProvider);
  }
}

final Provider<AccentController> accentControllerProvider = Provider<AccentController>(AccentController.new);
