#lang info

(define collection "racket-copilot")
(define deps '("base"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/racket-copilot.scrbl" ())))
(define pkg-desc "Description Here")
(define version "0.0")
(define pkg-authors '(Daniel Melcer))

(define drracket-tool-names (list "Tool Name"))
(define drracket-tools (list (list "tool.rkt")))
