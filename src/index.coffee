util = require("util")
connect = require("connect")
vm = require("vm")
child_process = require("child_process")

languages = ["JavaScript"]
try
    coffeeScript = require("coffee-script")
    languages.push("CoffeeScript")
languages.push("Shell")

template = ""

module.exports = (options = {})->
    context = vm.createContext(options.context or {})

    options.title ?= "Admin Console"
    template = template.replace(/\{\{title\}\}/g, options.title)

    options.languages ?= languages
    languagesHtml = ("<option value=\"#{language}\">#{language}</option>" for language in options.languages).join("\n")
    template = template.replace("{{languages}}", languagesHtml)

    auth = (req, res, next)->next()
    if process.env.NODE_ENV isnt 'development'
        unless options.password?
            options.password = ""
            for i in [1..40]
                options.password += Math.floor(Math.random()*36).toString(36)
            console.log("#{options.title or 'REPL'} password:", options.password)

        auth = connect.basicAuth(options.username or "admin", options.password)

    ensureBody = (req, res, next)->
        if req.body?
            next()
        else
            connect.bodyParser()(req, res, next)

    middleware = (req, res, next)->
        res.setHeader("Access-Control-Allow-Methods", "OPTIONS, HEAD, GET, POST")
        switch req.method
            when 'OPTIONS', 'HEAD'
                res.writeHead(204)
                res.end()

            when 'GET'
                res.end(template.replace("{{_csrf}}", req.session?._csrf or ''))

            when 'POST'
                auth(req, res, -> ensureBody(req, res, ->
                    language = req.body.language or 'JavaScript'
                    remoteAddr = req.headers["x-forwarded-for"] or req.socket.remoteAddress
                    console.log("Evaluating #{language} expression from #{remoteAddr}:", req.body.expression)
                    try
                        context.app = req.app
                        context.req = req
                        context.res = res
                        context.next = next
                        switch language
                            when 'Shell'
                                res.setHeader('Content-Type', 'text/html')
                                res.writeContinue()
                                child = child_process.spawn('sh', ['-c', req.body.expression])
                                child.stdout.on('data', (data)->
                                    res.write(escapeHTML(data)) if res.connection?.writable
                                )
                                child.stderr.on('data', (data)->
                                    res.write("<i>#{escapeHTML(data)}</i>") if res.connection?.writable
                                )
                                child.on('exit', (code, signal)->
                                    return unless res.connection?.writable
                                    if code
                                        res.write("<p class='error'>Exit #{code}</p>")
                                    if signal
                                        res.write("<p class='error'>Killed by #{signal}</p>")
                                    res.end()
                                )
                                child.stdin.end()
                                return
                            when 'CoffeeScript'
                                result = coffeeScript.eval(req.body.expression, {sandbox: context})
                            else
                                result = vm.runInContext(req.body.expression, context)
                        result = util.inspect(result)
                    catch e
                        result = e.toString()
                        res.statusCode = 500

                    return unless res.connection?.writable
                    if (!req.headers['accept'] or req.headers['accept'].indexOf('*/*') isnt -1 or req.headers['accept'].indexOf('text/plain') isnt -1)
                        res.setHeader('Content-Type', 'text/plain')
                        res.end(result)
                    else
                        res.setHeader('Content-Type', 'text/html')
                        page = template.replace("{{_csrf}}", req.session?._csrf or '')
                            .replace('<pre id="history"></pre>', """
                                <pre id="history">
                                <b class="expression" data-language="#{req.body.language}">#{escapeHTML(req.body.expression)}</b>
                                <p class="result#{if res.statusCode is 500 then ' error' else ''}">#{escapeHTML(result)}</p></pre>
                            """)
                        res.end(page)
                ))

            else
                next(405)

    return middleware

escapeHTML = (text)->
    return text.toString().replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")

template = """
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>{{title}}</title>
    <style>
        #history .expression:before { content: "> "; }
        #history .expression { font-weight: bold; cursor: pointer; white-space: pre-line; }
        #history .error { color: red; }
        #history .loading:after { content: "Loading..."; color: orange; }
        input[name="expression"] { font-family: monospace; width: 100%; display: inline-block; box-sizing: border-box; margin: 0.5em 0; }
    </style>
</head>
<body>
    <h2>{{title}}</h2>
    <pre id="history"></pre>
    <form method="post">
        <input type="hidden" name="_csrf" value="{{_csrf}}" />
        <input type="text" name="expression" value="" autofocus />
        <br/>
        <input type="submit" value="Evaluate" />
        <select name="language">
            {{languages}}
        </select>
    </form>
    <script src="http://code.jquery.com/jquery-1.9.1.min.js"></script>
    <script>
        $("form").on('submit', function(event){
            event.preventDefault();
            $form = $(event.target);
            if ($form.data("submitting")) {
                return;
            }
            $form.data("submitting", true);
            $('[type="submit"]', $form).attr("disabled", true);

            var $expression = $('<b class="expression" data-language="'+$('[name="language"]', $form).val()+'">');
            $expression.text($('[name="expression"]', event.target).val());
            var $result = $('<p class="result loading"></p>');
            $("#history").append($expression, $result);

            document.body.scrollTop = document.body.scrollHeight;

            window.xhr = $.ajax({
                url: $form[0].action || document.location.pathname,
                type: "POST",
                cache: false,
                data: $form.serialize(),
                complete: function(xhr, textStatus) {
                    $result.removeClass("loading");
                    $result.addClass(textStatus);
                    if (xhr.getResponseHeader('Content-Type') == 'text/html') {
                        $result.html(xhr.responseText);
                    }
                    else {
                        $result.text(xhr.responseText || xhr.statusText);
                    }
                    $(document.body).animate({scrollTop: document.body.scrollHeight});
                    $('[name="expression"]', $form).select();

                    $form.data("submitting", false);
                    $('[type="submit"]', $form).removeAttr("disabled");
                }
            });
        });
        $("#history").delegate(".expression", "click", function(event){
            var $expression = $(event.target);
            var text = $expression.text();
            $('[name="language"]').val($expression.data()['language']);
            $('[name="expression"]').val(text).select();
            document.body.scrollTop = document.body.scrollHeight;
        });
    </script>
</body>
"""
