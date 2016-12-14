Cli = require "./cli"
Transform = require "./tbob-transform"
Cli process
  .pipeline()
  .reduce (a,b)->a.pipe b
