hapi = require "hapi"
http-proxy = require 'http-proxy'

server = new hapi.Server!
        ..connection do
            port: 4001
            routes:
                cors: true
        ..register (require 'h2o2'), ->
        ..register (require 'inert'), ->
path = require \path

public-dir = path.join __dirname, "../../build/public"

proxy-as = \db
server.route do
    method: '*'
    path: "/#{proxy-as}/{f*}"
    handler:
        proxy:
            map-uri: (request, callback) ->
                resource-uri = request.url.path.replace("/#{proxy-as}/", '/')
                url = "https://demeter.cloudant.com/#{resource-uri}"
                console.log 'Proxying url: ', url
                callback(null,url)

            pass-through: true
            xforward: true

server.route do
    path: "/"
    method: "GET"
    handler:
        file: "#{public-dir}/pages/order.html"

server.route do
    path: "/{f*}"
    method: "GET"
    handler:
        directory:
            path: "#{public-dir}/pages"

server.start !->
    console.log "Server started at: ", server.info.uri
