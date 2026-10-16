import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'font_metadata.dart';
import 'system_font_permission.dart';

/// 系统已安装字体目录端口：枚举可选字体 + 读取字体文件字节。
abstract interface class SystemFontCatalog {
  /// 枚举可加入「我的字体」的系统字体（ttf / otf / ttc，按字体家族名排序）。
  ///
  /// 不支持或读取失败时抛 [SystemFontCatalogException]，message 可直接展示给用户。
  Future<List<SystemFontEntry>> listFonts();

  /// 读取一条系统字体的文件字节；失败时抛出原始 IO 异常。
  Future<Uint8List> readFontBytes(SystemFontEntry entry);
}

/// 系统字体枚举失败：message 为可展示的中文提示。
class SystemFontCatalogException implements Exception {
  const SystemFontCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 一条系统字体记录。
class SystemFontEntry {
  const SystemFontEntry({
    required this.familyName,
    required this.fileName,
    required this.filePath,
  });

  /// SFNT name 表解析出的字体家族名（解析失败时退化为文件名去扩展名）。
  final String familyName;

  /// 字体文件名（展示 + 导入落盘时保留原扩展名）。
  final String fileName;

  /// 字体文件绝对路径。
  final String filePath;

  /// 选择列表主文案；与 familyName 同义，保留 getter 兼容旧调用点。
  String get displayName => familyName;
}

/// 跨平台系统字体目录实现。
///
/// Windows = 注册表；macOS/Linux/Android = 字体目录（Linux 优先 fc-list）。
/// iOS 沙箱不允许应用直接读取系统字体文件，统一返回可展示提示。
final class PlatformSystemFontCatalog implements SystemFontCatalog {
  const PlatformSystemFontCatalog({
    this.permissionRequester = const MethodChannelSystemFontPermissionRequester(),
  });

  final SystemFontPermissionRequester permissionRequester;

  static const Set<String> _extensions = <String>{'ttf', 'otf', 'ttc'};

  @override
  Future<List<SystemFontEntry>> listFonts() async {
    if (Platform.isWindows) return _listWindows();
    if (Platform.isMacOS) return _listMacos();
    if (Platform.isLinux) return _listLinux();
    if (Platform.isAndroid) return _listAndroid();
    if (Platform.isIOS) {
      throw const SystemFontCatalogException(
        'iOS 不支持直接读取系统字体文件，请使用「导入字体」选择文件',
      );
    }
    throw const SystemFontCatalogException('当前系统不支持读取系统字体，请使用「导入字体」选择文件');
  }

  @override
  Future<Uint8List> readFontBytes(SystemFontEntry entry) => File(entry.filePath).readAsBytes();

  Future<List<SystemFontEntry>> _listWindows() async {
    final Map<String, String> fallbackNames = <String, String>{};
    final Set<String> paths = <String>{};
    try {
      final _Win32Registry registry = _Win32Registry.open();
      for (final int hive in <int>[_hkeyLocalMachine, _hkeyCurrentUser]) {
        for (final ({String name, String data}) value in registry.readFontValues(hive, _fontsSubKey)) {
          final String? filePath = _resolveWindowsFile(value.data);
          if (filePath == null) continue;
          paths.add(filePath);
          fallbackNames.putIfAbsent(filePath, () => _stripRegistrySuffix(value.name));
        }
      }
    } on SystemFontCatalogException {
      rethrow;
    } catch (_) {
      throw const SystemFontCatalogException('读取系统字体失败，请使用「导入字体」选择文件');
    }
    return _entriesFromPaths(paths, fallbackNames: fallbackNames);
  }

  Future<List<SystemFontEntry>> _listMacos() async {
    final String home = Platform.environment['HOME'] ?? '';
    final List<String> dirs = <String>[
      '/System/Library/Fonts',
      '/System/Library/Fonts/Supplemental',
      '/Library/Fonts',
      if (home.isNotEmpty) '$home/Library/Fonts',
    ];
    return _entriesFromPaths(await _filesUnder(dirs));
  }

  Future<List<SystemFontEntry>> _listLinux() async {
    final Set<String> paths = <String>{};
    try {
      final ProcessResult result = await Process.run(
        'fc-list',
        <String>['-f', '%{file}\\n'],
        runInShell: false,
      );
      if (result.exitCode == 0) {
        for (final String line in '${result.stdout}'.split('\n')) {
          final String path = line.trim();
          if (path.isNotEmpty && _isFontFile(path)) paths.add(path);
        }
      }
    } catch (_) {
      // fc-list 缺失/不可执行时走目录扫描。
    }
    if (paths.isEmpty) {
      final String home = Platform.environment['HOME'] ?? '';
      paths.addAll(await _filesUnder(<String>[
        '/usr/share/fonts',
        '/usr/local/share/fonts',
        if (home.isNotEmpty) '$home/.local/share/fonts',
        if (home.isNotEmpty) '$home/.fonts',
      ]));
    }
    return _entriesFromPaths(paths);
  }

  Future<List<SystemFontEntry>> _listAndroid() async {
    final List<String> dirs = <String>[
      '/system/fonts',
      '/system/product/fonts',
      '/product/fonts',
      '/data/fonts',
    ];
    try {
      return _entriesFromPaths(await _filesUnder(dirs));
    } on FileSystemException {
      final bool granted = await permissionRequester.requestReadFontsPermission();
      if (!granted) {
        throw const SystemFontCatalogException('缺少读取系统字体的权限，请在系统设置中允许后重试');
      }
      try {
        return _entriesFromPaths(await _filesUnder(dirs));
      } on FileSystemException {
        throw const SystemFontCatalogException('读取系统字体失败，请使用「导入字体」选择文件');
      }
    }
  }

  Future<List<SystemFontEntry>> _entriesFromPaths(
    Iterable<String> paths, {
    Map<String, String> fallbackNames = const <String, String>{},
  }) async {
    final Map<String, SystemFontEntry> byPath = <String, SystemFontEntry>{};
    for (final String path in paths) {
      final String key = path.toLowerCase();
      if (byPath.containsKey(key)) continue;
      String? family = await FontMetadata.familyNameOfFile(File(path));
      family ??= fallbackNames[path];
      family ??= FontMetadata.fallbackFamilyName(path);
      final String clean = family.trim();
      byPath[key] = SystemFontEntry(
        familyName: clean.isEmpty ? FontMetadata.fallbackFamilyName(path) : clean,
        fileName: _fileNameOf(path),
        filePath: path,
      );
    }
    return byPath.values.toList()
      ..sort((SystemFontEntry a, SystemFontEntry b) =>
          a.familyName.toLowerCase().compareTo(b.familyName.toLowerCase()));
  }

  /// 递归扫描字体目录；全部目录都不可读且没有任何命中时抛第一个 IO 异常。
  Future<List<String>> _filesUnder(Iterable<String> dirs) async {
    final Set<String> paths = <String>{};
    FileSystemException? firstError;
    for (final String path in dirs) {
      final Directory dir = Directory(path);
      try {
        if (!await dir.exists()) continue;
        await for (final FileSystemEntity entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File && _isFontFile(entity.path)) paths.add(entity.path);
        }
      } on FileSystemException catch (e) {
        firstError ??= e;
      }
    }
    if (paths.isEmpty && firstError != null) throw firstError;
    return paths.toList();
  }

  /// 注册表值 → 真实存在的字体文件路径；非字体扩展名或文件缺失 → null。
  static String? _resolveWindowsFile(String data) {
    final String trimmed = data.trim();
    if (trimmed.isEmpty || !_isFontFile(trimmed)) return null;
    final bool absolute = trimmed.contains(r'\') || trimmed.contains('/') || trimmed.contains(':');
    final String windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
    final String? localAppData = Platform.environment['LOCALAPPDATA'];
    final List<String> fontDirs = <String>[
      '$windir\\Fonts',
      if (localAppData != null) '$localAppData\\Microsoft\\Windows\\Fonts',
    ];
    final Iterable<String> candidates = absolute
        ? <String>[trimmed]
        : fontDirs.map((String dir) => '$dir\\$trimmed');
    for (final String candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  static String _stripRegistrySuffix(String name) => name
      .replaceFirst(RegExp(r'\s*\((TrueType|OpenType|TrueType Collection|All Res)\)\s*$'), '')
      .trim();

  static bool _isFontFile(String path) => _extensions.contains(_extensionOf(path));

  static String _fileNameOf(String path) {
    final int back = path.lastIndexOf('\\');
    final int forward = path.lastIndexOf('/');
    final int slash = back > forward ? back : forward;
    return slash >= 0 ? path.substring(slash + 1) : path;
  }

  static String _extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    return dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : '';
  }
}

// ── Win32 常量（advapi32 注册表直调；HKEY_* 为预定义伪句柄）──
const int _hkeyLocalMachine = 0x80000002;
const int _hkeyCurrentUser = 0x80000001;

/// KEY_READ = READ_CONTROL | KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY。
const int _keyRead = 0x00020019;
const int _errorSuccess = 0;
const int _errorFileNotFound = 2;
const int _errorMoreData = 234;
const int _errorNoMoreItems = 259;
const int _regSz = 1;
const int _nameChars = 1024;
const int _dataBytes = 2048;
const String _fontsSubKey = r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts';

/// advapi32 / kernel32 直调的最小封装（避免为一次枚举引入新依赖）。
final class _Win32Registry {
  _Win32Registry._(this._regOpenKeyEx, this._regEnumValue, this._regCloseKey, this._localAlloc, this._localFree);

  final _RegOpenKeyExDart _regOpenKeyEx;
  final _RegEnumValueDart _regEnumValue;
  final _RegCloseKeyDart _regCloseKey;
  final _LocalAllocDart _localAlloc;
  final _LocalFreeDart _localFree;

  static _Win32Registry? _cached;

  static _Win32Registry open() {
    final _Win32Registry? cached = _cached;
    if (cached != null) return cached;
    final DynamicLibrary advapi32 = DynamicLibrary.open('advapi32.dll');
    final DynamicLibrary kernel32 = DynamicLibrary.open('kernel32.dll');
    return _cached = _Win32Registry._(
      advapi32.lookupFunction<_RegOpenKeyExNative, _RegOpenKeyExDart>('RegOpenKeyExW'),
      advapi32.lookupFunction<_RegEnumValueNative, _RegEnumValueDart>('RegEnumValueW'),
      advapi32.lookupFunction<_RegCloseKeyNative, _RegCloseKeyDart>('RegCloseKey'),
      kernel32.lookupFunction<_LocalAllocNative, _LocalAllocDart>('LocalAlloc'),
      kernel32.lookupFunction<_LocalFreeNative, _LocalFreeDart>('LocalFree'),
    );
  }

  /// 读一处字体键的全部 (值名, 值数据)；键不存在 → 空列表。
  List<({String name, String data})> readFontValues(int hive, String subKey) {
    final Pointer<Uint8> subKeyMem = _alloc((subKey.length + 1) * 2);
    final Pointer<Uint8> keyMem = _alloc(sizeOf<IntPtr>());
    final Pointer<Uint8> nameMem = _alloc(_nameChars * 2);
    final Pointer<Uint8> dataMem = _alloc(_dataBytes);
    final Pointer<Uint8> scratchMem = _alloc(16);
    try {
      final Pointer<Uint16> subKeyBuf = subKeyMem.cast<Uint16>();
      final Uint16List units = subKeyBuf.asTypedList(subKey.length + 1);
      for (int i = 0; i < subKey.length; i++) {
        units[i] = subKey.codeUnitAt(i);
      }
      units[subKey.length] = 0;

      final int openCode = _regOpenKeyEx(hive, subKeyBuf, 0, _keyRead, keyMem.cast<IntPtr>());
      if (openCode == _errorFileNotFound) return const <({String name, String data})>[];
      if (openCode != _errorSuccess) {
        throw SystemFontCatalogException('读取系统字体注册表失败（错误码 $openCode）');
      }
      final int key = keyMem.cast<IntPtr>().value;
      try {
        return _enumerateValues(key, nameMem.cast<Uint16>(), dataMem, scratchMem.cast<Uint32>());
      } finally {
        _regCloseKey(key);
      }
    } finally {
      _localFree(subKeyMem);
      _localFree(keyMem);
      _localFree(nameMem);
      _localFree(dataMem);
      _localFree(scratchMem);
    }
  }

  List<({String name, String data})> _enumerateValues(
    int key,
    Pointer<Uint16> nameBuf,
    Pointer<Uint8> dataBuf,
    Pointer<Uint32> scratch,
  ) {
    final List<({String name, String data})> values = <({String name, String data})>[];
    for (int index = 0;; index++) {
      scratch[0] = _nameChars; // 值名缓冲容量（字符）
      scratch[1] = 0; // 输出：值类型
      scratch[2] = _dataBytes; // 数据缓冲容量（字节）
      final int code = _regEnumValue(
        key,
        index,
        nameBuf,
        scratch,
        nullptr, // lpReserved 按文档必须为 NULL
        scratch + 1,
        dataBuf,
        scratch + 2,
      );
      if (code == _errorNoMoreItems) break;
      if (code == _errorMoreData) continue; // 单项超长（罕见）跳过，不中断整体枚举
      if (code != _errorSuccess) {
        throw SystemFontCatalogException('读取系统字体注册表失败（错误码 $code）');
      }
      if (scratch[1] != _regSz) continue;
      final String name = _decodeUtf16(nameBuf, scratch[0]);
      final String data = _decodeUtf16(dataBuf.cast<Uint16>(), scratch[2] ~/ 2);
      if (name.isEmpty || data.isEmpty) continue;
      values.add((name: name, data: data));
    }
    return values;
  }

  /// UTF-16 码元缓冲 → 字符串（首个 NUL 截断；surrogate 对按码元原样保留）。
  static String _decodeUtf16(Pointer<Uint16> buffer, int codeUnits) {
    if (codeUnits <= 0) return '';
    final Uint16List units = buffer.asTypedList(codeUnits);
    for (int i = 0; i < units.length; i++) {
      if (units[i] == 0) return String.fromCharCodes(units.take(i));
    }
    return String.fromCharCodes(units);
  }

  Pointer<Uint8> _alloc(int bytes) {
    final Pointer<Uint8> memory = _localAlloc(0, bytes);
    if (memory == nullptr) {
      throw const SystemFontCatalogException('读取系统字体失败（内存分配失败）');
    }
    return memory;
  }
}

// FFI 函数签名（advapi32!RegOpenKeyExW / RegEnumValueW / RegCloseKey；
// kernel32!LocalAlloc / LocalFree）。
typedef _RegOpenKeyExNative = Int32 Function(
  IntPtr hKey,
  Pointer<Uint16> subKey,
  Uint32 options,
  Uint32 desired,
  Pointer<IntPtr> result,
);
typedef _RegOpenKeyExDart = int Function(
  int hKey,
  Pointer<Uint16> subKey,
  int options,
  int desired,
  Pointer<IntPtr> result,
);
typedef _RegEnumValueNative = Int32 Function(
  IntPtr hKey,
  Uint32 index,
  Pointer<Uint16> name,
  Pointer<Uint32> nameLen,
  Pointer<Uint32> reserved,
  Pointer<Uint32> type,
  Pointer<Uint8> data,
  Pointer<Uint32> dataLen,
);
typedef _RegEnumValueDart = int Function(
  int hKey,
  int index,
  Pointer<Uint16> name,
  Pointer<Uint32> nameLen,
  Pointer<Uint32> reserved,
  Pointer<Uint32> type,
  Pointer<Uint8> data,
  Pointer<Uint32> dataLen,
);
typedef _RegCloseKeyNative = Int32 Function(IntPtr hKey);
typedef _RegCloseKeyDart = int Function(int hKey);
typedef _LocalAllocNative = Pointer<Uint8> Function(Uint32 flags, IntPtr bytes);
typedef _LocalAllocDart = Pointer<Uint8> Function(int flags, int bytes);
typedef _LocalFreeNative = Pointer<Uint8> Function(Pointer<Uint8> memory);
typedef _LocalFreeDart = Pointer<Uint8> Function(Pointer<Uint8> memory);
