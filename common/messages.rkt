#lang racket

; A Client->Server Message is one of
; Initialization messages:
; (msg-new-session name:string version:number) ; Server verifies that version matches and rejects connection otherwise, proper backward compatibility is hard
; (msg-join-session name:string version:number session-info) ; Will receive a base revision and multiple incremental edits
; Anyone can send this:
; (msg-disconnect) ; If host disconnects without transferring host priveliges, everyone disconnects
; Only host can send this:
; (msg-base-revision file:bytes)
; (msg-incremental-edit edit-event) ; From edit-events.rkt
; (msg-transfer-host user-id:number) 
; Only readers can send this:
; (msg-request-new-base-revision) ; Should possibly be rate-limited


; A Server->Client Message is one of
; (msg-wrong-version server-version:number) ; The server number should be incremented for breaking changes to the communication protocol
; Sent to host:
; (msg-new-session-info you:user-name+id session-info)
; Sent to readers:
; (msg-disconnect) ; If host disconnects
; (msg-base-revision file:bytes) ; TODO Should revisions have (server-assigned) IDs? Will add later if needed.
; (msg-incremental-edit edit-event) ; If revisions have IDs, incremental edits would have the base revision ID and a serial number.
; (msg-request-new-base-revision) ; Will be sent to current writer if someone else requests
; Sent to everyone after every join, leave, or host change
; (msg-participant-info you:user-name+id others:(List user-name+id) host-id:number)



(struct user-name+id [name id])
(struct session-info [id pass])