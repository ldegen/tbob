describe "The TBob Transform", ->
  TBobTransform = require "../src/tbob-transform"
  sink = undefined
  source = undefined
  tbob = undefined
  scenarioNo = undefined
  world = ->
  MockTBob = ()->
    scenarioNo++
    build: (args...)->["Scenario #{scenarioNo}", args...]
    type: (args...)->["Scenario #{scenarioNo}", "type", args...]
    metaTree: (args...)->["Scenario #{scenarioNo}", "metaTree", args...]

  beforeEach ->
    scenarioNo=0
    sink = Sink()
    source = Source [
      ["Projekt", "ab_gesperrt", title: "SFB 42: Space Shuttle"]
      ["Projekt", "rahmenprojekt"]
      ["Projekt"]
    ]

  describe "in scenario mode", ->
    beforeEach ->
      tbob = TBobTransform world, world:MockTBob, mode:'scenario'
      source = Source [
        p1: [
          "Projekt"
          "ab_gesperrt"
          title: "SFB 42: Space Shuttle"
        ]
        p2: [
          "Projekt"
          "rahmenprojekt"
        ]
      ,
        p1: ["Projekt"]
      ]
    it "treats each chunk of input as a description of a separate scenario, containing an arbitrary number of (named) documents",->
      source
        .pipe tbob
        .pipe sink
      expect(sink.promise).to.eventually.eql [
        p1: ["Scenario 1", "Projekt", "ab_gesperrt", title:"SFB 42: Space Shuttle"]
        p2: ["Scenario 1", "Projekt", "rahmenprojekt"]
      ,
        p1: ["Scenario 2", "Projekt"]
      ]

  describe "in document mode", ->
    beforeEach ->
      tbob = TBobTransform world, world:MockTBob, mode:'document'
    it "treats input chunks as document specs all belonging to the same scenario", ->
      source
        .pipe tbob
        .pipe sink
      expect(sink.promise).to.eventually.eql [
        ["Scenario 1", "Projekt", "ab_gesperrt", title:"SFB 42: Space Shuttle"]
        ["Scenario 1", "Projekt", "rahmenprojekt"]
        ["Scenario 1", "Projekt"]
      ]
  describe "in type mode", ->
    beforeEach ->
      tbob = TBobTransform world, world:MockTBob, mode:'type'
    it "outputs document types instead of documents", ->
      source
        .pipe tbob
        .pipe sink
      expect(sink.promise).to.eventually.eql [
        ["Scenario 1", "type", "Projekt", "ab_gesperrt", title:"SFB 42: Space Shuttle"]
        ["Scenario 1", "type", "Projekt", "rahmenprojekt"]
        ["Scenario 1", "type", "Projekt"]
      ]

  describe "in duplex mode", ->
    beforeEach ->
      tbob = TBobTransform world, world:MockTBob, mode:'duplex'
    it "produces objects containing both, the type and the objec", ->
      source
        .pipe tbob
        .pipe sink
      expect(sink.promise).to.eventually.eql [
        _type: ["Scenario 1", "type", "Projekt", "ab_gesperrt", title:"SFB 42: Space Shuttle"]
        _data: ["Scenario 1", "Projekt", "ab_gesperrt", title:"SFB 42: Space Shuttle"]
      ,
        _type: ["Scenario 1", "type", "Projekt", "rahmenprojekt"]
        _data: ["Scenario 1", "Projekt", "rahmenprojekt"]
      ,
        _type: ["Scenario 1", "type", "Projekt"]
        _data: ["Scenario 1", "Projekt"]
      ]

