module.exports = class ErrorWithContext extends Error
  constructor: (nestedError, context0={})->
    super()
    @name="ErrorWithContext"
    @originalStack = super.stack
    if typeof context0 is "string"
      context = message:context0
    else
      context = context0
    if context.message?
      nestedMessage = nestedError.message
        .split "\n"
        .map (line)-> "  "+line
        .join "\n"
      @message="#{context.message}\nCause:\n#{nestedMessage}"
    else
      @message=nestedError.message
    if context.context?
      @message="In '#{context.context}':\n#{@message}"

    @nestedError = nestedError
    @context= context
    fullNestedStack: ->
      if @nestedError instanceof ErrorWithContext then @nestedError.fullStack() else @nestedError.stack
    fullStack: ->
      [@originalStack,fullNestedStack()...].join "\nNested Stack:\n"
      
