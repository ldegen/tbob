Bob
===

*Bob* ist ein *Builder*, ein Werkzeug, das -- gemäß einer bekannten *Bauanleitung* --
Datensätze erzeugt, die bestimmten vorgegebenen Anforderungen genügen (z.B.
ein Projektnachweis zu einem bestimmten Verfahren). Alle nicht spezifizierten
Eigenschaften werden mit "plausiblen" Defaults befüllt. Die so erstellten
Datensätze eigenen sich zur Verwendung in manuellen oder automatisierten
Testfällen.


Motivation
----------

Das Verhalten unseres Systems wird auf zwei Ebenen durch Tests beschrieben:

1. Einerseits beschreiben wir das Verhalten einzelner *Komponenten* unabhängig
   von der Domäne.

2. Andererseits beschreiben wir das Verhalten einer bestimmten *Konfiguration*
   dieser Komponenten *für unsere Domäne*.

Insbesondere im zweiten Fall muss davon ausgegangen werden, dass wir in
verschiedensten Kontexten mit ähnlichen Testdaten arbeiten werden.

Einfaches Beispiel:

- Eine REST-API stellt Daten in einem bestimmten Format zur Verfügung.

- Ein Client verarbeitet diese Daten und repräsentiert sie in einer bestimmten
  Art und Weise.

Beide Tests referenzieren die 'Art' von Daten, die wir natürlich trotzdem nur
einmal beschreiben wollen. Und optimaler weise so, dass die Beschreibung
automatisch überprüft wird. 



Szenarien, Factories, Traits, Variants
--------------------------------------

Factories funtkionieren im wesentlichen genau wie die von Rosie.  Tatsächlich
verwenden wir Rosie-Factories zur Implementierung unserer Factories, exponieren
aber nur einen Teil der Rosie-API in unserer DSL.

Wir verwenden zudem nicht die globale Registry von Rosie, sondern eine eigene
Registry die spezifisch für die jeweilige Instanz von Bob ist.

Eine neue Instanz von Bob wird immer mit einem Szenario referenziert. Das
Szenario wird beschrieben durch eine anonyme Funktion, die mit einem
`scenarioContext`-Objekt als `this` ausgeführt wird.

Dieser Kontext stellt die API zum definieren von Factories bereit. Das ist im
Wesentlichen die Methode `factory`. Diese wiederum erwartet eine weitere
Callback-Funktion, die diese factory beschreibt.  Dieser Callback wird mit
einem `factoryContext` als `this` aufgerufen.  Der `factoryContext` ist ein
dünner Wrapper um eine `Factory`-Instanz von Rosie und bietet die übliche API
(`attr`, `sequence`, `option`, `extend`). Darüber hinaus gibt es die Direktive
`trait` zum definieren eines Traits. Diese erwartet wiederum einen Callback
der wiederum mit einem `traitContext` als `this` ausgeführt wird. usw.

Beispiel:
---------

Ein einfaches Szenario könnte folgendermaßen aussehen:

``` coffeescript
module.exports = ->
  
  @factory "Project", ->
    @sequence "id"
    @attr "title", [id], (id)->"Titel von Projekt #{id}"
    @attr "abstract", "Lorem Ipsum einszweidrei"
    @trait "no_abstract", ->
      @attr "abstract", null
    
```


Ideen zur Umsetzung
-------------------

- Die eigentliche Arbeit erledigen wir mit
  [rosie](https://github.com/rosiejs/rosie), oder irgendwas ähnlichem.

- Wir nehmen die Factories aus dem geprisapp-service als Ausgangspunkt.

- Dieser Kern wird um die Möglichkeit erweitert, Bauanleitungen "dynamisch" zu laden.

- Ausserdem benötigen wir mittelfristig die Möglichkeit, über Bauanleitungen zu reflektieren.

- Um den Kern wickeln wir Schnittstellen, die uns ermöglichen, Bob nicht nur via API,
  sondern auch auf der Kommandozeile oder aus einer Web-Anwendung heraus zu nutzen.





