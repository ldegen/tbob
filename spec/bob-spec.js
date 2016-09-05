describe("Bob", function() {
  var Bob = require("../src/bob");
  var merge = require("deepmerge")
  it("is a simple wrapper around rosie's Factory API", function() {
    var bob = Bob(function(Factory) {
      var f = new Factory()
        .sequence('id')
        .attr('type', "SPECIAL_TYPE")
        .attr('key', ['id'], function(id) {
          return "KEY_" + id;
        });

      return {
        Entry: f
      };
    });
    return expect(bob.build("Entry")).to.eql({
      id: 1,
      type: "SPECIAL_TYPE",
      key: "KEY_1"
    });
  });

  it("raises an Error if you try to invent new attributes", function() {
    var bob = Bob(function(Factory) {
      return {
        Thing: new Factory()
          .sequence('id')
          .attr('foo', "bar")
      };
    });
    return expect(function() {
      return bob.build("Thing", {
        bar: "baz"
      });
    }).to["throw"](Bob.BadAttributeError);
  });

  it("supports traits (a.k.a. variants or mixins)",function(){
    var bob = Bob(function(Factory, Trait){
      return {
        Thing: new Factory().sequence('id').attr('foo','bar').attr('bang','baz'),
        with_big_bang: function(options, next){
          return next(merge({bang:"big"},options));
        }
      };
    });

    expect(bob.build(["Thing","with_big_bang"],{foo:"balla"})).to.eql()
  
  };)
});
