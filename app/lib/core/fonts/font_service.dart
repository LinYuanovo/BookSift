import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repo/database_provider.dart';
import 'font_ports.dart';
import 'font_registry.dart';
import 'font_tokens.dart';
import 'system_font_catalog.dart';

/// 字体服务：导入注册表 + 角色槽配置 + 运行时家族加载（ChangeNotifier → Riverpod）。
///
/// 解析链（设计系统 v1.4 §2.2/§5.2）：
/// 槽配置（fonts.roles）× 注册表（fonts.registry）→ [families]（FontFamilySet）
/// → `AppTypography.resolve(families)` → BookTheme → 全 App。
/// 任何失败（DB/文件/引擎）都降级 system，不抛出。
class FontService extends ChangeNotifier {
  FontService({
    required FontSettingsStore settings,
    FontFilePicker picker = const PlatformFontFilePicker(),
    FontRegistrar registrar = const RuntimeFontRegistrar(),
    FontFileStore files = const AppSupportFontFileStore(),
    SystemFontCatalog systemFonts = const PlatformSystemFontCatalog(),
  }) : _settings = settings,
       _picker = picker,
       _registrar = registrar,
       _files = files,
       _systemFonts = systemFonts;

  final FontSettingsStore _settings;
  final FontFilePicker _picker;
  final FontRegistrar _registrar;
  final FontFileStore _files;
  final SystemFontCatalog _systemFonts;

  List<ImportedFont> _registry = const <ImportedFont>[];

  /// 只存非 system 覆盖；缺角色 = system。
  Map<FontRole, FontSlot> _slots = const <FontRole, FontSlot>{};

  /// 引擎加载成功的 fontId 集合（失败/缺文件者不进集合 → 解析时回退 system）。
  Set<String> _loadedIds = const <String>{};
  FontFamilySet _families = FontFamilySet.standard;

  /// 当前生效的十角色 family 解析结果。
  FontFamilySet get families => _families;

  /// 已导入字体注册表（不可变视图）。
  List<ImportedFont> get registry => List<ImportedFont>.unmodifiable(_registry);

  /// 角色当前槽位（缺省 system）。
  FontSlot slotOf(FontRole role) => _slots[role] ?? const FontSlot.system();

  /// 启动加载（main 于 runApp 前 await）：读注册表/槽位 → 加载已导入字体 → 解析。
  /// 默认配置（无导入）零文件 IO 之外的字体加载，失败不阻塞启动。
  Future<void> bootstrap() async {
    try {
      _registry = FontRegistryCodec.decode(await _settings.read(FontSettingsKeys.registry));
      _slots = FontRoleSlotsCodec.decode(await _settings.read(FontSettingsKeys.roles));
    } catch (_) {
      _registry = const <ImportedFont>[];
      _slots = const <FontRole, FontSlot>{};
    }
    final Set<String> loaded = <String>{};
    for (final ImportedFont font in _registry) {
      try {
        final Uint8List bytes = await _files.read(font.storedName);
        await _registrar.registerFamily(font.familyName, bytes);
        loaded.add(font.fontId);
      } catch (_) {
        // 单字体失败（文件丢失/损坏/引擎拒绝）→ 引用它的角色解析时自动回退 system。
      }
    }
    _loadedIds = loaded;
    _families = _resolve();
    notifyListeners();
  }

  /// 弹文件选择器导入；返回 null = 成功或用户取消，非 null = 可展示的错误消息。
  Future<String?> importPickedFont() async {
    final PickedFontFile? picked;
    try {
      picked = await _picker.pickFontFile();
    } catch (_) {
      // 平台对话框不可用（Linux 桌面缺 zenity/portal 等）→ 与 [scanSystemFonts]
      // 同口径：返回可展示的消息，不把异常抛给 UI（否则按钮会卡在「导入中」）。
      return '打开文件选择器失败，请重试或改用「加入系统字体」';
    }
    if (picked == null) return null; // 用户取消不算错误
    return importFontBytes(picked.fileName, picked.bytes);
  }

  /// 枚举系统已安装字体（ttf / otf / ttc）供选择界面展示。
  /// 失败降级为「空列表 + 可展示的错误消息」，不抛异常、不影响现有导入。
  Future<({List<SystemFontEntry> fonts, String? error})> scanSystemFonts() async {
    try {
      return (fonts: await _systemFonts.listFonts(), error: null);
    } on SystemFontCatalogException catch (e) {
      return (fonts: const <SystemFontEntry>[], error: e.message);
    } catch (_) {
      return (fonts: const <SystemFontEntry>[], error: '读取系统字体失败，请使用「导入字体」选择文件');
    }
  }

  /// 读取所选系统字体字节，走 [importFontBytes] 现有校验 / 落盘 / 注册 / 持久化链路。
  /// 返回 null = 成功，非 null = 可展示的错误消息。
  Future<String?> importSystemFont(SystemFontEntry entry) async {
    final Uint8List bytes;
    try {
      bytes = await _systemFonts.readFontBytes(entry);
    } catch (_) {
      return '读取系统字体文件失败：${entry.fileName}';
    }
    return _importFontBytes(
      entry.fileName,
      bytes,
      familyName: entry.familyName,
      allowCollections: true,
    );
  }

  /// 导入字节流：校验 → 落盘 → 注册引擎 → 持久化。失败自动回滚，不抛异常。
  Future<String?> importFontBytes(String fileName, Uint8List bytes) =>
      _importFontBytes(fileName, bytes);

  Future<String?> _importFontBytes(
    String fileName,
    Uint8List bytes, {
    String? familyName,
    bool allowCollections = false,
  }) async {
    final String ext = _extensionOf(fileName);
    final bool supported = ext == 'ttf' || ext == 'otf' || (allowCollections && ext == 'ttc');
    if (!supported) {
      return allowCollections ? '仅支持 ttf / otf / ttc 字体文件' : '仅支持 ttf / otf 字体文件';
    }
    if (bytes.isEmpty) {
      return '字体文件为空';
    }
    final String resolvedFamily =
        (familyName ?? fileName.substring(0, fileName.length - ext.length - 1)).trim();
    if (resolvedFamily.isEmpty) {
      return '无法解析字体名称';
    }
    if (_registry.any(
      (ImportedFont f) => f.familyName.toLowerCase() == resolvedFamily.toLowerCase(),
    )) {
      return '已导入同名字体「$resolvedFamily」';
    }
    final ImportedFont font = ImportedFont(
      fontId: _newFontId(),
      familyName: resolvedFamily,
      fileName: fileName,
      importedAt: DateTime.now(),
    );
    try {
      await _files.write(font.storedName, bytes);
      await _registrar.registerFamily(font.familyName, bytes);
    } catch (_) {
      try {
        await _files.delete(font.storedName);
      } catch (_) {
        // 回滚失败无碍：注册表未收录该文件，下次导入会覆盖同名落盘文件。
      }
      return '字体加载失败，请确认文件为有效的 ttf / otf';
    }
    _registry = <ImportedFont>[..._registry, font];
    _loadedIds = <String>{..._loadedIds, font.fontId};
    final String? error = await _persist();
    _families = _resolve();
    notifyListeners();
    return error;
  }

  /// 设置角色槽位；未知 fontId 防御性视为 system。返回持久化错误（null = 成功）。
  Future<String?> setRoleSlot(FontRole role, FontSlot slot) async {
    final bool known = slot.isSystem || _registry.any((ImportedFont f) => f.fontId == slot.fontId);
    final Map<FontRole, FontSlot> next = Map<FontRole, FontSlot>.of(_slots);
    if (slot.isSystem || !known) {
      next.remove(role);
    } else {
      next[role] = slot;
    }
    _slots = next;
    final String? error = await _persist();
    _families = _resolve();
    notifyListeners();
    return error;
  }

  /// 恢复默认：全部角色回 system（导入的字体文件保留）。
  Future<String?> resetRoles() async {
    _slots = const <FontRole, FontSlot>{};
    final String? error = await _persist();
    _families = _resolve();
    notifyListeners();
    return error;
  }

  /// 删除导入字体：引用它的角色自动回退 system。返回错误消息（null = 成功）。
  Future<String?> deleteFont(String fontId) async {
    final int index = _registry.indexWhere((ImportedFont f) => f.fontId == fontId);
    if (index < 0) return '字体不存在';
    final ImportedFont font = _registry[index];
    _registry = <ImportedFont>[..._registry]..removeAt(index);
    _slots = <FontRole, FontSlot>{
      for (final MapEntry<FontRole, FontSlot> e in _slots.entries)
        if (e.value.fontId != fontId) e.key: e.value,
    };
    _loadedIds = <String>{..._loadedIds}..remove(fontId);
    try {
      await _files.delete(font.storedName);
    } catch (_) {
      // 文件删除失败不阻塞注册表移除（残留文件不被引用，无副作用）。
    }
    final String? error = await _persist();
    _families = _resolve();
    notifyListeners();
    return error;
  }

  /// 槽 × 注册表 → family：system 槽 = null（mono 例外 = 平台等宽族）；
  /// imported 槽指向缺失/未加载字体时同样回退 system 值。
  FontFamilySet _resolve() => FontFamilySet.fromFamilyOf((FontRole role) {
    final FontSlot slot = slotOf(role);
    if (!slot.isSystem) {
      for (final ImportedFont font in _registry) {
        if (font.fontId == slot.fontId && _loadedIds.contains(font.fontId)) {
          return font.familyName;
        }
      }
    }
    return role == FontRole.mono ? FontFamily.monospace : null;
  });

  Future<String?> _persist() async {
    try {
      await _settings.write(FontSettingsKeys.registry, FontRegistryCodec.encode(_registry));
      await _settings.write(FontSettingsKeys.roles, FontRoleSlotsCodec.encode(_slots));
      return null;
    } catch (_) {
      return '字体设置保存失败';
    }
  }

  static String _extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    return dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : '';
  }

  static String _newFontId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
}

/// 字体服务单例；bootstrap 由 main() 在 runApp 前调用（见 main.dart）。
final ChangeNotifierProvider<FontService> fontServiceProvider = ChangeNotifierProvider<FontService>((Ref ref) {
  return FontService(settings: DriftFontSettingsStore(ref.watch(appDatabaseProvider)));
});
