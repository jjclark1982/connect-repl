chai = require 'chai'
expect = chai.expect
chai.should()
http = require 'http'
querystring = require 'querystring'

server = null

describe('Backend', ->
    describe("Middleware", ->
        it('should compile without errors', ->
            repl = require("../src")
            expect(repl).to.be.ok
        )
    )

    describe("Server", ->
        it('should run without errors', ->
            server = require("../src/example-server")
            expect(server).to.be.ok
        )
    )
)

describe('Frontend', ->
    makeRequest = (options, done, complete)->
        options.hostname ?= 'localhost'
        options.port ?= server.address().port
        options.path ?= '/repl'
        options.method ?= 'POST'
        options.auth ?= 'admin:secret'
        req = http.request(options, (res)->
            res.body = ''
            res.on('data', (chunk)->
                res.body += chunk
            )
            res.on('close', ->
                done('connection closed')
            )
            res.on('end', ->
                complete(res)
            )
        )
        req.on('error', (err)->
            done(err)
        )
        if options.body?
            body = querystring.stringify(options.body)
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded')
            req.setHeader('Content-Length', body.length)
            req.write(body)
        req.end()

    it('should not appear at /', (done)->
        makeRequest({method: "GET", path: '/'}, done, (res)->
            expect(res.statusCode).to.equal(404)
            done()
        )
    )

    it('should appear at /repl', (done)->
        makeRequest({method: "GET", path: '/repl'}, done, (res)->
            expect(res.statusCode).to.equal(200)
            done()
        )
    )

    it('should reject requests without the password', (done)->
        makeRequest({auth: ''}, done, (res)->
            expect(res.statusCode).to.equal(401)
            done()
        )
    )

    it('should accept requests with the right password', (done)->
        makeRequest({}, done, (res)->
            expect(res.statusCode).to.equal(200)
            done()
        )
    )

    it('should evaluate well-formed JavaScript expressions', (done)->
        makeRequest({body:{expression: '2 + 3'}}, done, (res, body)->
            expect(res.body).to.equal('5')
            done()
        )
    )

    it('should reject misformed JavaScript expressions', (done)->
        makeRequest({body:{expression: 'x['}}, done, (res, body)->
            expect(res.statusCode).to.equal(500)
            done()
        )
    )

)
