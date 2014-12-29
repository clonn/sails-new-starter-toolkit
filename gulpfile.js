var gulp = require('gulp');
var watch = require('gulp-watch');
var compass = require('gulp-compass');

gulp.task('default', function() {
  // place code for your default task here
  gulp.src('./assets/**/*.scss')
  .pipe(watch('./assets/**/*.scss'))
  .pipe (compass({
    sass: './assets/styles/',
    css: '.tmp/public/styles/'
  }))
  .on('error', function(error) {
      // Would like to catch the error here
    console.log(error);
    this.emit('end');
  })
  .pipe(gulp.dest('./.tmp/public/'));
});