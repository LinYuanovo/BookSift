import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:booksift/core/fonts/font_ports.dart';
import 'package:booksift/core/fonts/font_registry.dart';
import 'package:booksift/core/fonts/font_service.dart';
import 'package:booksift/core/fonts/font_tokens.dart';

// ── 手写 fake（端口依赖倒置：不触 drift / file_picker / dart:ui / 文件系统）──

class FakeSettingsStore implements FontSettingsStore {
  final Map<String, String> data = <String, String>{};
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('db down');
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('db down');
    data[key] = value;
  }
}

class FakeFileStore implements FontFileStore {
  final Map<String, Uint8List> files = <String, Uint8List>{};
  int reads = 0;
  bool failWrites = false;

  @override
  Future<Uint8List> read(String fileName) async {
    reads++;
    final Uint8List? bytes = files[fileName];
    if (bytes == null) throw StateError('missing file: $fileName');
    return bytes;
  }

  @override
  Future<void> write(String fileName, Uint8List bytes) async {
    if (failWrites) throw StateError('disk full');
    files[fileName] = bytes;
  }

  @override
  Future<void> delete(String fileName) async => files.remove(fileName);
}

class FakeRegistrar implements FontRegistrar {
  final List<String> loaded = <String>[];
  bool failAll = false;
  String? failFamily;

  @override
  Future<void> registerFamily(String familyName, Uint8List bytes) async {
    if (failAll || familyName == failFamily) throw StateError('engine rejected font');
    loaded.add(familyName);
  }
}

class FakePicker implements FontFilePicker {
  PickedFontFile? next;
  int picks = 0;

  @override
  Future<PickedFontFile?> pickFontFile() async {
    picks++;
    return next;
  }
}

Uint8List fakeBytes() => Uint8List.fromList(List<int>.filled(16, 7));

ImportedFont sampleFont({String fontId = 'f1', String familyName = 'MySerif', String fileName = 'MySerif.ttf'}) =>
    ImportedFont(fontId: fontId, familyName: familyName, fileName: fileName, importedAt: DateTime.utc(2026, 10, 13));

({FontService service, FakeSettingsStore store, FakeFileStore files, FakeRegistrar registrar, FakePicker picker})
buildService() {
  final FakeSettingsStore store = FakeSettingsStore();
  final FakeFileStore files = FakeFileStore();
  final FakeRegistrar registrar = FakeRegistrar();
  final FakePicker picker = FakePicker();
  final FontService service = FontService(settings: store, picker: picker, registrar: registrar, files: files);
  return (service: service, store: store, files: files, registrar: registrar, picker: picker);
}

/// 预置一个已导入字体（注册表 + 落盘文件）。
void seedFont(FakeSettingsStore store, FakeFileStore files, {List<ImportedFont> fonts = const <ImportedFont>[]}) {
  store.data[FontSettingsKeys.registry] = FontRegistryCodec.encode(
    fonts.isEmpty ? <ImportedFont>[sampleFont()] : fonts,
  );
  for (final ImportedFont f in fonts.isEmpty ? <ImportedFont>[sampleFont()] : fonts) {
    files.files[f.storedName] = fakeBytes();
  }
}

void main() {
  group('bootstrap（启动加载）', () {
    test('空配置：families = standard，零字体文件读取、零引擎注册（默认启动零加载）', () async {
      final b = buildService();
      await b.service.bootstrap();
      expect(b.service.families, FontFamilySet.standard);
      expect(b.registrar.loaded, isEmpty);
      expect(b.files.reads, 0);
      expect(b.service.registry, isEmpty);
      for (final FontRole role in FontRole.values) {
        expect(b.service.slotOf(role), const FontSlot.system());
      }
      b.service.dispose();
    });

    test('注册表 + 角色槽：加载字体并按槽解析 family', () async {
      final b = buildService();
      seedFont(b.store, b.files);
      b.store.data[FontSettingsKeys.roles] = '{"display":"imported:f1","body":"system","mono":"imported:f1"}';
      await b.service.bootstrap();
      expect(b.registrar.loaded, <String>['MySerif']);
      expect(b.service.families.display, 'MySerif');
      expect(b.service.families.body, isNull);
      expect(b.service.families.mono, 'MySerif');
      expect(b.service.families.title, isNull);
      expect(b.service.slotOf(FontRole.display), const FontSlot.imported('f1'));
      b.service.dispose();
    });

    test('槽引用不存在的 fontId：该角色回退 system，其余角色不受影响', () async {
      final b = buildService();
      b.store.data[FontSettingsKeys.roles] = '{"display":"imported:ghost","title":"imported:f1"}';
      await b.service.bootstrap();
      expect(b.service.families.display, isNull);
      expect(b.service.families.title, isNull, reason: 'f1 不在注册表 → system');
      expect(b.service.families.mono, FontFamily.monospace);
      b.service.dispose();
    });

    test('字体文件缺失：跳过加载并回退，不抛异常', () async {
      final b = buildService();
      seedFont(b.store, b.files);
      b.files.files.clear(); // 文件丢失
      b.store.data[FontSettingsKeys.roles] = '{"display":"imported:f1"}';
      await b.service.bootstrap();
      expect(b.registrar.loaded, isEmpty);
      expect(b.service.families.display, isNull);
      expect(b.service.registry.length, 1, reason: '注册表保留，文件找回后下次启动可恢复');
      b.service.dispose();
    });

    test('引擎注册失败：降级 system，不抛异常', () async {
      final b = buildService();
      seedFont(b.store, b.files);
      b.registrar.failAll = true;
      b.store.data[FontSettingsKeys.roles] = '{"display":"imported:f1"}';
      await b.service.bootstrap();
      expect(b.service.families.display, isNull);
      expect(b.service.families, FontFamilySet.standard);
      b.service.dispose();
    });

    test('settings 读取抛错（DB 故障）：整体降级 standard，不阻塞启动', () async {
      final b = buildService();
      seedFont(b.store, b.files);
      b.store.failReads = true;
      await b.service.bootstrap();
      expect(b.service.families, FontFamilySet.standard);
      expect(b.service.registry, isEmpty);
      b.service.dispose();
    });

    test('坏 JSON：注册表/槽位解码降级为空', () async {
      final b = buildService();
      b.store.data[FontSettingsKeys.registry] = '{broken';
      b.store.data[FontSettingsKeys.roles] = '[1,2,3]';
      await b.service.bootstrap();
      expect(b.service.registry, isEmpty);
      expect(b.service.families, FontFamilySet.standard);
      b.service.dispose();
    });
  });

  group('导入流程（mock FilePicker / FontLoader 端口）', () {
    test('成功：落盘 <fontId>.ttf → 注册引擎 → 注册表持久化', () async {
      final b = buildService();
      await b.service.bootstrap();
      b.picker.next = PickedFontFile(fileName: 'Kaiti.ttf', bytes: fakeBytes());
      final String? error = await b.service.importPickedFont();
      expect(error, isNull);
      expect(b.service.registry.length, 1);
      final ImportedFont font = b.service.registry.single;
      expect(font.familyName, 'Kaiti');
      expect(font.fileName, 'Kaiti.ttf');
      expect(font.storedName, '${font.fontId}.ttf');
      expect(b.files.files.keys, <String>[font.storedName]);
      expect(b.registrar.loaded, <String>['Kaiti']);
      // 持久化 JSON 含四字段
      final List<dynamic> persisted = jsonDecode(b.store.data[FontSettingsKeys.registry]!) as List<dynamic>;
      expect(persisted.length, 1);
      final Map<String, dynamic> json = persisted.first as Map<String, dynamic>;
      expect(json['fontId'], font.fontId);
      expect(json['familyName'], 'Kaiti');
      expect(json['fileName'], 'Kaiti.ttf');
      expect(DateTime.tryParse(json['importedAt'] as String), isNotNull);
      // 新导入字体立即可被槽引用
      expect(await b.service.setRoleSlot(FontRole.body, FontSlot.imported(font.fontId)), isNull);
      expect(b.service.families.body, 'Kaiti');
      b.service.dispose();
    });

    test('otf 扩展名同样接受', () async {
      final b = buildService();
      await b.service.bootstrap();
      expect(await b.service.importFontBytes('SourceSerif.otf', fakeBytes()), isNull);
      expect(b.service.registry.single.storedName, endsWith('.otf'));
      b.service.dispose();
    });

    test('用户取消选择：无副作用、不算错误', () async {
      final b = buildService();
      await b.service.bootstrap();
      b.picker.next = null;
      expect(await b.service.importPickedFont(), isNull);
      expect(b.picker.picks, 1);
      expect(b.service.registry, isEmpty);
      expect(b.files.files, isEmpty);
      b.service.dispose();
    });

    test('非 ttf/otf：拒绝且不落盘不注册', () async {
      final b = buildService();
      await b.service.bootstrap();
      final String? error = await b.service.importFontBytes('evil.zip', fakeBytes());
      expect(error, isNotNull);
      expect(b.service.registry, isEmpty);
      expect(b.files.files, isEmpty);
      expect(b.registrar.loaded, isEmpty);
      b.service.dispose();
    });

    test('空字节：拒绝', () async {
      final b = buildService();
      await b.service.bootstrap();
      expect(await b.service.importFontBytes('Empty.ttf', Uint8List(0)), isNotNull);
      expect(b.service.registry, isEmpty);
      b.service.dispose();
    });

    test('同名字体：拒绝二次导入', () async {
      final b = buildService();
      await b.service.bootstrap();
      expect(await b.service.importFontBytes('Kaiti.ttf', fakeBytes()), isNull);
      final String? error = await b.service.importFontBytes('Kaiti.ttf', fakeBytes());
      expect(error, contains('Kaiti'));
      expect(b.service.registry.length, 1);
      b.service.dispose();
    });

    test('引擎加载失败：报错并回滚已落盘文件，注册表不变', () async {
      final b = buildService();
      await b.service.bootstrap();
      b.registrar.failAll = true;
      final String? error = await b.service.importFontBytes('Broken.ttf', fakeBytes());
      expect(error, isNotNull);
      expect(b.files.files, isEmpty, reason: '落盘文件应回滚');
      expect(b.service.registry, isEmpty);
      b.service.dispose();
    });

    test('落盘失败：报错且不注册引擎', () async {
      final b = buildService();
      await b.service.bootstrap();
      b.files.failWrites = true;
      expect(await b.service.importFontBytes('NoDisk.ttf', fakeBytes()), isNotNull);
      expect(b.registrar.loaded, isEmpty);
      expect(b.service.registry, isEmpty);
      b.service.dispose();
    });
  });

  group('角色槽配置', () {
    test('setRoleSlot：解析生效 + fonts.roles 持久化 + 通知监听器', () async {
      final b = buildService();
      seedFont(b.store, b.files);
      await b.service.bootstrap();
      int notifications = 0;
      b.service.addListener(() => notifications++);
      expect(await b.service.setRoleSlot(FontRole.display, const FontSlot.imported('f1')), isNull);
      expect(b.service.families.display, 'MySerif');
      expect(notifications, 1);
      final Map<String, dynamic> roles = jsonDecode(b.store.data[FontSettingsKeys.roles]!) as Map<String, dynamic>;
      expect(roles['display'], 'imported:f1');
      // 回 system：键移除
      expect(await b.service.setRoleSlot(FontRole.display, const FontSlot.system()), isNull);
      expect(b.service.families.display, isNull);
      final Map<String, dynamic> roles2 = jsonDecode(b.store.data[FontSettingsKeys.roles]!) as Map<String, dynamic>;
      expect(roles2.containsKey('display'), isFalse);
      b.service.dispose();
    });

    test('setRoleSlot 未知 fontId：防御性视为 system', () async {
      final b = buildService();
      await b.service.bootstrap();
      expect(await b.service.setRoleSlot(FontRole.body, const FontSlot.imported('ghost')), isNull);
      expect(b.service.families.body, isNull);
      expect(b.service.slotOf(FontRole.body), const FontSlot.system());
      b.service.dispose();
    });

    test('十角色覆盖往返：全部指到导入字体 → 编码/解码无损 → resetRoles 回默认', () async {
      final b = buildService();
      seedFont(b.store, b.files);
      await b.service.bootstrap();
      for (final FontRole role in FontRole.values) {
        await b.service.setRoleSlot(role, const FontSlot.imported('f1'));
      }
      for (final FontRole role in FontRole.values) {
        expect(b.service.families.familyOf(role), 'MySerif', reason: '${role.name} 应解析到导入家族');
        expect(b.service.slotOf(role), const FontSlot.imported('f1'));
      }
      // 持久化往返：decode(encode(slots)) 与原槽一致
      final Map<FontRole, FontSlot> decoded = FontRoleSlotsCodec.decode(b.store.data[FontSettingsKeys.roles]);
      expect(decoded, <FontRole, FontSlot>{for (final FontRole r in FontRole.values) r: const FontSlot.imported('f1')});
      // 恢复默认
      expect(await b.service.resetRoles(), isNull);
      expect(b.service.families, FontFamilySet.standard);
      expect(FontRoleSlotsCodec.decode(b.store.data[FontSettingsKeys.roles]), isEmpty);
      b.service.dispose();
    });

    test('注册表编解码往返：字段无损、坏条目跳过', () {
      final List<ImportedFont> fonts = <ImportedFont>[
        sampleFont(),
        sampleFont(fontId: 'f2', familyName: 'Kaiti', fileName: 'Kaiti.otf'),
      ];
      final String raw = FontRegistryCodec.encode(fonts);
      expect(FontRegistryCodec.decode(raw), fonts);
      expect(FontRegistryCodec.decode(null), isEmpty);
      expect(FontRegistryCodec.decode('null'), isEmpty);
      // 混入坏条目：好条目保留
      final List<dynamic> mixed = <dynamic>[
        ...(jsonDecode(raw) as List<dynamic>),
        <String, dynamic>{'fontId': '', 'familyName': 'x', 'fileName': 'x.ttf'},
        'garbage',
      ];
      expect(FontRegistryCodec.decode(jsonEncode(mixed)), fonts);
    });
  });

  group('删除字体', () {
    test('引用它的角色自动回退 system（mono 回平台等宽族），文件删除、注册表持久化', () async {
      final b = buildService();
      seedFont(b.store, b.files);
      b.store.data[FontSettingsKeys.roles] = '{"display":"imported:f1","mono":"imported:f1","body":"imported:f1"}';
      await b.service.bootstrap();
      expect(b.service.families.display, 'MySerif');
      expect(await b.service.deleteFont('f1'), isNull);
      expect(b.service.registry, isEmpty);
      expect(b.files.files, isEmpty);
      expect(b.service.families.display, isNull);
      expect(b.service.families.body, isNull);
      expect(b.service.families.mono, FontFamily.monospace, reason: 'mono 的 system 值 = 平台等宽族');
      expect(FontRegistryCodec.decode(b.store.data[FontSettingsKeys.registry]), isEmpty);
      expect(FontRoleSlotsCodec.decode(b.store.data[FontSettingsKeys.roles]), isEmpty);
      b.service.dispose();
    });

    test('未引用任何角色时也可删除', () async {
      final b = buildService();
      seedFont(b.store, b.files);
      await b.service.bootstrap();
      expect(await b.service.deleteFont('f1'), isNull);
      expect(b.service.families, FontFamilySet.standard);
      b.service.dispose();
    });

    test('删除不存在的 fontId：报错且状态不变', () async {
      final b = buildService();
      seedFont(b.store, b.files);
      await b.service.bootstrap();
      expect(await b.service.deleteFont('ghost'), '字体不存在');
      expect(b.service.registry.length, 1);
      b.service.dispose();
    });
  });

  group('持久化失败降级', () {
    test('写失败：返回错误消息，但内存状态生效并通知（UI 不假死）', () async {
      final b = buildService();
      seedFont(b.store, b.files);
      await b.service.bootstrap();
      b.store.failWrites = true;
      int notifications = 0;
      b.service.addListener(() => notifications++);
      final String? error = await b.service.setRoleSlot(FontRole.display, const FontSlot.imported('f1'));
      expect(error, isNotNull);
      expect(b.service.families.display, 'MySerif');
      expect(notifications, 1);
      b.service.dispose();
    });
  });
}
