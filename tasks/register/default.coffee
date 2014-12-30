module.exports = (grunt) ->
  grunt.registerTask "default", [
    "bower:dev"
    "compileAssets"
    "linkAssets"
    "watch"
  ]
  return
