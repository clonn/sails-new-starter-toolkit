should = require('chai').should()
Sails = require('sails/lib/app')
_ = require("lodash")

config = _.merge require('../../config/local'), {
  globals: false
  loadHooks: [
    'moduleloader'
    'userconfig'
    'request'
    'services'
    'controllers'
    'blueprints'
    'orm'
  ]
}
sails = new Sails()

before (done) ->
  try 
    global.sails = sails.load config, done
  catch $e
    console.error "Error", $e

after (done) ->
  sails.lower done
  return