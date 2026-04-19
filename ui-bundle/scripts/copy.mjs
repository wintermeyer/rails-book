import { cpSync, mkdirSync } from 'node:fs'

mkdirSync('build/bundle', { recursive: true })

for (const dir of ['js', 'img', 'layouts', 'partials', 'helpers']) {
  cpSync(`src/${dir}`, `build/bundle/${dir}`, { recursive: true })
}
