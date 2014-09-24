DEFAULT_TIMEOUT = 10000

logger = {
    debug: () ->
    info: () ->
}

exports.get = (url, headers, opts, callback) ->
    if !callback and typeof opts is "function"
        callback = opts
        opts = null
    opts ?= {}

    logger.debug "GET to url #{url}"

    url = require("url").parse url
    options =
        hostname: url.hostname
        port: url.port
        path: url.path
        method: "GET"
        headers: {}

    if headers?
        for h of headers
            options.headers[h] = headers[h]

    protocol = if url.protocol is "https:" then require("https") else require("http")

    get_request = protocol.request options, (res) ->
        buf = new Buffer(0)
        res.on 'data', (chunk) ->
            buf = Buffer.concat [buf, chunk]
        res.on 'end', () ->
            res_body = buf.toString "UTF-8"
            callback && callback null, res.statusCode, res_body

    get_request.on "error", (e) ->
        callback && callback e

    timeout = opts.timeout
    timeout ?= DEFAULT_TIMEOUT
    get_request.setTimeout timeout, () ->
        err = "Connection timeout in #{timeout} ms"
        callback && callback err

    get_request.end()

exports.parseForm = (str) ->
    logger.debug "typeof str #{typeof str}"
    pairs = str.split("&")
    params = {}
    for pair in pairs
        key_value = pair.split("=")
        params[key_value[0]] = key_value[1]

    return params

#
# Post form content to url
#
exports.postForm = (url, body, callback) ->
    exports.post url, "application/x-www-form-urlencoded", null, body, callback

exports.post = (url, content_type, headers, body, opts, callback) ->
    if !callback and typeof opts is "function"
        callback = opts
        opts = null
    opts ?= {}

    logger.debug "POST to url #{url} with body of content type #{content_type}", body

    url = require("url").parse url
    options =
        hostname: url.hostname
        port: url.port
        path: url.path
        method: "POST"
        headers:
            "Content-Type": content_type
            "Content-Length": body.length

    if headers?
        for h of headers
            options.headers[h] = headers[h]

    protocol = if url.protocol is "https:" then require("https") else require("http")

    post_request = protocol.request options, (res) ->
        buf = new Buffer(0)
        res.on 'data', (chunk) ->
            buf = Buffer.concat [buf, chunk]
        res.on 'end', () ->
            res_body = buf.toString "UTF-8"
            callback && callback null, res.statusCode, res_body

    post_request.on "error", (e) ->
        callback && callback e, res.statusCode, res_body

    timeout = opts.timeout
    timeout ?= DEFAULT_TIMEOUT
    post_request.setTimeout timeout, () ->
        err = "Connection timeout in #{timeout} ms"
        callback && callback err

    post_request.write(body)
    post_request.end()
