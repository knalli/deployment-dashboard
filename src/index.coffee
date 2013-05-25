#!node_modules/.bin/coffee
util = require 'util'


configFileId = process.argv[2] or 'Dashboard'
unless configFileId[-7..] is '.coffee'
  configFileId += '.coffee'
unless configFileId[0] is '/'
  configFileId = process.cwd() + '/' + configFileId

{App} = require './lib/dashboard'
app = new App
configRunner = null

try
  configRunner = require "#{configFileId}"
  util.log "Configuration file found."
catch e
  util.error "Configuration file not found: #{configFileId}"
  process.exit 1

try
  configRunner app
  util.log "Configuration successfully loaded."

catch e
  util.error "Configuration loading failed: #{e.message}"
  process.exit 1

app.run()