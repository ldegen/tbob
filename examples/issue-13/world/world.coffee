module.exports = ->
  @factory "Adresse", ->
    @attr "strasse"
      .type @optional @string
      .fill "In der Pampa"

  @factory "AdresseES", ->
    @extend "Adresse"
    @meta derived: true
    @attr "_sort"
      .type @optional @string
      .fill ["strasse"], (s)->s?.toLowerCase()
