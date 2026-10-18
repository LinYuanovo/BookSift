import '../lib/classify/classifier.dart' show PostKind;
import '../lib/classify/src/engine.dart' show entryKindLabel, kRecommendKind;

void main() {
  final List<(String, String)> cases = <(String, String)>[
    ('作者避雷不错', kRecommendKind),
    ('作者的避雷建议不靠谱', PostKind.mine),
    ('作者避雷不错个鬼', PostKind.mine),
    ('不是排雷，是推荐这本', kRecommendKind),
    ('不排雷，而是推荐这本', kRecommendKind),
    ('没有避雷，是来扫书的', PostKind.scan),
    ('反向避雷，安利这本', kRecommendKind),
    ('排雷？不存在的，推荐这本', kRecommendKind),
    ('《某书》不是很雷', PostKind.scan),
    ('排雷《某书》主角降智，慎入', PostKind.mine),
    ('扫书合集', PostKind.scan),
  ];

  for (final (String title, String expected) in cases) {
    final String actual = entryKindLabel(
      category: PostKind.scan,
      flag: 0,
      title: title,
    );
    if (actual != expected) {
      throw StateError('分类错误：$title => $actual，预期 $expected');
    }
    print('OK $title => $actual');
  }
}
