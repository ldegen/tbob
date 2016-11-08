Cli = require "./cli"
Transform = require "./bob-transform"
Cli process
  .pipeline()
  .reduce (a,b)->a.pipe b
