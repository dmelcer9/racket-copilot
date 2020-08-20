#lang racket

(require racket/gui/base)



(define edit-event<%>
  (interface ()
    [apply-to-editor (->m (is-a?/c text%) void?)]))

(define edit-event-insert%
  (class* object% (edit-event<%>)
    (init-field start ; Start position : number
                snips ; 
     (super-new)