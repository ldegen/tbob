module.exports = ->
  @factory "Adresse", ->
    @attr "strasse"
      .type @optional @string
      .fill "In der Pampa"

  @factory "AdresseES_broken", ->
    @extend "Adresse"
    @meta derived:true
    @attr "_sort"
      .type @optional @string
      .fill ["strasse"], (s)->s?.toLowerCase()

  @factory "AdresseES_fixed", ->
    @extend "Adresse"
    @attr "_sort"
      .type @optional @string
      .derive ["strasse"], (s)->s?.toLowerCase()
