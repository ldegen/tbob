b = Trait
  attributes: foo: type: opaqueT()

t = Trait 
  alias: "con"
  attributes:
    head: type: opaqueT()
    tail: 
      type: (w)->optionalT w
      traits: ["con", b]

s = Trait
  alias: "con"
  attributes:
    head: type: scalarT()
    tail: 
      type: (w)->optionalT w
      traits: ["con"]
  foo: type: opaqueT()

tA = Trait
  .sequence [t]
  .type()

tB = Trait
  .sequence [s]
  .type()

expect(tA.contains tB).to.be.true

#####################################

@factory "con", ->
  @attr "head"
  @attr "tail", @optional "con", "b"

@trait "b", ->
  @attr "foo"

@factory "con+", ->
  @attr "head"
  @attr "tail", @optional "con+"

@factory "doc0", ->
  @attr "seq", "con"
  @trait "+", ->
    @attr "seq", "con+"
