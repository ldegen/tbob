module.exports = function(configure) {
  var Factory = require("rosie").Factory;
  var factories = configure(Factory);
  var postProcess = function(name, factory) {
    return factory.after(function(obj) {
      var attr, value;
      var attrs = factory._attrs;
      for (attr in obj) {
        value = obj[attr];
        if (!attrs[attr]) {
          throw new BadAttributeError(attr,name);
        }
        if (typeof value === "undefined") {
          delete obj[attr];
        }
      }
      return obj;
    });
  };
  Object.keys(factories).forEach(function(name){
    var factory = factories[name];
    postProcess(name, factory);
  });

  return {
    build: function(factoryName, opts) {
      return factories[factoryName].build(opts);
    }
  };
};
var extend = function(child, parent) {
  for (var key in parent) {
    if (hasProp.call(parent, key)) child[key] = parent[key];
  }

  function ctor() {
    this.constructor = child;
  }
  ctor.prototype = parent.prototype;
  child.prototype = new ctor();
  child.__super__ = parent.prototype;
  return child;
};

var hasProp = {}.hasOwnProperty;

var BadAttributeError = (function(superClass) {
  extend(BadAttributeError, superClass);

  function BadAttributeError(attr, factoryName) {
    BadAttributeError.__super__.constructor.call(this, "You tried to introduce a new attribute '" + attr + "' in factory '"+factoryName+"'.");
  }

  return BadAttributeError;

})(Error);
module.exports.BadAttributeError = BadAttributeError;
