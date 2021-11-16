(ql:quickload :hunchentoot)
(ql:quickload :easy-routes)

(hunchentoot:start (make-instance 'easy-routes:routes-acceptor :port 8008))

; (easy-routes:defroute home ("/") () 'hello) ; NG 'hello is not SEQUENSE


; http://localhost:8008/
(easy-routes:defroute home ("/") () "hello")

; http://localhost:8008/
; http://localhost:8008/harupiyo => hello harupiyo
(easy-routes:defroute home ("/:x") () (format nil "hello ~a" x))

(easy-routes:defroute home ("/:x") ((y 'lisp)) (format nil "hello ~a, ~a" x y))

