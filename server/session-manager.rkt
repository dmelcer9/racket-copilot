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
     (define new-sstate (sstate-connect-new sstate client-info)) ; TODO Send doc to new person
     (define messages (append (participant-info-messages new-sstate) (document->messages doc-info (client-info-id client-info))))
     (session-output messages new-sstate)]
    [(sess-client-disconnect discon-id)
     #:when (equal? current-host discon-id)
     (session-output (host-disconnect-messages sstate) (session-state-end))]
    [(sess-client-disconnect discon-id)
     (define new-sstate (sstate-disconnect sstate discon-id))
     (define messages (participant-info-messages new-sstate))
     (session-output messages new-sstate)]
    [(sess-client-msg id msg) (server-client-msg id msg sstate)]))

; Number Client->ServerMessage SessionState -> SessionOutput
; Same as server, but specifically for client messages
(define (server-client-msg sending-client-id msg sstate)
  (match-define (session-state clients current-host doc-info) sstate)
  (define (make-error-output error)
    (session-output (list (sess-client-msg sending-client-id (msg-error error))) sstate))
  
  (match msg
    [(or (msg-new-session _ _)
         (msg-join-session _ _ _)) ; Messages that this server doesn't handle
     (make-error-output (error-illegal-state))]
    [(or (msg-base-revision _)
         (msg-incremental-edit _)
         (msg-transfer-host _))
     #:when (not (equal? sending-client-id current-host))
     (make-error-output (error-not-allowed-by-role))]
    [(msg-base-revision file)
     (define new-sstate (session-state clients current-host (document file '())))
     (define messages (send-msg-to-all-except-host sstate (λ (client) (sess-client-msg (client-info-id client) (msg-base-revision file)))))
     (session-output messages new-sstate)]
    [(msg-incremental-edit edit)
     #:when (no-document? doc-info)
     (make-error-output (error-illegal-state))]
    [(msg-incremental-edit edit)
     (match-define (document base revs) doc-info)
     (define new-sstate (session-state clients current-host (document base (cons edit revs))))
     (define messages (send-msg-to-all-except-host sstate (λ (client) (sess-client-msg (client-info-id client) (msg-incremental-edit edit)))))
     (session-output messages new-sstate)]
    [(msg-transfer-host new-host) ; Not a valid host
     #:when (not (ormap (λ (client) (equal? (client-info-id client) current-host)) clients))
     (make-error-output (error-illegal-state))]
    [(msg-transfer-host new-host)
     (define new-sstate (session-state clients new-host doc-info))
     (define messages (participant-info-messages new-sstate))
     (session-output messages new-sstate)]
    [(msg-request-new-base-revision)
     #:when (equal? sending-client-id current-host)
     (make-error-output (error-not-allowed-by-role))]
    [(msg-request-new-base-revision)
     (define messages (list (sess-client-msg current-host (msg-request-new-base-revision))))
     (session-output messages sstate)]))
                                

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

; SessionState number -> SessionState
; Disconnect participant in session state
; ASSUME participant is not host
(define (sstate-disconnect sstate client-id)
  (match-define (session-state clients current-host doc-info) sstate)
  (define new-clients (filter (λ (c) (not (equal? (client-info-id c) client-id))) clients))
  (session-state new-clients current-host doc-info))

(module+ test
  (check-equal? (sstate-connect-new newly-created-server-state c2) server-state-after-first-join)
  (check-equal? (sstate-disconnect server-state-three-clients-c2-host 1) server-state-three-clients-c1-disconnect))

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

; SessionState [ClientInfo -> ClientResponse] -> (List ClientResponse)
(define (send-msg-to-all-except-host sstate message-gen)
  (match-define (session-state clients current-host _) sstate)
  (for/list ([client clients]
             #:when (not (equal? (client-info-id client) current-host)))
    (message-gen client)))

; SessionState -> (List ClientResponse)
(define (host-disconnect-messages sstate)
  (send-msg-to-all-except-host
   sstate
   (λ (client) (sess-client-disconnect (client-info-id client)))))

(module+ test
  (check-equal? (host-disconnect-messages server-state-three-clients-c2-host)
                (list (sess-client-disconnect 1)
                      (sess-client-disconnect 3))))

; Document Number -> (List ClientResponse)
(define (document->messages doc send-id)
  (match doc
    [(no-document) '()]
    [(document base incr-edits)
     (cons (sess-client-msg send-id (msg-base-revision base))
           (map (λ (edit) (sess-client-msg send-id (msg-incremental-edit edit)))
                (reverse incr-edits)))]))

(module+ test
  (check-equal? (document->messages (no-document) 1) '())
  (check-equal? (document->messages (document b0 '()) 1)
                (list (sess-client-msg 1 (msg-base-revision b0))))
  (check-equal? (document->messages (document b0 (list edit-evt-2 edit-evt-1)) 1)
                (list (sess-client-msg 1 (msg-base-revision b0))
                      (sess-client-msg 1 (msg-incremental-edit edit-evt-1))
                      (sess-client-msg 1 (msg-incremental-edit edit-evt-2)))))