import 'dart:io';
import 'dart:typed_data';

import 'package:booksift/core/fonts/font_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

// SFNT name 表解析：系统字体选择/“我的字体”显示家族名，而不是文件名。

typedef _NameRecord = ({int platform, int encoding, int language, int nameId, String text});

void _u16(BytesBuilder out, int value) {
  out.add(<int>[(value >> 8) & 0xFF, value & 0xFF]);
}

void _u32(BytesBuilder out, int value) {
  out.add(<int>[(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF]);
}

Uint8List _utf16Be(String value) {
  final Uint8List out = Uint8List(value.length * 2);
  for (int i = 0; i < value.length; i++) {
    final int unit = value.codeUnitAt(i);
    out[i * 2] = (unit >> 8) & 0xFF;
    out[i * 2 + 1] = unit & 0xFF;
  }
  return out;
}

Uint8List _nameTable(List<_NameRecord> records) {
  final BytesBuilder strings = BytesBuilder();
  final BytesBuilder recordBytes = BytesBuilder();
  int stringOffset = 0;
  for (final _NameRecord r in records) {
    final Uint8List bytes = _utf16Be(r.text);
    _u16(recordBytes, r.platform);
    _u16(recordBytes, r.encoding);
    _u16(recordBytes, r.language);
    _u16(recordBytes, r.nameId);
    _u16(recordBytes, bytes.length);
    _u16(recordBytes, stringOffset);
    strings.add(bytes);
    stringOffset += bytes.length;
  }
  final BytesBuilder out = BytesBuilder();
  _u16(out, 0); // format
  _u16(out, records.length);
  _u16(out, 6 + records.length * 12); // stringOffset
  out.add(recordBytes.toBytes());
  out.add(strings.toBytes());
  return out.toBytes();
}

Uint8List _sfnt(List<_NameRecord> records) {
  final Uint8List name = _nameTable(records);
  final BytesBuilder out = BytesBuilder();
  _u32(out, 0x00010000); // sfnt version
  _u16(out, 1); // numTables
  _u16(out, 0);
  _u16(out, 0);
  _u16(out, 0);
  _u32(out, 0x6E616D65); // 'name'
  _u32(out, 0);
  _u32(out, 28); // table offset
  _u32(out, name.length);
  out.add(name);
  return out.toBytes();
}

Uint8List _ttc(Uint8List font) {
  final BytesBuilder out = BytesBuilder();
  _u32(out, 0x74746366); // 'ttcf'
  _u32(out, 0x00010000);
  _u32(out, 1); // numFonts
  _u32(out, 16); // first face offset
  out.add(font);
  final Uint8List ttc = out.toBytes();
  // TTC 内 table record 的 offset 以文件起点计；测试构造时把 font 内的 28 改成 16+28。
  final ByteData view = ByteData.sublistView(ttc);
  view.setUint32(36, 16 + 28, Endian.big);
  return ttc;
}

void main() {
  test('优先返回中文本地化家族名（华文宋体，而非 STSong）', () async {
    final Uint8List font = _sfnt(<_NameRecord>[
      (platform: 3, encoding: 1, language: 0x0409, nameId: 1, text: 'STSong'),
      (platform: 3, encoding: 1, language: 0x0804, nameId: 1, text: '华文宋体'),
    ]);
    expect(await FontMetadata.familyNameOfBytes(font), '华文宋体');
  });

  test('typographic family（nameID 16）优先于 family（nameID 1）', () async {
    final Uint8List font = _sfnt(<_NameRecord>[
      (platform: 3, encoding: 1, language: 0x0409, nameId: 1, text: 'Source Han Serif CN'),
      (platform: 3, encoding: 1, language: 0x0409, nameId: 16, text: 'Source Han Serif'),
    ]);
    expect(await FontMetadata.familyNameOfBytes(font), 'Source Han Serif');
  });

  test('TTC 取第一个 face 的家族名', () async {
    final Uint8List font = _sfnt(<_NameRecord>[
      (platform: 3, encoding: 1, language: 0x0409, nameId: 1, text: 'PingFang SC'),
    ]);
    expect(await FontMetadata.familyNameOfBytes(_ttc(font)), 'PingFang SC');
  });

  test('坏字节 / 无 name 表 → null；文件名兜底只去路径和扩展名', () async {
    expect(await FontMetadata.familyNameOfBytes(Uint8List.fromList(<int>[1, 2, 3, 4])), isNull);
    expect(FontMetadata.fallbackFamilyName(r'C:\Windows\Fonts\STSONG.TTF'), 'STSONG');
    expect(FontMetadata.fallbackFamilyName('/System/Library/Fonts/PingFang.ttc'), 'PingFang');
  });

  test('真实 STSONG.TTF（存在时）解析为「华文宋体」，不是文件名 STSONG', () async {
    if (!Platform.isWindows) return;
    final File file = File(r'C:\Windows\Fonts\STSONG.TTF');
    if (!await file.exists()) return;
    expect(await FontMetadata.familyNameOfFile(file), contains('华文宋体'));
  });
}
