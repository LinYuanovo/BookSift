import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// SFNT 字体元数据读取（TrueType / OpenType / TrueType Collection 的最小实现）。
///
/// 只解析 `name` 表里的字体家族名，目标是让系统字体列表和“我的字体”显示
/// “华文宋体”而不是文件名 `STSONG`。不引入第三方字体解析依赖。
abstract final class FontMetadata {
  /// 读取字体文件里的家族名；文件损坏、无 `name` 表或解码失败 → null。
  static Future<String?> familyNameOfFile(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      return await _Parser(_FileByteSource(handle)).familyName();
    } catch (_) {
      return null;
    } finally {
      try {
        await handle?.close();
      } catch (_) {
        // 读取失败路径不覆盖原始结果。
      }
    }
  }

  /// 从内存字节解析家族名（测试 / 已读入的字体共用）。
  static Future<String?> familyNameOfBytes(Uint8List bytes) =>
      _Parser(_MemoryByteSource(bytes)).familyName();

  /// 解析失败时的兜底名：文件名去扩展名（非路径语义）。
  static String fallbackFamilyName(String pathOrFileName) {
    final String fileName = pathOrFileName.split(RegExp(r'[\\/]')).last;
    final int dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }
}

abstract interface class _ByteSource {
  Future<Uint8List> read(int offset, int length);
}

final class _MemoryByteSource implements _ByteSource {
  const _MemoryByteSource(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> read(int offset, int length) async {
    if (offset < 0 || length <= 0 || offset >= bytes.length) {
      return Uint8List(0);
    }
    final int end = math.min(bytes.length, offset + length);
    return Uint8List.sublistView(bytes, offset, end);
  }
}

final class _FileByteSource implements _ByteSource {
  const _FileByteSource(this.handle);

  final RandomAccessFile handle;

  @override
  Future<Uint8List> read(int offset, int length) async {
    if (offset < 0 || length <= 0) return Uint8List(0);
    final int fileLength = await handle.length();
    if (offset >= fileLength) return Uint8List(0);
    final int want = math.min(length, fileLength - offset);
    await handle.setPosition(offset);
    final Uint8List out = Uint8List(want);
    int read = 0;
    while (read < want) {
      final Uint8List chunk = await handle.read(want - read);
      if (chunk.isEmpty) break;
      out.setRange(read, read + chunk.length, chunk);
      read += chunk.length;
    }
    return read == out.length ? out : Uint8List.sublistView(out, 0, read);
  }
}

final class _Parser {
  const _Parser(this.source);

  final _ByteSource source;

  /// SFNT 家族名：优先 typographic family（nameID 16），其次 family（nameID 1）；
  /// 同名字段里优先 Windows 中文（0x0804），再退 Windows 英文 / Unicode / Mac。
  Future<String?> familyName() async {
    final Uint8List header = await source.read(0, 12);
    if (header.length < 12) return null;

    int faceOffset = 0;
    final int signature = _u32(header, 0);
    if (signature == 0x74746366) {
      // 'ttcf'：取第一个 face 的家族名（TTC 内多个 face 的简化口径）。
      final Uint8List ttc = await source.read(8, 8);
      if (ttc.length < 8) return null;
      final int fontCount = _u32(ttc, 0); // TTC header.numFonts 为 32 位
      if (fontCount < 1) return null;
      faceOffset = _u32(ttc, 4);
    } else if (signature != 0x00010000 &&
        signature != 0x4F54544F && // OTTO
        signature != 0x74727565 && // true
        signature != 0x74797031) { // typ1
      return null;
    }

    final Uint8List face = await source.read(faceOffset, 12);
    if (face.length < 12) return null;
    final int tableCount = _u16(face, 4);
    if (tableCount <= 0 || tableCount > 512) return null;

    final Uint8List records = await source.read(faceOffset + 12, tableCount * 16);
    if (records.length < tableCount * 16) return null;

    int? nameOffset;
    int? nameLength;
    for (int i = 0; i < tableCount; i++) {
      final int base = i * 16;
      if (_u32(records, base) == 0x6E616D65) { // 'name'
        nameOffset = _u32(records, base + 8);
        nameLength = _u32(records, base + 12);
        break;
      }
    }
    if (nameOffset == null || nameLength == null || nameLength <= 0) {
      return null;
    }

    // 名称表通常几 KB；设上限防止损坏文件带入超大读取。
    final Uint8List table = await source.read(nameOffset, math.min(nameLength, 1 << 20));
    return _parseNameTable(table);
  }

  static String? _parseNameTable(Uint8List data) {
    if (data.length < 6) return null;
    final int count = _u16(data, 2);
    final int stringOffset = _u16(data, 4);
    if (count <= 0 || count > 1024) return null;

    String? best;
    int bestScore = -1;
    for (int i = 0; i < count; i++) {
      final int base = 6 + i * 12;
      if (base + 12 > data.length) break;
      final int platform = _u16(data, base);
      final int encoding = _u16(data, base + 2);
      final int language = _u16(data, base + 4);
      final int nameId = _u16(data, base + 6);
      if (nameId != 1 && nameId != 16) continue;
      final int length = _u16(data, base + 8);
      final int offset = _u16(data, base + 10);
      final int start = stringOffset + offset;
      if (length <= 0 || start < 0 || start + length > data.length) continue;

      final String? decoded = _decode(
        platform,
        encoding,
        Uint8List.sublistView(data, start, start + length),
      );
      final String clean = _clean(decoded);
      if (clean.isEmpty) continue;

      int score = nameId == 16 ? 100 : 80;
      if (platform == 3) {
        score += language == 0x0804 ? 60 : (language == 0x0409 ? 35 : 30);
      } else if (platform == 0) {
        score += 20;
      } else if (platform == 1) {
        score += 10;
      }
      if (RegExp(r'[\u3400-\u9FFF]').hasMatch(clean)) score += 25;
      if (clean.length > 80) score -= 10;

      if (score > bestScore) {
        bestScore = score;
        best = clean;
      }
    }
    return best;
  }

  static String? _decode(int platform, int encoding, Uint8List bytes) {
    try {
      if (platform == 3 || platform == 0) {
        return _decodeUtf16Be(bytes);
      }
      if (platform == 1 || platform == 2) {
        // MacRoman / ISO-8859-1：家族名绝大多数为 ASCII；非 ASCII 由 UTF-16
        // 的 Windows/Unicode 记录优先覆盖，故这里用单字节映射兜底即可。
        return String.fromCharCodes(bytes);
      }
      return _decodeUtf16Be(bytes);
    } catch (_) {
      return null;
    }
  }

  static String _decodeUtf16Be(Uint8List bytes) {
    final int units = bytes.length ~/ 2;
    final Uint16List codeUnits = Uint16List(units);
    for (int i = 0; i < units; i++) {
      codeUnits[i] = (bytes[i * 2] << 8) | bytes[i * 2 + 1];
    }
    return String.fromCharCodes(codeUnits);
  }

  static String _clean(String? value) {
    if (value == null) return '';
    return value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

int _u16(Uint8List data, int offset) => (data[offset] << 8) | data[offset + 1];

int _u32(Uint8List data, int offset) =>
    (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
