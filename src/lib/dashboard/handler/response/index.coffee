templates = ({})

for name in ['http', 'json']
  templates[name] = require "./#{name}_response_handler"

module.exports = (name) ->
  name = name.toLowerCase()
  templates[name]