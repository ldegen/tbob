Cli = require "./cli"
Transform = require "./bob-transform"
cli = Cli process
cli.input
  .pipe Transform cli.world
  .pipe cli.output
