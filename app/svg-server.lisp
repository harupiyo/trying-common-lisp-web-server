;;; 評価したあと、
;;; http://localhost:8000/
;;; から動作確認可能

(ql:quickload '(:hunchentoot :cl-svg :cl-who :parenscript))
(defpackage svg-server
  (:shadow cl-svg:stop) ; hunchentoot:stop とかぶるため
  (:use :cl :parenscript :cl-who :cl-svg :hunchentoot))
(in-package :svg-server)

;;; start http server

(defparameter accepter (make-instance 'hunchentoot:easy-acceptor :port 8000 :document-root "./web"))
(hunchentoot:start accepter)

;;; Making SVG API

(hunchentoot:define-easy-handler (svg :uri "/api/svg") (name)
  (setf (hunchentoot:content-type*) "image/svg+xml")
  (let ((canvas (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 100 :width 1200)))
    (svg:text canvas (:x 10 :y 50 :font-family "serif" :font-size 50)
      name) ; URL parts
    (let ((svg-string (with-output-to-string (string)
                        (svg:stream-out string canvas) string)))
      svg-string)))

;;; input form

(setf (cl-who:html-mode) :html5)
(setf cl-who:*attribute-quote-char* #\")

(hunchentoot:define-easy-handler (index :uri "/") ()
  (with-html-output-to-string (s nil :prologue t :indent t)
    (:html
      (:head
        (:title "SVG TEXT GENERATOR")
        (:meta :charset "UTF-8")
        (:link :rel "stylesheet" :href "web/style.css")
        (:link :rel "icon" :type "image/vnd.microsoft.icon" :href "web/favicon.ico")) ; favicon を.png にしたければ :type "image/png" とする
      (:body
        (:header
          (:h1 "SVG TEXT GENERATOR")
             (:input :type "text")
             (:input :type "submit"))
       (:div :id "svg-container")
       (:footer (:img :id "made-with-lisp" :src "web/Lisp-glossy-120.jpg" :alt "Made with Lisp."))
       (:script :src "web/glue.js")))))

