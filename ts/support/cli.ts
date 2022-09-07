#!/usr/bin/env node

import { Command } from 'commander'

import { version as VERSION } from '../package.json'
import { generator } from './generator'
import { runner } from './runner'

const program = new Command()

program
  .name('app-identity-suite-ts')
  .description('Generates or runs app-identity integration test suites in Typescript')
  .version(VERSION)

program
  .command('generate')
  .description('Generates an integration test suite')
  .argument(
    '[suite]',
    'The filename to use for the suite, adding .json if not present',
    'app-identity-suite-ts.json'
  )
  .option('--stdout', 'Prints the suite to standard output instead of saving it')
  .option('-q, --quiet', 'Silences diagnostic messages')
  .action(generator(program))

program
  .command('run')
  .description('Runs one or more integration suites')
  .argument('[paths...]', 'The filenames or directories containing the suites to be run')
  .option('-S, --strict', 'Runs in strict mode; optional tests will cause failure')
  .option('--stdin', 'Reads a suite from stdin')
  .option('-D, --diagnostic', 'Enables output diagnostics')
  .action(runner(program))

program.parse(process.argv)
