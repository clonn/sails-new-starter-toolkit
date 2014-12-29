module.exports = (grunt) ->
  grunt.registerTask "default", [
    "compileAssets"
    "linkAssets"
    "watch"
  ]
  return
