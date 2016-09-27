Before we start, lets define a bit notational sugar for exporting classes.

    _exposed=[]
    _expose = (c)->_exposed.push c

Model
=====

Specs
-----

A *Spec* ("specification") is what you give to a factory when you want it to
produce an object that adheres to your Spec. It is comprised of a list of
traits and an object containing attribute overrides. Overrides in turn can
contain more specs to override the default behaviour for compound attributes.

Both, traits aswell as overrides can be ommited.

    _expose class Spec
      constructor: (@traitRefs=[], @overrides={})->
        # nothing else to do.


Types
-----

A *Type* is tripple (name, super, traitDefinitions). A type is a description of
the structure of a document, or part of a document. This structure is
recursively defined by a set of attributes whose values are either scalar (or
opaque) values, or compound structures described by nested types.


    _expose class Type
      constructor: (name, superVariant=null)->
        @name=name
        @superVariant=superVariant
        @traitDefinitions=
          t0: new Trait(this, "t0")

All attribute definitions are grouped in traits.

Traits
------

When dealing with test data we often tend to use ideosyncratic language to
describe certain properties of a domain object, that only indirectly map to the
defined attributes.  Something like "Gib mir ein SFB-Rahmenprojekt mit
gesperrtem Abschlussbericht." (I won't even try to translate that.) On the one
hand, we would like to capture the meaning of something like
"SFB-Rahmenprojekt". Subtyping would lead to all the usual problems with
multi-inheritence. We could use options (think: hidden attributes, see below),
but that feels clumpsy.  Another approach is to use so called *traits*. (Not so
much "traits" like in programming languages, but like in plain English).  It
allows us to say "give me an Object of type 'Projekt' and apply traits
'sfb rahmenprojekt', 'ab gesperrt'".

A Trait is basically a particular *fill-strategy* for a set of attributes.
Every type has an implicit default trait *t0* that is always applied. You can add an
arbitrary namber of additional, named traits and add specialized attribute
definitions for that trait only.


    _expose class Trait
      constructor: (@type, @name)->
        @attributes={}

Adding an attribute to any trait of a given type will automatically make sure
that an attribute with the same name (but without any fill strategy!) exists in
the default trait of that type. This is done to make sure that traits do not alter
the document type itself, but only the fill strategy.

      add: (attribute)->
        if not @name is "t0"
          t0 = @type.traitDefinitions.t0
          baseAttr = t0[attribute.name]
          if not baseAttr?
            t0.add new Attribute attribute.name, attribute.rel, [], null
          else if baseAttr.rel?.toString() != attribute.rel?.toString()
            throw new Error("conflicting argument types")

When requesting an object of a given type and trait(s), we ultimately have to
'apply' the trait to a factory object.  This boils down to applying the attribute
definitions to the factory.

      apply: (factory, build)->
        attr.apply factory, build for name,attr of @attributes

Variants
--------

In many situations, we do not refer to types directly, but instead use
*Variants*.  A *Variant* is a combination of a type and a set of variant
references. We can use it to request specifically request the "structure" of a
certain type, combined with the default "behaviour" of a specified set of
traits.

Technically, variants are a unit of reuse when creating lots of objects. We
never create more than one factory per variant.

    _expose class Variant
      constructor: (@type, @traitRefs=[])->
      toString: ->
        if @traitRefs.length is 0 then @type.name else "#{@type.name}(#{@traitRefs.join ','})"

Attributes
----------

An *attribute*, (in its most general form) is a tuple (name, dependencies,
fillStrategy)

*dependencies* is a list of names of the same type that need to be filled
before this attribute can be filled. (same as in rosie.js)

*fillStrategy* is a function that will be applied to the values of the
attributes specified in dependencies.

    _expose class Attribute
      constructor: (@name, @dependencies=[], @fillStrategy)->

Attributes are the atomic units of our semantics. We program the behaviour of
our factories by "applying" attributes to them. Here we look at the simplest
scenario possible:

      apply: (factory)->
        factory.attr @name, @dependencies, @fillStrategy

Of course, this is only useful for simple attributes that carry scalar or
otherwise opaque values.  For compound values, where the inner structure is
relevant, we need more elaborated behaviour.  The same is true for special
cases like sequences or options. We make use of several subclasses to model the
different types of attributes.

A *NestedAttribute* is used to model an attribute whose single value is an
object of known type.

    _expose class NestedAttribute extends Attribute
      constructor: (name, @nestedType, dependencies=[], fillStrategy)->
        super name, dependencies, fillStrategy

When using a nested attribute, the fillStrategy does not return a concrete
value, but rather a spec that needs to be processed by a dedicated factory
instance.

      apply: (factory,build)->
        factory.attr @name, @dependencies, (attrs...)->
          spec = fillStrategy.apply this, attrs
          build @nestedType, spec.traitRefs, spec.overrides

A ListAttribue is used to model an attribute whose value is an ordered list
whose elements are all instances of the same known type.  Semantics are similar
to that of a NestedAttribute, only for multiple values.

    _expose class ListAttribute extends Attribute
      constructor: (name, @nestedType, dependencies=[], fillStrategy)->
        super name, dependencies, fillStrategy
      apply: (factory,build)->
        factory.attr @name, @dependencies, (attrs...)->
          specs = fillStrategy.apply this, attrs
          build @nestedType, spec.traitRefs, spec.overrides for spec in specs

A DictAttribute is used to model an attribute whose value is a dictionary of
key-value-Pairs.  The keys are all strings (it's just an object, doh!), and the
values are all objects a known type. Semantics are completely analogous to the
beformentioned cases.

    _expose class DictAttribute extends Attribute
      constructor: (name, @nestedType, dependencies=[], fillStrategy)->
        super name, dependencies, fillStrategy
      apply: (factory,build)->
        factory.attr @name, @dependencies, (attrs...)->
          specs = fillStrategy.apply this, attrs
          dict = {}
          dict[key]=build @nestedType, spec.traitRefs, spec.overrides for key, spec of specs
          dict

An OptionAttribute is used to parameterize factories without actually adding
attributes to the built objects.  Just like normal attributes, options can be
depended on to calculate the value of other attributes (or options), but they
do not appear in the resulting object.  Semantics: OptionAttributes are just
options in rosie.

    _expose class OptionAttribute extends Attribute
      apply: (factory)->
        factory.option @name, @dependencies, @fillStrategy

A SequenceAttribute is used to model sequence attributes. Duh.

    _expose class SequenceAttribute extends Attribute
      apply: (factory)->
        factory.sequence @name, @dependencies, @fillStrategy



Object Building and Factory Creation
====================================

To build any object, Bob will first construct a factory for the requested type or variant.
It caches *all* created factories. Caching is local to a 'world' instance.

    world = (Factory)->
      build = (type, traitRefs=[], overrides={})->
        f = if traitRefs.length==0 then factoryForType(type) else factoryForVariant new Variant(type, traitRefs)
        f.build overrides
      factories={}

      factoryForVariant=(variant)->
        factories[variant] ?= constructFactoryForVariant variant

      factoryForType=(type)->
        factories[type] ?= constructFactoryForType type

Constructing a factory for a variant (typeRef, traitRefs) is done by induction over the requested variant:
 1. construct (or load from cache) a factory f0 for the type typeRef
 2. create a new factory f and let it extend f0
 3. apply traitRefs

      constructFactoryForVariant = ({type, traitRefs})->
        f0 = factoryForType type
        f = new Factory
        f.extend f0
        for traitRef in traitRefs
          trait = type.traitDefinitions[traitRef]
          trait.apply f, build
        f

Constructing a factory for a type (name, super, traitDefinitions):
 1. create a new factory f
 2. if super is not nil, construct or load a factory f0 for super and let f extend f0
 3. find the traitDefinition t0 and apply it to f

      constructFactoryForType = ({name, superVariant, traitDefinitions})->
        f = new Factory
        if superVariant?
          f0 = factoryForVariant superVariant
          f.extend f0
        traitDefinitions.t0.apply f, build
        f

Return the 'world' as a closure to the build function.

      build

Public API
==========

The higher-order 'world' function is also the entry point of the public API of this module.

    module.exports = world

In addition, all the classes defined above are exposed as exported properties.

    module.exports[classDef.name] = classDef for classDef in _exposed

Use the API like this:

``` coffeescript
  # require the parts of the API that you need:

  Builder = {Type, Trait, Attribute} require "bob"

  # create a build function

  build = Builder()

  # define some types
  t1 = new Type(...)

  # build stuff

  obj = build t1, ["foo", "bar"], bang: 42

```
