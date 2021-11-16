(ql:quickload :hunchentoot)
(ql:quickload :easy-routes)

(hunchentoot:start (make-instance 'easy-routes:routes-acceptor :port 8008))

(ql:quickload :cl-svg)

(defparameter canvas (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 300 :width 300))

(svg:draw canvas (:rect :x 5 :y 5 :height 30 :width 30))

(svg:stream-out *standard-output* canvas)
#|
<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" 
  "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg width="300" height="300" version="1.1" id="toplevel"
    xmlns="http://www.w3.org/2000/svg"
    xmlns:xlink="http://www.w3.org/1999/xlink">
  <rect x="5" y="5" height="30" width="30"/>
</svg>
|#

; (inspect 'canvas)

(with-output-to-string (string)
    (svg:stream-out string canvas)
    string)

(easy-routes:defroute home ("/shikaku") ()
    (with-output-to-string (string)
        (svg:stream-out string canvas)
        string))

http://localhost:8008/shikaku
    →よし、四角が表示された

hello world をSVG で

(defparameter canvas2 (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 800 :width 1000))

(svg:text canvas2 (:x 0 :y 0 :font-family "Verdana" :font-size 35) "hello world")

(with-output-to-string (string)
    (svg:stream-out string canvas2)
    string)
#|
"<?xml version=\"1.0\" standalone=\"no\"?>                  ; この３行を
<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\"            ; 消したいな 後記: level3.lisp を書き終わったあとで気がついたが、消さなくても大丈夫だった
  \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">     ; 
<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1000\" height=\"800\" version=\"1.1\"
    id=\"toplevel\" xmlns=\"http://www.w3.org/2000/svg\"
    xmlns:xlink=\"http://www.w3.org/1999/xlink\">
  <text x=\"0\" y=\"0\" font-family=\"Verdana\" font-size=\"35\">
    hello world
  </text>
</svg>
"
|#

(easy-routes:defroute home ("/hello") ()
    (with-output-to-string (string)
        (svg:stream-out string canvas2)
        string))

http://localhost:8008/hello
    →文字列は表示されない。

最初の<?xml><!DOCTYPE> を消してみる

(setq test (with-output-to-string (string)
    (svg:stream-out string canvas2)
    string))

(ql:quickload :cl-ppcre)
(describe :cl-ppcre) ; これでモジュールのドキュメントが読めればいいんだけど、だめだな。

https://lisphub.jp/common-lisp/cookbook/index.cgi?CL-PPCRE

(ppcre:scan "[^\\n]*\\n[^\\n]*\\n[^\\n]*\\n(.*)" test)
    0
    219
    #(140)
    #(219)
    140文字以降を切り出せばいいと分かった。

http://clhs.lisp.se/Body/m_multip.htm
(multiple-value-bind (a b start c) ; TODO a,b,c は使わない。このような時に読み捨てを指示できないかな？
  (ppcre:scan "[^\\n]*\\n[^\\n]*\\n[^\\n]*\\n(.*)" test)
  (elt start 0)) ; 140

http://clhs.lisp.se/Body/f_subseq.htm
(subseq test 140)
#| きれいに切り取れているね
"<svg width=\"1000\" height=\"800\" version=\"1.1\" id=\"toplevel\"
    xmlns=\"http://www.w3.org/2000/svg\"
    xmlns:xlink=\"http://www.w3.org/1999/xlink\">
  <text x=\"0\" y=\"0\" font-family=\"Verdana\" font-size=\"35\">
    hello world
  </text>
</svg>
"
|#

(easy-routes:defroute home ("/hello") ()
      (subseq test 140)) 

http://localhost:8008/hello
    →文字列は表示されない。

https://developer.mozilla.org/ja/docs/Web/SVG/Element/text#basic_text_usage
によると、次のように書けばいいらしく、ちょっと違いがある。
    <svg xmlns="http://www.w3.org/2000/svg"
         width="500" height="40" viewBox="0 0 500 40">
      <text x="0" y="35" font-family="Verdana" font-size="35">
        Hello, out there
      </text>
    </svg>

ためしにそれをそのまま返すようにしてみる。

(easy-routes:defroute home ("/hello") ()
    "<svg xmlns=\"http://www.w3.org/2000/svg\"
         width=\"500\" height=\"400\" viewBox=\"0 0 500 40\">
      <text x=\"0\" y=\"35\" font-family=\"Verdana\" font-size=\"35\" transform=\"rotate(30 20,40)\">
        Hello, out there
      </text>
    </svg>")

http://localhost:8008/hello
    →文字列が表示された！
        transform=rotate() を指定しているので、文字列が回転して表示されている。

→cl-svg の出力に近づけていく。
(easy-routes:defroute home ("/hello") ()
    "<svg xmlns=\"http://www.w3.org/2000/svg\"
    xmlns:xlink=\"http://www.w3.org/1999/xlink\"
version=\"1.1\"
id=\"toplevel\"
         width=\"500\" height=\"400\" viewBox=\"0 0 500 40\">
      <text x=\"0\" y=\"0\" font-family=\"Verdana\" font-size=\"35\" transform=\"rotate(30 20,40)\">
        Hello, out there
      </text>
    </svg>")
    →あれー！表示されるなぁ

もう一度
(easy-routes:defroute home ("/hello") ()
      (subseq test 140)) 

http://localhost:8008/hello
    →文字列は表示されない。

    [F12] で確認すると、単にビューポート内にテキストが入っていないだけだった。

(defparameter canvas2 (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 800 :width 1000))

(svg:text canvas2 (:x 0 :y 100 :font-family "Verdana" :font-size 50
    :transform "rotate(30 20,40)") "hello world")

(easy-routes:defroute home ("/hello") ()
  (with-output-to-string (string)
    (svg:stream-out string canvas2)
    (multiple-value-bind (a b start c)
      (ppcre:scan "[^\\n]*\\n[^\\n]*\\n[^\\n]*\\n(.*)" string)
      (subseq test (elt start 0)))))

http://localhost:8008/hello
    →文字列は表示されない。REPL にエラーとバックトレースが表示されるが、
        単に標準エラー出力にロギングしただけであり、
        SLDB が立ち上がるわけではない。
        SLDBのようにフレームを開けないのでデバッグしづらい。
        
http://edicl.github.io/hunchentoot/#debugging
Web サーバーのHunchentoot に、開発用のデバッグ用設定を行う
    (setq hunchentoot:*CATCH-ERRORS-P* nil) ; これでREPL 側でデバッガーが立ち上がる。やったね！
        →デバッガは立ち上がるものの、REPL がなく、[abort] しか選べず、かつまた同じエラーで永久ループになってしまう。

            それを無視して、例えば以下のように正しく動くコードに差し替えてブラウザを再読込するとちゃんと動くし、
            
            (easy-routes:defroute home ("/hello") ()
              "hello")
            その状態で[abort] を選べば通常のREPL に戻ってくる。

    (setq hunchentoot:*SHOW-LISP-ERRORS-P* t)   ; エラーの詳細をブラウザーにも露出する

エラーは次の通り：
    The value
      #<SB-IMPL::STRING-OUTPUT-STREAM {7FB2ED606203}>
    is not of type
      SEQUENCE
       [Condition of type TYPE-ERROR]

どうも、with-output-to-string の中ではstring はストリームであって文字列ではないようだな。
だから次のようにsvg-string に束縛する形で文字列に変換する。

(easy-routes:defroute home ("/hello") ()
  (let ((svg-string
            (with-output-to-string (string)
                (svg:stream-out string canvas2)
                string)))
    (multiple-value-bind (a b start c)
      (ppcre:scan "[^\\n]*\\n[^\\n]*\\n[^\\n]*\\n(.*)" svg-string)
      (subseq test (elt start 0)))))

まだ文字列がずれている。
毎回canvas をリセットし、描画関数を実行するのが面倒になったので、
これまでやっていることを１つの関数にまとめた。
ここで調整すればOK.

(easy-routes:defroute home ("/hello") ()
  (let ((canvas (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 800 :width 1000)))
    (svg:text canvas (:x 10 ; これが効いていない
                      :y 10 ;
                      :font-family "serif"
                      :font-size 50
                      :transform "rotate(30 20,40)"
                      ) "hello lisp")
    (let ((svg-string (with-output-to-string (string)
                        (svg:stream-out string canvas)
                        string)))
      (multiple-value-bind (a b start c)
        (ppcre:scan "[^\\n]*\\n[^\\n]*\\n[^\\n]*\\n(.*)" svg-string)
        (subseq svg-string (elt start 0))))))

これまでに定義した変数をいろいろ間違えていたので、それを直したら動くようになった。

http://localhost:8008/hello
    →OK


CSS を加えてみる

(easy-routes:defroute home ("/hello") ()
  (let ((canvas (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 800 :width 1000)))
    (svg:text canvas (:x 10 ; これが効いていない
                      :y 10 ;
                      :transform "rotate(30 20,40)"
                      :style "font-family: Times New Roman;
                             font-size: 44px;
                             stroke: #00ff00;
                             fill: #0000ff;"
                      ) "hello lisp")
    (let ((svg-string (with-output-to-string (string)
                        (svg:stream-out string canvas)
                        string)))
      (multiple-value-bind (a b start c)
        (ppcre:scan "[^\\n]*\\n[^\\n]*\\n[^\\n]*\\n(.*)" svg-string)
        (subseq svg-string (elt start 0))))))

http://localhost:8008/hello
    →OK

文字列をURL で受け取れるようにする

(easy-routes:defroute home ("/message-:x") ()
  (let ((canvas (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 800 :width 1000)))
    (svg:text canvas (:x 10 ; これが効いていない
                      :y 10 ;
                      :transform "rotate(30 20,40)"
                      :style "font-family: Times New Roman;
                             font-size: 44px;
                             stroke: #00ff00;
                             fill: #0000ff;")
      x)    ; URL で受け取った値
    (let ((svg-string (with-output-to-string (string)
                        (svg:stream-out string canvas)
                        string)))
      (multiple-value-bind (a b start c)
        (ppcre:scan "[^\\n]*\\n[^\\n]*\\n[^\\n]*\\n(.*)" svg-string)
        (subseq svg-string (elt start 0))))))

http://localhost:8008/message-hello-world
    →hello-world
http://localhost:8008/message-hello-lisp
    →hello-lisp
