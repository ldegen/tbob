Cli = require "./cli"
Transform = require "./bob-transform"
cli = Cli process
cli.input
  .pipe Transform cli.world, cli.transformOptions
  .pipe cli.output
