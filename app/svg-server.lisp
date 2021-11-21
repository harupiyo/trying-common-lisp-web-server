;;; 評価したあと、
;;; http://localhost:8000/
;;; から動作確認可能

(ql:quickload '(:hunchentoot :cl-svg :cl-who))
(defpackage svg-server
  (:shadow cl-svg:stop) ; hunchentoot:stop とかぶるため
  (:use :common-lisp :cl-who :cl-svg :hunchentoot))
(in-package :svg-server)

;;; Setup & starting http server

(defparameter *acceptor* (make-instance 'hunchentoot:easy-acceptor :port 8000 :document-root "./web"))
(hunchentoot:start *acceptor*)

;;; Making SVG API

(hunchentoot:define-easy-handler (svg :uri "/api/svg") (name)
  (setf (hunchentoot:content-type*) "image/svg+xml")
  (let ((scene (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 100 :width 1000)))
    (svg:draw scene (:rect :x 5 :y 8 :height 50 :width 10))
    (svg:text scene (:x 40 :y 50 :font-family "serif" :font-size 50)
      name) ; <--- NAME is a GET parameter value passing by in URL.
	(with-output-to-string (string)
       (svg:stream-out string scene) string)))

;;; input form

(setf (cl-who:html-mode) :html5)
(setf cl-who:*attribute-quote-char* #\")

(defconstant +title+ "SVG-based text Echo server")

(hunchentoot:define-easy-handler (index :uri "/") ()
  (cl-who:with-html-output-to-string (s nil :prologue t :indent t)
    (:html
      (:head
        (:title (str +title+)) ; 変数を埋め込む時には str を使う. https://edicl.github.io/cl-who/#example
        (:meta :charset "UTF-8")
        (:link :rel "stylesheet" :href "web/style.css")
        (:link :rel "icon" :type "image/vnd.microsoft.icon" :href "web/favicon.ico")) ; favicon を.png にしたければ :type "image/png" とする
      (:body
        (:header
          (:h1 (str +title+))
             (:input :type "text" :maxlength "19" :placeholder "Hello Common Lisp!")
             (:input :type "submit"))
       (:div :id "svg-container")
       (:footer (:img :id "made-with-lisp" :src "web/Lisp-glossy-120.jpg" :alt "Made with Lisp."))
       (:script :src "web/glue.js")))))
