express = require("express")
http_utils = require("./http_utils")

QNAP_APP_INFO = {
    secret : "26YWyuTEk50bToMXLCtQ"
    app_id : "51b178b0b86f7b5338346b71"
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
    auth_error = req.param("error")

    if auth_code
        # Authorization code flow callback

        # Exchange for access token
        token_endpoint = "#{api_server}/v1.1/oauth/token" 
        body = "grant_type=authorization_code&client_id=#{QNAP_APP_INFO.app_id}&client_secret=#{QNAP_APP_INFO.secret}&code=#{auth_code}&redirect_uri=#{QNAP_APP_INFO.redirect_uri}"
        await http_utils.postForm token_endpoint, body, defer err, return_code, response

        token_response = JSON.parse(response)
        console.log("RESPONSE /oauth/token", token_response)

        if token_response and token_response.access_token
            # Get me profile from API
            api_url = "#{api_server}/v1.1/me"
            content_type = "application/json"
            headers = {
                "Authorization": "Bearer " + token_response.access_token
            }
            await http_utils.get api_url, headers, defer err, return_code, response

            me_response = JSON.parse(response)
            console.log("RESPONSE /me", me_response)
            result = me_response.result
        
        res.render "main_backend",
            auth_code: auth_code
            auth_error: auth_error
            token_response: token_response
            me_response: me_response

    else
        # Implicit flow callback
        res.render "main_frontend",
            app: QNAP_APP_INFO
            api_server: api_server

requireAuth = (req, res, next) ->
    if req.session.user?
        return next()

    res.redirect "/login.html"


server.listen(port)