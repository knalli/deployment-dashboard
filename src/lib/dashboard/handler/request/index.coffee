templates = ({})

for name in ['http', 'ssh']
  templates[name] = require "./#{name}_request_handler"

module.exports = (name) ->
  name = name.toLowerCase()
  templates[name].handler