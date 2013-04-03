#!/usr/bin/env coffee

http = require 'http'
connect = require 'connect'
repl = require './index'

app = connect()
app.use('/repl', repl({
    username: "admin",
    password: "secret",
    context: global
}))

httpServer = http.createServer(app)
httpServer.once('listening', ->
    console.log("HTTP server listening on port", httpServer.address().port)
)
httpServer.listen(process.env.PORT or 0)

module.exports = httpServer
