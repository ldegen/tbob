# 1 A trait is a set of attribute definitions.

Trait = require "../src/trait"
Attribute = require "../src/attribute"
{Factory} = require "rosie"

{optionalT, opaqueT, scalarT} = Type = require "../src/type"
describe "A Trait", ->

  
  f=undefined
  beforeEach ->
    f = new Factory()


  it "describes attributes that can be applied to factories", ->
    t=Trait attributes:
      bang: 
        fill: ->42
      bum:
        fill: (bang)->2*bang
        deps:["bang"]
    t.apply f
    expect(f.build()).to.eql
      bang: 42
      bum: 84

  it "has an unique identifier", ->
    t = Trait()
    expect(t.id()).to.be.a "number"


describe "A application sequence", ->
  a=b=c=d=e=undefined

  beforeEach ->
    a = Trait deps: [], alias:'a'
    b = Trait deps: [a], alias: 'b'
    c = Trait deps: [a,b], alias: 'c'
    d = Trait deps: [a], alias: 'd'
    e = Trait deps: [], alias: 'e'
  
  it "contains the net dependencies of a sequence of traits in topological order", ->
    s=Trait.sequence [b,e,d,c]
    expect(s.traits).to.eql [a,b,e,d,c]
      

  it "is only valid if all dependency and ordering constraints can be fulfilled without closing a cycle", ->
    c_ = Trait deps: [b,a], alias: 'c_'
    mistake = ->Trait.sequence [b,e,d,c_]
    expect(mistake).to.throw

  it "can detect unsafe attribute overrides", ->
    a = Trait attributes:
      foo:type: scalarT "string"
      bar:type: opaqueT
    b = Trait attributes:
      foo:type: scalarT "number"
      bar:type: scalarT "number"
    s = Trait.sequence [a,b]
    expect(s.unsafeOverrides()).to.eql [
      ['foo',a,b]
    ]
    

#
# 2 A factory is defined by taking an empty factory and applying a sequence of traits.
# 2.1 Applying a trait to a factory means adding the traits attributes to the factory.
# 2.2 In the process of adding an attribute, any previously registered attribute with the same name
#     is overwritten.
# 2.3 Overriding an existing attribute is considered *save* if the new attribute is a specialization
#     of the existing one. (see below)
# 2.4 Any sequence of traits is a *type* if
# 2.4.a applying the traits would not result in any *unsafe* override and
# 2.4.b the resulting set of attributes is closed under the attribute dependency relation
#
# A type is a class (as in set-theory) of values. Or rather: it is a predicate over values.
# In our domain, we only consider predicates of one of the following forms:
#
#   a) The value is opaque, meaning: we don't know or care about its structure
#
#   b) The value is of some scalar type (string, boolean, numnber).
#
#   c) The value is a document with *at least* the following attributes: a1, a2, ..., an.
#      Each attribute is a pair (name_i, type_i) with name_i != name_j for i!=j.
#      The value for attribute a_i is consistent with type_i.
#
#   d) The value is a dictionary and all entries are of type t.
#
#   e) The value is a list and all elements are of type t.
#
#   f) The value is of a given type, or it is nil (i.e. absent).
#   
#   g) The value is nil (i.e.: absent).
#
# There are types that are impossible to fulfill (at least by a finite value).
# We simply use ⊥ to refer to any of these types.

# Or much rather: it is a predicate over
# documents. We only consider certain types of types, though
#
# - scalar types:
#
# our type is a conjunction
# of statements of the form: The document contains an attribute "foo" of type "bar".
#
# 3. Type Extensions and Upper Bounds
# 3.1 If S and T are types and the elements of S apear interleaved in T then T is called an *extension*
#     of S.
# 3.2 It suits our purpose to also assert that any type is an extenion of nil and any type
#     is an extension of the empty sequence.
# 3.3 A *least upper bound* for types S and T is a type U such that S and T are extensions of
#     U and no other extension of U with the same property exists.
# 3.3.1 Note that there may be more than one LUB for a given pair of types.
#
# 4 Attributes are comprised of a name, a structure and a value type
# 4.1 The value type is either nil (opaque type) or a type as defined above (document type).
# 4.1.1 Not that Nil (no constraints at all) is not the same as an empty sequence (contains
# 4     only the empty document).
# 4.2 The structure is either that of a single value, a list of values or a dictionary of values.
# 4.3 An attribute B is a *refinement* of an attribute A if all of the following conditions hold
# 4.3.a) the value type of B is is an extension of that of A, and
# 4.3.b) if the value type of A is not nil than its structure is the same as that of B
#
# 5 Traits and Types
# 5.1 Any Trait may specify a *local dependency graph* which is a subset of Trait².
# 5.2 For any trait, the *net dependency graph* can be calculated as the union of
#     the net dependency graphs of all vertices in the local dependency graph and
#     the local dependency graph itself
# 5.4 A sequence can be created from a trait by doing topololgical sort of
#     all vertices that can be reached in the traits net dependency graph, starting from the
#     trait itself.
# 5.4.1 If more than one such sequence exists, the trait is invalid.
# 5.4.2 If none exists (i.e. there is a cycle), the trait is invalid.
# 5.5 For the trait to be valid, this sequence must be a type.
# 5.6 Thus, any trait has exactly one corresponding type.
