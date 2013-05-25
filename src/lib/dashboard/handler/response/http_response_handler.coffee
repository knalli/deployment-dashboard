handler = (response) ->
  response[0].body if response[0].statusCode is 200


# Export class
module.exports =
  id: 'HTTP'
  handler: handler