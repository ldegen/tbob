describe "The merge function",->
  merge = require "../src/merge"
  it "comes with (naive) recursive variant", ->
    a =
      foo:2
      bar:baz:[1,2,3]
      bonk:noppel:"umf"
    b =
      krank:true
      bar:baz:tante:"onkel"
      bonk:42
    c =
      krank:false
      bar:baz:yay:0

    expect(merge.deep a,b,c).to.eql
      foo:2
      bar:baz:
        tante:"onkel"
        yay:0
      bonk:42
      krank:false
      
