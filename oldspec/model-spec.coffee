xdescribe "The Model", ->
  Model = require "../src/model"
  {DocumentType, Attribute,OpaqueType, PlainSemantics} = Model

  describe "An Attribute",->
    it "is created implicitly as part of a DocumentType", ->
      docType = new DocumentType "Doc"
      attr = docType.attr "flint"
      expect(attr).to.be.an.instanceof Attribute
      expect(attr.declaringType).to.equal docType

    it "initially comes with an opaque value type and plain semantics", ->
      docType = new DocumentType "Doc"
      attr = docType.attr "flint"
      expect(attr.valueType()).to.be.an.instanceof OpaqueType
      expect(attr.semantics()).to.be.an.instanceof PlainSemantics

    it "can refine its value type to a document type", ->
      docType = new DocumentType "Doc"
      otherType = new DocumentType "Other"
      attr = docType
        .attr "flint"
        .valueType (t)-> t.attr "bar"
      docType = attr.valueType()

      expect(docType).to.be.an.instanceof DocumentType
      expect(attr.valueType()).to.equal docType
      

  describe "A DocumentType", ->
    describe "when asked for an attribute with a given name", ->
      it "will always returns the Attribute instance", ->
        docType = new DocumentType "Doc"
        attr1 = docType.attr "flint"
        attr2 = docType.attr "flint"
        attr3 = docType.attr "flint"

        expect(attr1).to.equal attr2
        expect(attr2).to.equal attr3

    describe "when asked to extend another type", ->
      it "makes sure it does not close a dependency cycle"
      it "will switch to the new super type if it is a specialization of the current one"
      it "sticks with the current super type if it is a specialization of the new one"
