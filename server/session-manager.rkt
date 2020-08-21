#lang racket

; A SessionInput is one of
; (client-connect client-info)
; (client-disconnect client-id) ; If a client disconnects without sending a message, or if the client sends a malformed message
; (client-msg client-id message) ; A client->server message from common/messages

; A SessionState is a
; (session-state clients:(List client-info) current-host:number DocInfo)

; A DocInfo is one of
; (no-document-uploaded)
; (document base-revision incremental-edits:(List edit-event))

; A ClientResponse is one of
; (client-msg client-id message) ; A server->client message
; (client-disconnect client-id) ; Close the TCP socket

; A SessionOutput is a (List ClientResponse)

; SessionInput SessionState -> (values SessionOutput SessionState)
(define (server sinput sstate)
  '())