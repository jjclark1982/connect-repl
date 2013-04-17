# connect-repl

Password-protected interactive prompt for examining a running [Connect](http://www.senchalabs.org/connect/) or [Express](http://expressjs.com/) server

## Usage

    var connect = require('connect');
    var repl = require('connect-repl');

    var app = connect();
    app.use(connect.bodyParser());
    app.use('/console', repl({
        title: 'Admin Console',
        username: 'admin',
        context: global,
        languages: ['JavaScript', 'CoffeeScript', 'Shell']
    }));

    app.listen(3000);

## To Do

- make clicking on "Loading..." hang up the request,
and make hanging up a request cancel the job if possible

- allow long-running processes to trickle in one line at a time,
maybe with an onreadystatechange handler
