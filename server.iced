express = require("express")
http_utils = require("./http_utils")

QNAP_APP_INFO = {
    app_id : "51b178b0b86f7b5338346b71"
    secret : "26YWyuTEk50bToMXLCtQ"
    redirect_uri : "http://flydrop.com:3000/oauth"
    scope : [ "device", "favorite" ]
}

app = express()
app.root = process.cwd()

# Basic express setup
app.use express.bodyParser()
app.use express.cookieParser('secret')
app.sessionStore = new express.session.MemoryStore()
app.use express.session({key: 'express.sid', store: app.sessionStore, cookie: {maxAge:5*60*1000} })
app.use app.router 
app.use express.static(app.root + "/public")
app.set 'view engine', 'ejs'
app.set 'views', "#{app.root}/views"

# Create http/https server
port = 3000
server = require("http").createServer(app) 

api_server = "http://api.qcloud.com:8080"
#api_server = "https://dev-api.dev-myqnapcloud.com"
#api_server = "https://qa-api-nr.api.dev-myqnapcloud.com"

# Routes
app.get "/", (req, res) ->
    if !req.session.user 
        return res.redirect "/login.html"

    res.redirect "/main.html"

app.get "/login.html", (req, res) ->
    res.render "login",
        app: QNAP_APP_INFO
        api_server: api_server

app.get "/oauth", (req, res) ->
    # Get auth code
    auth_code = req.param("code")
    status = req.param("status")
    error = req.param("error")
    error_description = req.param("error_description")
    state = req.param("state")

    switch status 
        when "back"
            console.log "back, state=", state

            if state == "backend"
                res.redirect "/main_backend"
            else
                res.redirect "/main_frontend"

        when "signed_out"
            delete req.session.user
            res.redirect "/"

        else
            if error
                res.render "error",
                    error: error
                    error_description: error_description

            else if auth_code
                console.log "Get auth_code", auth_code
                req.session.auth_code = auth_code

                # Authorization code flow callback
                token_response = {}
                    
                # Exchange for access token
                token_endpoint = "#{api_server}/oauth/token" 
                body = "grant_type=authorization_code&client_id=#{QNAP_APP_INFO.app_id}&client_secret=#{QNAP_APP_INFO.secret}&code=#{auth_code}&redirect_uri=#{QNAP_APP_INFO.redirect_uri}"
                await http_utils.postForm token_endpoint, body, defer err, return_code, response

                if err
                    console.log("ERROR", err)

                token_response = JSON.parse(response)
                console.log("RESPONSE /oauth/token", token_response)

                req.session.token_response = token_response

                if token_response and token_response.access_token
                    req.session.access_token = token_response.access_token

                    res.redirect "/main_backend"
                
            else
                # Implicit flow callback
                res.render "main_frontend",
                    app: QNAP_APP_INFO
                    api_server: api_server
                

app.get "/main_backend", (req, res) ->
    # Get me profile from API
    api_url = "#{api_server}/v1.1/me"
    content_type = "application/json"
    headers = {
        "Authorization": "Bearer " + req.session.access_token
    }
    await http_utils.get api_url, headers, defer err, return_code, response

    me_response = JSON.parse(response)
    console.log("RESPONSE /me", me_response)
    result = me_response.result
    
    res.render "main_backend",
        auth_code: req.session.auth_code
        token_response: req.session.token_response
        me_response: me_response
        api_server: api_server
        app: QNAP_APP_INFO

requireAuth = (req, res, next) ->
    if req.session.user?
        return next()

    res.redirect "/login.html"


server.listen(port)