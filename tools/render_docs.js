import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const toolsDir = dirname(fileURLToPath(import.meta.url))
const defaultRoot = resolve(toolsDir, '..')

export function readAppVersion(root = defaultRoot) {
  const pubspec = readFileSync(resolve(root, 'app/pubspec.yaml'), 'utf-8')
  const match = pubspec.match(/^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$/m)
  if (!match) throw new Error('无法从 app/pubspec.yaml 解析 version')
  return match[1]
}

export function renderVersioned(source, version = readAppVersion()) {
  return source.replaceAll('{{version}}', version)
}

function renderFile(root, relativePath, templatePath, version) {
  const template = readFileSync(resolve(root, templatePath), 'utf-8')
  writeFileSync(
    resolve(root, relativePath),
    renderVersioned(template, version),
    'utf-8',
  )
}

if (
  process.argv[1] &&
  pathToFileURL(resolve(process.argv[1])).href === import.meta.url
) {
  const root = process.env.BOOKSIFT_DOC_ROOT
    ? resolve(process.env.BOOKSIFT_DOC_ROOT)
    : defaultRoot
  const version = readAppVersion(root)
  renderFile(root, 'README.md', 'docs-content/readme.md.tpl', version)
  renderFile(
    root,
    'website/guide/getting-started.md',
    'docs-content/guide-getting-started.md',
    version,
  )
  console.log(`docs rendered at v${version}`)
}
