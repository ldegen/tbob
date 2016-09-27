module.exports = ->

  lpad = (pad,num)->(""+pad+num).slice -pad.length

  defaultLookupEntries = (factory, opts)->
    (entries0)->
      entries0 ?=
        '0': id: 0
      entries = {}
      for id,entry of entries0
        entries[id] = @nested factory, entry ,opts
      entries

  titelEntries = (entries0)->
    entries0 ?=
      '0':
        id: 0
        labelMale: de: "Prof."
        labelFemale: de: "Prof."
      '1':
        id: 1
        labelMale: de: "Dr."
        labelFemale: de:"Dr."
    entries = {}
    for id,entry of entries0
      entries[id] = @nested "MaleFemaleEntry", entry , typeLabel:'Titel'
    entries

  @factory 'LookupEntry', ->
    @option 'typeLabel', "Something"
    @option 'padding', ""
    @option 'defaultKey', null
    @sequence 'id'
    @attr 'type', ['typeLabel'], (tl)->tl.toLowerCase()
    @attr 'key', ['key','padding','id','defaultKey'], (key,padding,id,defaultKey)->
      key ? defaultKey ? (lpad padding, id)

  @factory 'SimpleEntry', ->
    @extend 'LookupEntry'
    @nested 'label','Bilingual', ['label','typeLabel'], (label,tl)->
      label ?
        de: "Bezeichnung #{tl}"
        en: "Label #{tl}"


  @factory 'ShortLongEntry', ->
    @extend 'LookupEntry'
    @nested 'labelShort', 'Bilingual', ['labelShort','typeLabel'], (label,tl)->
      label ?
        de: "Bezeichnung #{tl} (kurz)"
        en: "Label #{tl} (short)"
    @nested 'labelLong', 'Bilingual', ['labelLong','typeLabel'], (label,tl)->
      label ?
        de: "Bezeichnung #{tl} (lang)"
        en: "Label #{tl} (long)"

  @factory 'MaleFemaleEntry', ->
    @extend 'LookupEntry'
    @nested 'labelFemale', 'Bilingual', ['labelFemale','typeLabel'], (label,tl)->
      label ?
        de: "Bezeichnung #{tl} (weibl.)"
        en: "Label #{tl} (female)"
    @nested 'labelMale', 'Bilingual', ['labelMale','typeLabel'], (label,tl)->
      label ?
        de: "Bezeichnung #{tl} (männl.)"
        en: "Label #{tl} (male)"

  @factory 'RawLookup', ->
    @dict 'fach', ->
      @extend 'SimpleEntry', typeLabel:'Fach', padding:'00000'
      @default
        0: id:0
    @dict 'fach', 'SimpleEntry', 'with_padding', 
      0: id: 0
      1: id: 1

    @dict 'fach', 'SimpleEntry', 'with_padding', ['fach', 'id'], (fach,id)->
      fach ?
        0: id: 0
        1: id: id+1


    @nested 'fach', -> @extend 'SimpleEntry', typeLabel:'Fach', padding:'00000'
    @nested 'fachkollegium', -> @extend 'SimpleEntry', typeLabel:'Fachkollegium', padding:'000'
    @nested 'fachgebiet', -> @extend 'SimpleEntry', typeLabel:'Fachgebit', padding:'00'
    @nested 'wissenschaftsbereich', -> @extend 'SimpleEntry', typeLabel:'Wissenschaftsbereich', padding:'0'
    @nested 'peu', -> @extend 'SimpleEntry', typeLabel: 'PEU', defaultKey:'XXX'
    @nested 'pemu', -> @extend 'SimpleEntry',
    @attr 'peu', ['peu'], defaultLookupEntries 'SimpleEntry',
      typeLabel:'PEU'
      defaultKey:'XXX'
    @attr 'pemu', ['pemu'], defaultLookupEntries 'SimpleEntry',
      typeLabel:'PEMU'
      defaultKey:'XXX'
    @attr 'peo', ['peo'], defaultLookupEntries 'SimpleEntry',
      typeLabel:'PEO'
      defaultKey:'XXXX'
    @attr 'titel',['titel'], titelEntries
    @attr 'bundesland',['bundesland'], defaultLookupEntries 'SimpleEntry',
      typeLabel:'Bundesland'
      defaultKey:'XXX0'
    @attr 'land',['land'], defaultLookupEntries 'SimpleEntry',
      typeLabel:'Land'
      defaultKey:'XXX'
    @attr 'kontinent',['kontinent'], defaultLookupEntries 'SimpleEntry',
      typeLabel:'Kontinent'
      defaultKey:'0'
    @attr 'teilkontinent',['teilkontinent'], defaultLookupEntries 'SimpleEntry',
      typeLabel:'Teilkontinent'
      defaultKey:'00'
  @factory 'RawFachklassifikation', ->
    @sequence 'id'
    @attr '_partSn',['id'], (id)->id
    @attr '_partType', 'FACHSYSTEMATIK'
    @attr 'prioritaet', false
    @attr 'wissenschaftsbereich'
    @attr 'fachgebiet'
    @attr 'fachkollegium'
    @attr 'fach'

  @factory 'RawProgrammklassifikation', ->
    @attr 'peo',0
    @attr 'pemu',0
    @attr 'peu',0
  @factory 'Bilingual', ->
    @attr 'de'
    @attr 'en'
  @factory 'RawPersonenbeteiligung', ->
    @attr '_partSn',['personId'], (id)->id
    @sequence 'personId'
    @attr '_partType', 'PER_BETEILIGUNG'
    @attr '_partDeleted', false
    @attr 'referent',false
    @attr 'verstorben',false
    @attr 'showInProjektResultEntry',true
    @attr 'style', 'L'
    @attr 'btrKey', "PAN"

  @factory 'RawInstitutionsbeteiligung', ->
    @sequence '_partSn'
    @attr '_partType', 'INS_BETEILIGUNG'
    @attr 'btrKey', 'IAN'
    @attr 'style', 'L'
    @sequence 'institutionId'

  @factory 'TitelTupel', ->
    @attr 'anrede',0
    @attr 'teilname',1

  @factory 'InsTitel', ->
    @attr 'nameRoot', ['nameRoot'], (name)->
      @nested "Bilingual", name ?
        de: 'Name der Wurzelinstitution'
        en: 'Name of Root Institution'
    @attr 'namePostanschrift', 'Name der Wurzelinstitution, Abteilung, usw'

  @factory 'GeoLocation', ->
    @attr 'lon'
    @attr 'lat'

  @factory 'RawRahmenprojekt', ->
    @sequence 'id'
    @attr 'gz', 'FOO 08/15'
    @attr 'gzAnzeigen', false
    @attr 'titel', ['titel'], (titel)->
      @nested "Bilingual", titel ?
        de: "Rahmenprojekttitel"
        en: "Title of Framework Project"

  @factory 'RawBeteiligtePerson', ->
    @sequence 'id'
    @attr '_partSn',['id'], (id)->id
    @attr '_partDeleted', false
    @attr '_partType', 'PER'
    @attr 'privatanschrift',false
    @attr 'vorname', 'Vorname'
    @attr 'nachname', 'Nachname'
    @attr 'ort', 'Ortsname'
    @attr 'ortKey', 'DEU12potsdam'
    @attr 'plzVorOrt', '00000'
    @attr 'plzNachOrt',null
    @attr 'titel',['titel'], (titel)->@nested 'TitelTupel',titel ? {}
    @attr 'geschlecht','m'
    @attr 'institution',['institution'], (ins)->@nested 'InsTitel', ins ? {}
    @attr 'geolocation',['geolocation'], (loc)-> if loc? then @nested 'GeoLocation', loc
    @attr 'bundesland',0
    @attr 'land',0

  @factory 'RawBeteiligteInstitution', ->
    @sequence 'id'
    @attr '_partSn',['id'], (id)->id
    @attr '_partType', 'INS'
    @attr 'rootId'
    @attr 'einrichtungsart', 5
    @attr 'bundesland', 'DEU12'
    @attr 'ortKey', 'DEU12potsdam'
    @attr 'ort', 'Potsdam'
    @attr 'name:Bilingual',['name'], (name)->
      @nested 'Bilingual', name ?
        de: 'Name der Institution'
        en: 'Name of Institution'
    @attr 'nameRoot', ['nameRoot'], (name)->
      @nested "Bilingual", name ?
        de: 'Name der Wurzelinstitution'
        en: 'Name of Root Institution'
    @attr 'namePostanschrift', 'Name der Wurzelinstitution, Abteilung, usw'
    @attr 'geolocation',['geolocation'], (loc)-> if loc? then @nested 'GeoLocation', loc

  @factory 'RawAbschlussbericht', ->
    @attr 'datum', 0
    @attr 'abstract', ['abstract'], (abs)->
      @nested 'Bilingual',abs ?
        de:'Deutscher AB Abstract'
        en:'Englischer AB Abstract'
    @attr 'publikationen',['publikationen'], (pubs)->
      (pubs ? []).map (pub)->
        @nested 'RawPublikation',pub
  @factory 'RawPublikation', ->
    @sequence '_partSn'
    @attr '_partType', 'PUBLIKATION'
    @attr '_partDeleted'
    @attr 'titel', 'Publikationstitel'
    @attr 'position',0
    @attr 'autorHrsg', "Autor / Hrsg."
    @attr 'verweis', null
    @attr 'jahr', 1984
  @factory 'RawNationaleZuordnung', ->
    @sequence '_partSn'
    @attr '_partType', 'LAND_BEZUG'
    @attr 'kontinent',1
    @attr 'teilkontinent',12
    @attr 'land',1


  @factory 'RawProjekt', ->
    @attr '_partType', 'PRJ'
    @attr '_partSn', -1
    @attr '_partDeleted', false
    @sequence 'id'
    @attr 'hasAb',['abschlussbericht'], (ab)-> ab?
    @attr 'isRahmenprojekt', false
    @attr 'isTeilprojekt',['rahmenprojekt'], (rp)->rp?
    @attr 'pstKey', 'ABG'
    @attr 'gz', 'GZ 08/15'
    @attr 'gzAnzeigen', false
    @attr 'wwwAdresse', "http://www.mein-projekt.de"
    @attr 'rahmenprojekt',['rahmenprojekt'], (rp)->
      if rp? then @nested 'RawRahmenprojekt', rp
    @attr 'beginn'
    @attr 'ende'
    @attr 'beteiligteFachrichtungen'
    @attr 'titel', ['titel'], (titel)->
      @nested 'Bilingual', titel ?
        de: "Projekttitel"
        en: "Project Title"
    @attr 'antragsart', 'EIN'
    @attr 'abstract', ['abstract'], (abstract)->
      if abstract? then @nested 'Bilingual', abstract
    @attr 'fachklassifikationen', ['fachklassifikationen'], (fks)->
      prioSet = (fks ? []).some (fk)->fk.prioritaet
      (fks ? [{wissenschaftsbereich:0,fachkollegium:0,fach:0}]).map (d,i)->
        if not prioSet and not d.prioritaet?
          prioSet=true
          d.prioritaet=true
        @nested 'RawFachklassifikation', d
    @attr 'internationalerBezug',['internationalerBezug'], (zs)->
      (zs ? []).map (z)->@nested 'RawNationaleZuordnung', z
    @attr 'programmklassifikation', ['programmklassifikation'], (pkl)->
      @nested('RawProgrammklassifikation', pkl ? {})
    @attr 'perBeteiligungen', ['perBeteiligungen'] , (bets)->
      (bets ? []).map (bet)->@nested 'RawPersonenbeteiligung', bet
    @attr 'insBeteiligungen', ['insBeteiligungen'] , (bets)->
      (bets ? []).map (bet)->@nested 'RawInstitutionsbeteiligung', bet

    @attr 'personen',['perBeteiligungen','personen'], (bets,personen0)->
      personen0 ?= {}
      personen = {}
      for bet in bets
        personen[bet.personId]=@nested 'RawBeteiligtePerson', {id:bet.personId}
      for perId, person of personen0
        personen[perId] = @nested 'RawBeteiligtePerson', person
      personen
    @attr 'institutionen',['insBeteiligungen','institutionen'], (bets,institutionen0)->
      institutionen0 ?= {}
      institutionen = {}
      for bet in bets
        institutionen[bet.institutionId]=@nested 'RawBeteiligteInstitution', {id:bet.institutionId}
      for insId, institution of institutionen0
        institutionen[insId] = @nested 'RawBeteiligteInstitution', institution
      institutionen
    @attr 'abschlussbericht',['abschlussbericht'],(ab)->
      if ab? then @nested 'RawAbschlussbericht', ab

