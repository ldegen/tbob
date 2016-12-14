# tbob

tbob is a test data builder inspired in particular by
[Rosie](https://github.com/rosiejs/rosie).

However, at some point tbob evolved into a different direction.
We needed it to do more than "just" create test data.
In our particular workflow, factory definitions serve as reference model of our
data structures. From this model we want to create other stuff, like mappings
for Elasticsearch. We want to be able to express type constraints, and a way to attach arbitrary
metadata to any document type or attribute. Rosie's factory inheritance is fine, but we wanted
something more flexible. All this comes at the cost of added complexity.

If generating test data is your primary concern, you are almost certainly better of with
Rosie.

__Disclaimer:__
This is work in progress. Before releasing v1.0.0 we need to

- Document the DSL and the CLI

- finalize and document the scenario formats

- Give some examples of `@meta`-Annotations, and how those can be used
  to create ElasticSearch Mappings and other cool stuff.

## Usage

First, you need to tell tbob what kind of documents it should create.
You do this by defining *factories*, using tbob's own DSL:

``` coffee

module.exports = ->
  @factory "TodoList", ->
    @attr "owner"
      .type ->
        @attr "name"
          .type @string
          .fill "(owner name)"
        @attr "email"
          .type @optional @string

      
    @attr "items"
      .type @list @ref "TodoItem"
      .fill [{},{},{done:true}]

  @factory "TodoItem", ->
    @attr "id"
      .type @number
      .fill [], ->@world.docCount "TodoItem"
    @attr "title"
      .type @string
      .fill ["id"], (id)->"Title for item #{id}"
    @attr "done"
      .type @boolean
      .fill false

```

Next, you can run tbob like this

``` bash
tbob -w examples/ '["TodoList"]'
```

it will create a json document populated with defaults:
``` json
{
   "items" : [
      {
         "done" : false,
         "title" : "Title for item 0",
         "id" : 0
      },
      {
         "title" : "Title for item 1",
         "id" : 1,
         "done" : false
      },
      {
         "done" : true,
         "title" : "Title for item 2",
         "id" : 2
      }
   ],
   "owner" : {
      "email" : null,
      "name" : "(owner name)"
   }
}
```

Let's assume for your test case you need a todolist
with some particular values in it. You only specify the values
that are different from their respective defaults:


``` bash
tbob -w examples/ '["TodoList", {"items":[{"title": "Find better examples"},{},{"done":true}]}]'
```

The result would be:
``` json
{
   "owner" : {
      "email" : null,
      "name" : "(owner name)"
   },
   "items" : [
      {
         "title" : "Find better examples",
         "id" : 0,
         "done" : false
      },
      {
         "done" : false,
         "id" : 1,
         "title" : "Title for item 1"
      },
      {
         "title" : "Title for item 2",
         "id" : 2,
         "done" : true
      }
   ]
}
```
