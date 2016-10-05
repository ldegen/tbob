_exposed=[]
expose = (c)->_exposed.push c
SigMatch = require "./signature-matcher"
checkInstantiation = (instance, BaseType)->
  if not (instance instanceof BaseType)
    throw new Error "Well, this is strange. Did you forget to use 'new'?"

  if @constructor.abstract
    throw new Error "The class '#{instance.constructor}' is abstract, you cannot instantiate it."

expose class Type
  @abstract:true
  structure:()-> "unknown"
  constructor: ->
    checkInstantiation this, Type
  refine: -> throw new Error "Nope"
  clone: -> throw new Error "Nope"

expose class OpaqueType extends Type
  @abstract:false
  structure: ->"opaque"
  refine: (otherType)-> otherType.clone()
  clone: ->this #no need for clones, since this type is imutable

expose class BuildableType extends Type
  @abstract:true
  structure: ->"buildable"
  constructor: (@name)->


expose class CompositeType extends Type
  @abstract:true
  structure: -> @localStructure()+"|"+@entryType.structure()

expose class VariantType extends BuildableType
  @abstract:true
  constructor: (@_baseType, @_traitRefs=[])->
    super "#{[@_baseType.name, @_traitRefs...]})"

  describe: -> [@_baseType.name, @_traitRefs...]
  base:->@_baseType
  super:->@_baseType.super()
  traitRefs:->@_traitRefs
  clone: -> this # no need to clone, since we are imutable

expose class DocumentType extends BuildableType

  constructor: (@name, @_super=null)->
    super @name
    @_attrs={}

  base:->this
  super:->@_super
  traitRefs:->[]
  clone: -> new DocumentType @name, this

  attr: (name)->
    @_attrs[name] ?= new Attribute(name, this)


expose class DictionaryType extends CompositeType
  @abstract:false
  localStructure: -> "dict"

expose class ListType extends CompositeType
  @abstract:false
  localStructure: -> "list"

expose class Attribute
  @abstract:false
  constructor: (@name, @declaringType)->
    @_valueType = new OpaqueType
    @_semantics = new PlainSemantics

  # Every attribute has its own implicit value type.
  # Initially this is an ('the') opaque type, basicaly indicating
  # the absence of any type information whatsoever.
  # Type information can be attached passing a function, which will be
  # called with a document type instance as single argument.
  valueType: (mutate)->
    switch typeof mutate
      when "undefined" then @_valueType
      when "function"
        if @_valueType instanceof OpaqueType
          @_valueType = new DocumentType @declaringType.name+"$"+@name
        mutate @_valueType
        this
      else
        throw new Error """I don't know what to do with '#{typeof mutate}'. 
        To mutate the type of #{@declaringType}.#{@name}, use a callback; I will inject the type for you.
        """
  semantics: ->@_semantics

expose class AttributeSemantics
  @abstract:true
  constructor: ->
    checkInstantiation this, AttributeSemantics

expose class PlainSemantics extends AttributeSemantics
  @abstract:false

expose class OptionSemantics extends AttributeSemantics
  @abstract:false

expose class SequenceSemantics extends AttributeSemantics
  @abstract:false

expose class FillStrategy
  @abstract:false

expose class Spec
  @abstract:true
  constructor: ->
    checkInstantiation this, Type

expose class DocumentSpec extends Spec
  @abstract:false

expose class OpaqueSpec extends Spec
  @abstract:false

expose class CompositeSpec extends Spec
  @abstract:true

expose class DictionarySpec extends CompositeSpec
  @abstract:false

expose class ListSpec extends CompositeSpec
  @abstract:false


module.exports[classDef.name] = classDef for classDef in _exposed
 
