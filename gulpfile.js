var gulp = require('gulp');
var watch = require('gulp-watch');
var compass = require('gulp-compass');

gulp.task('default', function() {
  // place code for your default task here
  gulp.src('assets/styles/importer.scss')
  .pipe(watch('./assets/styles/**/*.scss'))
  .pipe (compass({
    config_file: './config.rb',
    sass: './assets/styles/',
    css: '.tmp/public/styles/'
  }))
  .on('error', function(error) {
      // Would like to catch the error here
    console.log(error);
  })
  .pipe(gulp.dest('./.tmp/public/styles/'));
});