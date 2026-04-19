import { rmSync, mkdirSync } from 'node:fs'

rmSync('build', { recursive: true, force: true })
mkdirSync('build/bundle/css', { recursive: true })
