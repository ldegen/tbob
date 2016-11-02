module.exports = class ErrorWithContext extends Error
  constructor: (nestedError, context={})->
    super()
    @name="ErrorWithContext"
    if typeof context is "string"
      context = message:context
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
    
