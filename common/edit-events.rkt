#lang racket

(require racket/gui/base)

; Editor event will be one of
; (insert start:number snips:(List snip-data))
; (delete start:number len:number)
; (split-snip position:number) ; TODO Split and merge might not actually be necessary to send, especially if we split intelligently during a delete
; (merge-snip position:number)

(define edit-event<%>
  (interface ()
    [apply-to-editor (->m (is-a?/c text%) void?)]))

#;(define edit-event-insert%
  (class* object% (edit-event<%>)
    (init-field start ; Start position : number
                snips ; 
     (super-new))))