describe.only "about Auth", (done) ->
  it "execute login by id", (done) ->

    request(sails.hooks.http.app)
    .get("/")
    .end (err, res) ->
      return done(body) if res.statusCode is 500
      res.statusCode.should.equal 200
      done(err)


