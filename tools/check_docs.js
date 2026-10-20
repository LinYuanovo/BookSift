import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { readAppVersion, renderVersioned } from './render_docs.js'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const version = readAppVersion(root)

function expectRendered(relativePath, templatePath) {
  const template = readFileSync(resolve(root, templatePath), 'utf-8')
  const actual = readFileSync(resolve(root, relativePath), 'utf-8')
  const expected = renderVersioned(template, version)
  if (actual !== expected) {
    throw new Error(
      `${relativePath} 未随 pubspec 版本同步，请运行 node tools/render_docs.js`,
    )
  }
}

expectRendered('README.md', 'docs-content/readme.md.tpl')
expectRendered(
  'website/guide/getting-started.md',
  'docs-content/guide-getting-started.md',
)
console.log(`docs checked at v${version}`)
