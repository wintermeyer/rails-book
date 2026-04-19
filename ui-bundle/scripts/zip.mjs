import { createWriteStream } from 'node:fs'
import archiver from 'archiver'

const out = createWriteStream('build/ui-bundle.zip')
const archive = archiver('zip', { zlib: { level: 9 } })

out.on('close', () => {
  const kb = (archive.pointer() / 1024).toFixed(1)
  console.log(`ui-bundle.zip: ${kb} KB`)
})

archive.on('error', (err) => { throw err })
archive.pipe(out)
archive.directory('build/bundle/', false)
await archive.finalize()
