#lang racket

(require "../common/messages.rkt")

; A SessionInput is one of
; (sess-client-connect client-info)
; (sess-client-disconnect client-id) ; If a client disconnects without sending a message, or if the client sends a malformed message
; (sess-client-msg client-id message) ; A client->server message from common/messages

(struct sess-client-connect [client-info] #:transparent)
(struct sess-client-disconnect [client-id] #:transparent)
(struct sess-client-msg [client-id msg] #:transparent)


; A SessionState is
; (session-state clients:(List client-info) current-host:number DocInfo)
; Note that it is created already with a current-host

; A SessionOutputState is one of
; SessionState
; (session-state-end) ; Process SessionOutput, then clean up all resources used by this session

(struct session-state [clients current-host doc-info] #:transparent)
(struct session-state-end [] #:transparent)

; A DocInfo is one of
; (no-document)
; (document base-revision incremental-edits:(List edit-event)) ; Early edits at end of list, new edits at beginning of list

(struct no-document [] #:transparent)
(struct document [base-rev incremental-edits] #:transparent)

; A ClientResponse is one of
; (sess-client-msg client-id message) ; A server->client message
; (sess-client-disconnect client-id) ; Close the TCP socket

; (Re-use the structs from SessionInput)

; A SessionMessages is a (List ClientResponse)

; A SessionOutput is a (session-output SessionMessages SessionOutputState)

(struct session-output [messages state] #:transparent)


; SessionInput SessionState -> SessionOutput
(define (server sinput sstate)
  (match-define (session-state clients current-host doc-info) sstate)
  (match sinput
    [(sess-client-connect client-info) ; Connect new client
     (define new-sstate (sstate-connect-new sstate client-info))
     (define messages (participant-info-messages new-sstate))
     (session-output messages new-sstate)]
    [_ (session-output '() '())]))


(module+ test
  (require rackunit)

  (define c1 (client-info "Client 1" 1))
  (define c2 (client-info "Client 2" 2))
  (define c3 (client-info "Client 3" 3))
  (define b0 (bytes 0))
  (define b1 (bytes 1))
  (define b2 (bytes 2))

  (define edit-evt-1 'edit-evt-1) ; Edit events should be opaque
  (define incr-edit-1 (msg-incremental-edit edit-evt-1))
  (define edit-evt-2 'edit-evt-2)
  (define incr-edit-2 (msg-incremental-edit edit-evt-2))
  (define edit-evt-3 'edit-evt-3)
  (define incr-edit-3 (msg-incremental-edit edit-evt-3))

  ; States for testing joining
  (define newly-created-server-state (session-state (list c1) 1 (no-document)))
  (define server-state-after-first-join (session-state (list c1 c2) 1 (no-document)))

  ; States for testing revisions
  (define server-state-base-revision (session-state (list c1 c2) 1 (document b0 '())))
  (define server-state-one-revision (session-state (list c1 c2) 1 (document b0 (list edit-evt-1))))
  (define server-state-two-revisions (session-state (list c1 c2) 1 (document b0 (list edit-evt-2 edit-evt-1))))

  ; States for testing >2 clients
  (define server-state-two-revisions-three-clients (session-state (list c1 c2 c3) 1 (document b0 (list edit-evt-2 edit-evt-1))))
  (define server-state-base-revision-three-clients (session-state (list c1 c2 c3) 1 (document b1 '())))
  (define server-state-three-revisions-three-clients (session-state (list c1 c2 c3) 1 (document b0 (list edit-evt-3 edit-evt-2 edit-evt-1))))

  ; States for testing transfer host and disconnect
  (define server-state-three-clients-c2-host (session-state (list c1 c2 c3) 2 (document b1 '())))
  (define server-state-three-clients-c1-disconnect (session-state (list c2 c3) 2 (document b1 '())))

  (define two-clients-participant-info (list (sess-client-msg 1 (msg-participant-info c1 (list c2) 1))
                                             (sess-client-msg 2 (msg-participant-info c2 (list c1) 1))))
  
  ; Join server with no document
  (check-equal? (server (sess-client-connect c2) newly-created-server-state)
                (session-output two-clients-participant-info
                                server-state-after-first-join))

  ; Non-host sending document
  (check-equal? (server (sess-client-msg 2 (msg-base-revision b0)) server-state-after-first-join)
                (session-output (list (sess-client-msg 2 (msg-error (error-not-allowed-by-role))))
                                server-state-after-first-join))

  ; Send incremental revision before base revision
  (check-equal? (server (sess-client-msg 1 incr-edit-1) server-state-after-first-join)
                (session-output (list (sess-client-msg 1 (msg-error (error-illegal-state))))
                                server-state-after-first-join))

  ; Send base revision
  (check-equal? (server (sess-client-msg 1 (msg-base-revision b0)) server-state-after-first-join)
                (session-output (list (sess-client-msg 2 (msg-base-revision b0)))
                                server-state-base-revision))

  ; Send two edit revisions
  (check-equal? (server (sess-client-msg 1 incr-edit-1) server-state-base-revision)
                (session-output (list (sess-client-msg 2 incr-edit-1)) server-state-one-revision))
  (check-equal? (server (sess-client-msg 1 incr-edit-2) server-state-one-revision)
                (session-output (list (sess-client-msg 2 incr-edit-2)) server-state-two-revisions))

  ; Client joins after base and some revisions
  (check-equal? (server (sess-client-connect c3) server-state-two-revisions)
                (session-output (list (sess-client-msg 1 (msg-participant-info c1 (list c2 c3) 1)) ; Participant infos
                                      (sess-client-msg 2 (msg-participant-info c2 (list c1 c3) 1))
                                      (sess-client-msg 3 (msg-participant-info c3 (list c1 c2) 1))
                                      (sess-client-msg 3 (msg-base-revision b0)) ; Base revision to c3
                                      (sess-client-msg 3 incr-edit-1) ; All incremental edits
                                      (sess-client-msg 3 incr-edit-2))
                                server-state-two-revisions-three-clients))

  ; Send base revision to multiple clients
  (check-equal? (server (sess-client-msg 1 (msg-base-revision b1)) server-state-two-revisions-three-clients)
                (session-output (list (sess-client-msg 2 (msg-base-revision b1))
                                      (sess-client-msg 3 (msg-base-revision b1)))
                                server-state-base-revision-three-clients))

  ; Send incremental edit to multiple clients
  (check-equal? (server (sess-client-msg 1 incr-edit-3) server-state-two-revisions-three-clients)
                (session-output (list (sess-client-msg 2 incr-edit-3)
                                      (sess-client-msg 3 incr-edit-3))
                                server-state-three-revisions-three-clients))

  ; Host transfers control
  (check-equal? (server (sess-client-msg 1 (msg-transfer-host 2)) server-state-base-revision-three-clients)
                (session-output (list (sess-client-msg 1 (msg-participant-info c1 (list c2 c3) 2))
                                      (sess-client-msg 2 (msg-participant-info c2 (list c1 c3) 2))
                                      (sess-client-msg 3 (msg-participant-info c3 (list c1 c2) 2)))
                                server-state-three-clients-c2-host))
  
  ; Non-host tries transferring control
  (check-equal? (server (sess-client-msg 1 (msg-transfer-host 2)) server-state-three-clients-c2-host)
                (session-output (list (sess-client-msg 1 (msg-error (error-not-allowed-by-role))))
                                server-state-three-clients-c2-host))
  
  ; Disconnect host
  (check-equal? (server (sess-client-disconnect 2) server-state-three-clients-c2-host)
                (session-output (list (sess-client-disconnect 1)
                                      (sess-client-disconnect 3))
                                (session-state-end)))
                        
  ; Disconnect non-host
  (check-equal? (server (sess-client-disconnect 1) server-state-three-clients-c2-host)
                (session-output (list (sess-client-msg 2 (msg-participant-info c2 (list c3) 2))
                                      (sess-client-msg 3 (msg-participant-info c3 (list c2) 2)))
                                server-state-three-clients-c1-disconnect)))


; SessionState ClientInfo -> SessionState
; Add a participant to the session state
(define (sstate-connect-new sstate client-info)
  (match-define (session-state clients current-host doc-info) sstate)
  (session-state (append clients (list client-info)) current-host doc-info))

(module+ test
  (check-equal? (sstate-connect-new newly-created-server-state c2) server-state-after-first-join))

; SessionState -> (List ClientResponse)
(define (participant-info-messages sstate)
  (match-define (session-state clients current-host doc-info) sstate)
  (for/list ([client clients]) ; client:ClientInfo
    (sess-client-msg (client-info-id client)
                     (msg-participant-info client
                                           (filter (λ (c) (not (equal? c client))) clients)
                                           current-host))))

(module+ test
  (check-equal? (participant-info-messages server-state-after-first-join) two-clients-participant-info))