import fs from 'node:fs';
import path from 'node:path';

const directory = process.argv[2] ?? 'build/acceptance/wechat';
const escapeHtml = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const plan = fs.readFileSync('../docs-content/import-reviews-plan.md', 'utf8');
const urls = plan.split('\n').filter(line => line.startsWith('- https://mp.weixin.qq.com/s/')).map(line => line.slice(2));

for (let index = 1; index <= 4; index++) {
  const capture = fs.readFileSync(path.join(directory, `sample-${index}-rendered.txt`), 'utf8');
  const start = capture.indexOf('{');
  const end = capture.indexOf('\n###', start);
  const article = JSON.parse(capture.slice(start, end < 0 ? undefined : end));
  const staticHtml = fs.readFileSync(path.join(directory, `sample-${index}.html`), 'utf8');
  const published = staticHtml.match(/\bcreate_time\s*[:=]\s*['"](\d{4}-\d{2}-\d{2})/)?.[1] ?? '';
  const document = `<!doctype html><html><head><meta charset="utf-8"><link rel="canonical" href="${urls[index - 1]}"><title>${escapeHtml(article.title)}</title></head><body><h1 id="activity-name">${escapeHtml(article.title)}</h1><span id="js_name">${escapeHtml(article.author)}</span><time id="publish_time">${published}</time><div id="js_content">${article.html}</div></body></html>`;
  fs.writeFileSync(path.join(directory, `sample-${index}-complete.html`), document);
  console.log(JSON.stringify({sample: index, title: article.title, date: published, visibleImages: article.images, sourceBytes: Buffer.byteLength(document)}));
}
