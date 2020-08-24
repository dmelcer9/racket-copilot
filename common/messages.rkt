#lang racket

(define-syntax-rule (struct-out-all x ...) (provide (struct-out x) ...))

(struct-out-all
  client-info
  session-info

  error-version-mismatch
  error-not-allowed-by-role
  error-illegal-state

  msg-new-session
  msg-join-session
  msg-base-revision
  msg-incremental-edit
  msg-transfer-host
  msg-request-new-base-revision
  msg-error
  msg-new-session-info
  msg-participant-info)

; A Client->Server Message is one of
; Initialization messages:
; - (msg-new-session name:string version:number) ; Server verifies that version matches and rejects connection otherwise, proper backward compatibility is hard
; - (msg-join-session name:string version:number session-info) ; Will receive a base revision and multiple incremental edits
; Anyone can send this:
; - Implicit message- TCP disconnection ; If host disconnects without transferring host priveliges, everyone disconnects
; Only host can send this:
; - (msg-base-revision file:bytes)
; - (msg-incremental-edit edit-event) ; From edit-events.rkt
; - (msg-transfer-host user-id:number) 
; Only readers can send this:
; - (msg-request-new-base-revision) ; Should possibly be rate-limited


; A Server->Client Message is one of
; - (msg-error ErrorType) ; The server number should be incremented for breaking changes to the communication protocol
; Sent to host:
; - (msg-new-session-info you:client-info session-info)
; Sent to readers:
; - (msg-base-revision file:bytes) ; TODO Should revisions have (server-assigned) IDs? Will add later if needed.
; - (msg-incremental-edit edit-event) ; If revisions have IDs, incremental edits would have the base revision ID and a serial number.
; - (msg-request-new-base-revision) ; Will be sent to current writer if someone else requests
; Sent to everyone after every join, leave, or host change
; - (msg-participant-info you:client-info others:(List client-info) host-id:number)
; - Implicit message: TCP disconnection

; An ErrorType is one of:  ; Does not automatically disconnect, need to do so separately if desired
; - (error-version-mismatch expected-version)
; - (error-not-allowed-by-role)
; - (error-illegal-state) ; Like when sending an incremental revision without a base revision

(struct client-info [name id] #:transparent)
(struct session-info [id pass] #:transparent)

(struct error-version-mismatch [expected-version] #:transparent)
(struct error-not-allowed-by-role [] #:transparent)
(struct error-illegal-state [] #:transparent)

(struct msg-new-session [name version] #:transparent)
(struct msg-join-session [name version session-info] #:transparent)
(struct msg-base-revision [file] #:transparent)
(struct msg-incremental-edit [edit-event] #:transparent)
(struct msg-transfer-host [new-user] #:transparent)
(struct msg-request-new-base-revision [] #:transparent)
(struct msg-error [error-info] #:transparent)
(struct msg-new-session-info [you session-info] #:transparent)
(struct msg-participant-info [you others host-id] #:transparent)