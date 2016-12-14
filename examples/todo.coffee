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
