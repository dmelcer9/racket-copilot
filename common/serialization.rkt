#lang racket

(define communication-serializer<%>
  (interface ()
    serialize-client->server-message
    deserialize-client-server-message
    serialize-server->client-message
    deserialize-server->client-message))
