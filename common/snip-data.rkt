#lang racket
(require racket/gui)

(provide
 (struct-out snip-data)
 (contract-out
  [snip->snip-data (-> (is-a?/c snip%) snip-data?)]
  [snip-data->snip (-> snip-data? (is-a?/c snip%))]))

; The data needed to represent a snip
; See https://groups.google.com/g/racket-users/c/QcfTCnD-9bo for discussion on security
(struct snip-data [snip-class snip-bytes])

(define (snip->snip-data snip)
  (define bytes-base-out (new editor-stream-out-bytes-base%))
  (define stream-out (make-object editor-stream-out% bytes-base-out))
  (send snip write stream-out)  
  (define bytes (send bytes-base-out get-bytes))
  (define snip-class-name (send (send snip get-snipclass) get-classname))
  (snip-data snip-class-name bytes))

(define (snip-data->snip data)
  (match-define (snip-data snip-class-name snip-bytes) data)
  (define snip-class (send (get-the-snip-class-list) find snip-class-name))
  (define bytes-base-in (make-object editor-stream-in-bytes-base% snip-bytes))
  (define editor-stream-in (make-object editor-stream-in% bytes-base-in))
  (send snip-class read editor-stream-in))
