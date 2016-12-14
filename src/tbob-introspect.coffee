module.exports = (world)->(baseName, traitNames...)->
  world
    .sequence baseName, traitNames
    .type()
    .describe()
