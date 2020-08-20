#lang racket

(provide (contract-out
          [port->js-channel (-> input-port? channel?)]))

(require json)

; TODO Make sure the thread is garbage collected if the channel is thrown away
; Maybe parameterize current-custodian before calling this
; Treat non-json as an EOF and close the port
; Channel outputs jsexpr or eof
(define (port->js-channel port)
  (define ch (make-channel))
  (thread (λ ()
            (let loop ()
              (define next-val
                (with-handlers ([exn:fail? (λ (e) eof)])
                  (read-json port)))
              (when (eof-object? next-val) (close-input-port port))
              (channel-put ch next-val)
              (unless (eof-object? next-val) (loop)))))
  ch)

(module+ test
  (require rackunit)

  (define (get-full-channel-output ch)
    (let loop ([val (channel-get ch)])
      (if (eof-object? val)
          (list val)
          (cons val (loop (channel-get ch))))))

  (define (output-from-str s)
    (define port (open-input-string s))
    (get-full-channel-output (port->js-channel port)))

  (check-equal? (output-from-str "") (list eof))
  (check-equal? (output-from-str "2 \n   6") (list 2 6 eof))
  (check-equal? (output-from-str "2 foo 7") (list 2 eof)))

