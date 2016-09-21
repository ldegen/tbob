describe "The Bob Transform", ->
  BobTransform = require "../src/bob-transform"
  sink = undefined
  scenarioNo = undefined
  world = ->
  MockBob = ()->
    scenarioNo++
    build: (args...)->["Scenario #{scenarioNo}", args...]

  beforeEach ->
    scenarioNo=0
    sink = Sink()

  it "Takes a world definition and creates a Transform to pipe scenario definitions through",->
    Source [
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
      .pipe BobTransform world, MockBob
      .pipe sink
    expect(sink.promise).to.eventually.eql [
      p1: ["Scenario 1", "Projekt", "ab_gesperrt", title:"SFB 42: Space Shuttle"]
      p2: ["Scenario 1", "Projekt", "rahmenprojekt"]
    ,
      p1: ["Scenario 2", "Projekt"]
    ]

