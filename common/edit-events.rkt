#lang racket

(require racket/gui/base)
(require "./snip-data.rkt")

; Editor event will be one of
; (insert start:number snips:(List snip-data))
; (delete start:number len:number)
; (split-snip position:number) ; TODO Split and merge might not actually be necessary to send, especially if we split intelligently during a delete

; Hopefully merge-snip doesn't need to be implemented


;; NOTE This doesn't return anything
;; TODO The unlocking should be done by whatever is calling apply-to-text
(define-syntax-rule (with-unlock editor actions ...)
  (let* ([e editor]
         [prev-unlock (send e is-locked?)])
    (send e lock #f)
    actions ...
    (send e lock prev-unlock)))
   

(define edit-event<%>
  (interface ()
    [apply-to-text (->m (is-a?/c text%) void?)]))

(define edit-event-insert%
  (class* object% (edit-event<%>)
    (init-field start ; Start position : number
                snips) ; List of snips
    (super-new)
    (define/public (apply-to-text text)
      (with-unlock text
        (for/fold ([pos start])
                  ([snip snips])
          (define hydrated-snip (snip-data->snip snip))
          (send text insert hydrated-snip pos)
          (+ pos (send hydrated-snip get-count)))))))

(define edit-event-delete%
  (class* object% (edit-event<%>)
    (init-field start
                len)
    (super-new)
    (define/public (apply-to-text text)
      (with-unlock text
        (send text delete start (+ start len))))))

(define edit-event-split-snip%
  (class* object% (edit-event<%>)
    (init-field pos)
    (super-new)
    (define/public (apply-to-text text)
      (with-unlock text
        (send text split-snip pos)))))