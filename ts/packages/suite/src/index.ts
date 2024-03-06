#!/usr/bin/env node

import { Command } from '@commander-js/extra-typings'

import { version as VERSION } from '../package.json'
import { generator } from './generator.js'
import { runner } from './runner.js'

const program = new Command()

program
  .name('app-identity-suite-ts')
  .description('Generates or runs app-identity integration test suites in Typescript')
  .version(VERSION)
  .addCommand(generator)
  .addCommand(runner)

program.parse(process.argv)
