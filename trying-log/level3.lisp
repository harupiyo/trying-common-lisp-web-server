(ql:quickload :hunchentoot)
(ql:quickload :easy-routes)

(hunchentoot:start (make-instance 'easy-routes:routes-acceptor :port 8000))

## 1. 入力欄をHTML で出力する

HTML Generator 一覧
https://www.cliki.net/html%20generator

→とりあえずCL-WHO を使おう。使ってみないと他のライブラリーの良さもわからないだろう。
https://edicl.github.io/cl-who/#example

(ql:quickload :cl-who)

(cl-who:with-html-output (*standard-output*)
  (cl-who:htm (:input :type "text")
              (:input :type "submit"))) 
    →標準出力のストリームと、返り値の文字列の２つを扱っている
        <input type='text' /><input type='submit' />
        "<input type='text' /><input type='submit' />"
    →文字列で返すだけでいいな。
https://edicl.github.io/cl-who/#with-html-output
    (with-html-output (var &optional stream &key prologue indent))
    If stream is NIL it is assumed that var is already bound to a stream,
        引数stream がNIL なら引数var で与えられたシンボルにはすでにストリームが束縛されているものと認識し、
    if stream is not NIL var will be bound to the form stream which will be evaluated at run time.
        そうでなければ引数var のシンボルに引数stream を束縛する
    →で、文字列にするにはどうしたらいいんだ？
        with-output-to-string で文字列ストリームを作って
            http://clhs.lisp.se/Body/m_w_out_.htm
                 with-output-to-string creates a character output stream,
                 この関数は文字からなる出力用ストリームを作る
        それを指定するしかない
            (with-output-to-string (str)
              (cl-who:with-html-output (str)
                (cl-who:htm (:input :type "text")
                            (:input :type "submit")))
              str) ; このstr はなくてもいいようだ
        →OK

→XML 構文になっている
https://edicl.github.io/cl-who/#html-mode
これでhtml5 になる
(setf (cl-who:html-mode) :html5)
   <input type='text' />
    ↓
   <input type='text'>

→シングルクォートをダブルクォートに変換
(setf cl-who:*attribute-quote-char* #\")
   <input type='text'>
    ↓
   <input type="text">

(cl-who:with-html-output (nil)
  (cl-who:htm (:input :type "text")
              (:input :type "submit"))) 

; 入力画面
(easy-routes:defroute home ("/") ()
                      (with-output-to-string (str)
                        (cl-who:with-html-output (str)
                          (cl-who:htm (:input :type "text")
                                      (:input :type "submit")))))

http://localhost:8000/
    [      ][送信]
    →OK

## 3. GET メソッドで起動するAPI を書く

先にAPI を用意しておいたほうがいいだろうということで、2. の前に3. を行う

http://localhost:8000/api/svg/hello => .SVG が返ってくるようにする

LEVEL2.lisp より

(ql:quickload :cl-svg)
(ql:quickload :cl-ppcre)

(easy-routes:defroute api ("/api/svg/:message") ()
  (let ((canvas (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 800 :width 1000)))
    (svg:text canvas (:x 10 ; これが効いていない
                      :y 10 ;
                      :transform "rotate(30 20,40)"
                      :style "font-family: Times New Roman;
                             font-size: 44px;
                             stroke: #00ff00;
                             fill: #0000ff;")
     message)    ; URL で受け取った値
    (let ((svg-string (with-output-to-string (string)
                        (svg:stream-out string canvas)
                        string)))
      (multiple-value-bind (a b start c)
        (ppcre:scan "[^\\n]*\\n[^\\n]*\\n[^\\n]*\\n(.*)" svg-string)
        (subseq svg-string (elt start 0))))))

http://localhost:8000/api/svg/hello
    → SVG が返ってくる

MIME Type をimage/svg+xml にし、ファイルとして.svg が返るようにする。

https://developer.mozilla.org/ja/docs/Web/HTTP/Basics_of_HTTP/MIME_types
	mime:
		image/svg+xml

MIME タイプの変更は、easy-routes のドキュメントにあった
https://github.com/mmontone/easy-routes#examples
	こういうヘルパー関数を用意すればいいようだ。

(defun @svg (next)
  (setf (hunchentoot:content-type*) "image/svg+xml")
  (funcall next))

	そしてルートのデコレーション部分に指定する
		(defroute foo ("/foo/:arg1/:arg2" :method :get
										  :decorators (@svg)) ←
		   (&get w)
			(format nil "<h1>FOO arg1: ~a arg2: ~a ~a</h1>" arg1 arg2 w))
        
        ↓適用
(easy-routes:defroute api ("/api/svg/:message" :decorators (@svg)) ()
  (let ((canvas (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 800 :width 1000)))
    (svg:text canvas (:x 10 ; これが効いていない
                      :y 10 ;
                      :transform "rotate(30 20,40)"
                      :style "font-family: Times New Roman;
                             font-size: 44px;
                             stroke: #00ff00;
                             fill: #0000ff;")
     message)    ; URL で受け取った値
    (let ((svg-string (with-output-to-string (string)
                        (svg:stream-out string canvas)
                        string)))
      (multiple-value-bind (a b start c)
        (ppcre:scan "[^\\n]*\\n[^\\n]*\\n[^\\n]*\\n(.*)" svg-string)
        (subseq svg-string (elt start 0))))))
    
http://localhost:8000/api/svg/hello
    → .svg ファイルが返ってくる. (ダウンロードの画面になる)

## 2. 送信時のajax 通信を行うJavaScript を書く

https://qiita.com/piyopiyo/items/56516ab4ab6d5797b78d
    Ajax のレスポンスはJSON が基本とある。
    ファイルではなく、JSON で返すべきだったかな？

data: スキームの形で返してもいいな。
https://ja.wikipedia.org/wiki/Data_URI_scheme

ひとまずこの問題はおいておく。

### 2-1. 普通のJavaScript コーディングを行う

ブラウザのconsole から書いてテストする

https://developer.mozilla.org/ja/docs/Web/API/XMLHttpRequest
    1. XMLHttpRequest リクエストとレスポンス
    2. サーバーからのイベントを受け取る時にはServer-sent event のEventSource を使う (push 通信のことかな)
    2. 全二重通信にはWebSocket を使う

https://developer.mozilla.org/ja/docs/Web/API/XMLHttpRequest/Using_XMLHttpRequest
https://developer.mozilla.org/ja/docs/Web/API/XMLHttpRequest/responseText

let request = new XMLHttpRequest()
request.addEventListener ("load",
   function (response){ 
    if (request.readyState === request.DONE) {
        if (request.status === 200) {
            console.log(request.responseText); // SVG が返ってきている
        }
    }
   });
request.open("GET","http://localhost:8000/api/svg/hello");
request.send ();

img タグとして貼る
https://developer.mozilla.org/ja/docs/Web/API/Document/createElement
var img = document.createElement ('img');
img.src = request.responseText;
var body = document.getElementsByTagName('body')[0];
body.appendChild (img);
    →画像はこわれているが、こういう流れで良さそうだ。

AJAX通信で受け取った画像をBASE64 でdata: スキームで表現する
https://qiita.com/yasumodev/items/e1708f01ff87692185cd
    注意点として、<img>要素 → Base64 の時は、Ajax同様に JavaScript のクロスドメイン制限があります。つまり、外部サーバーにある画像をBase64形式に変換することはできません。
    →ほんまかいな
    
BASE64 エンコードする
https://qiita.com/i15fujimura1s/items/6fa5d16b1e53f04f3b06
    btoa (src)

btoa (request.responseText);
    "PHN2ZyB3aWR0aD0iMTAwMCIgaGVpZ2h0PSI4MDAiIHZlcnNpb249IjEuMSIgaWQ9InRvcGxldmVsIgogICAgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIgogICAgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiPgogIDx0ZXh0IHg9IjEwIiB5PSIxMCIgdHJhbnNmb3JtPSJyb3RhdGUoMzAgMjAsNDApIgogICAgICAgc3R5bGU9ImZvbnQtZmFtaWx5OiBUaW1lcyBOZXcgUm9tYW47CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZm9udC1zaXplOiA0NHB4OwogICAgICAgICAgICAgICAgICAgICAgICAgICAgIHN0cm9rZTogIzAwZmYwMDsKICAgICAgICAgICAgICAgICAgICAgICAgICAgICBmaWxsOiAjMDAwMGZmOyI+CiAgICBoZWxsbwogIDwvdGV4dD4KPC9zdmc+Cg=="
    
data: スキームにする
https://gray-code.com/javascript/display-image-in-base64-format/
    data:image/svg+xml;base64,----data----"
    という形式にすればよい
    
data_scheme_img = "data:image/svg+xml;base64," + btoa (request.responseText);

img.src=data_scheme_img;
    →画像が表示できたー！
    
ここまでのコードのまとめ:

function say (message){
    let request = new XMLHttpRequest()

    function response_handler (){
        if (request.readyState === request.DONE) {
            if (request.status === 200) {
                let img = document.createElement ('img');
                var body = document.getElementsByTagName('body')[0];
                img.src = "data:image/svg+xml;base64," + btoa (request.response); 
                body.appendChild (img);
            }
        }
    }

    request.addEventListener ("load", response_handler);
    request.open("GET","http://localhost:8000/api/svg/" + message);
    request.send ();
}

say('lisp');

### 2-2. say() をsubmit と関連付ける

let submit = document.querySelector('[type=submit]');
let text = document.querySelector('[type=text]');
text
    <input type="text">
text.value
    "test"

submit.addEventListener('click', function(){
    let text = document.querySelector('[type=text]');
    say (text.value);
    return false; // for not submit
});

よし。

まとめ：
    let submit = document.querySelector('[type=submit]');
    submit.addEventListener('click', function(){
        let text = document.querySelector('[type=text]');
        say (text.value);
        return false; // for not submit
    });

### 2-3. ここまでの仕組みを、サーバー側に持たせる

#### 2-3-1. 静的.js をサポートする

http://edicl.github.io/hunchentoot/#teen-age
    デフォルトでは、Hunchentootはからのファイルを提供します www/ソースツリー内のディレクトリ。

静的ファイルの提供もできるが、今回はCommon Lisp でJavaScript 開発するのが主眼だから、これは於いておく。

#### 2-3-2. Common Lisp からのJavaScript コーディング

Common Lisp からJavaScript のコーディングをする時には、JavaScript 側で何をするかを予め知って置かなければならない。
そのターゲットを目当てに、二人羽織のようにおそるおそるCommon Lisp をコーディングするのは頼りない。

このパラダイムは、マクロを書く時と同じメタプログラミングだ。

だからこの段階の前に、

### 2-1. 普通のJavaScript コーディングを行う
を解決しておくことには意味がある。

さて、CommonLisp -> JavaScript の手段には２つあることがわかっている。

- Parenscript
- JSCL
- またはParenscript で実装されているWeb サーバー Weblocks
    http://lispcookbook.github.io/cl-cookbook/web.html#weblocks---solving-the-javascript-problem

どちらがよいかだが、Weblocks というプロダクトの実績のあるParenscript を味わうことにしたい。
weblocks そのものが一番ラクだと思うが、現時点では 

	2021\10\2021-10-06-180148.txt|4| = [lisp] static-vectors モジュールがインストールできない

の問題が発生して (Ubuntu20.04 on WSL2 では)使えないのでParenscript を直に使うことにする。
    -> 後記：↑の問題は解決した
        [TODO] Weblocks を試してみる

#### 2-3-2-1. Parenscript でのJavaScript コーディング

(ql:quickload :parenscript)
(ql:quickload :cl-fad)

https://common-lisp.net/project/parenscript/
https://common-lisp.net/project/parenscript/tutorial.html
https://common-lisp.net/project/parenscript/reference.html
http://www.adamtornhill.com/articles/lispweb.htm

(defpackage test
  (:shadow hunchentoot:redirect) ; easy-routes:redirect とかぶるため, そちらを優先する
  (:use :cl :parenscript :cl-fad :cl-who :hunchentoot :easy-routes))

(in-package :test)

; MEMO in-package したことにより、SLIME のコード補完がライブラリにまで拡張した！

(defroute html-with-js ("/html-with-js") ()
  (with-html-output-to-string (s) ; ので、この関数があることに気づいた
    (:html
      (:head (:title "Parenscript test"))
      (:body (:h2 "Parenscript test")
       "Please click the link"
       (:a :href "#" :onclick (ps (alert "Parenscript!"))
        "hello ...")))))

http://localhost:8000/html-with-js
    →うごいたー

こういう感じにしたい
(defroute html-with-js ("/html-with-js") ()
  (with-html-output-to-string (s)
    (:html
      (:head (:title "Parenscript test")
       (:script
         (str   ; script の中を書く時にはstr の中に行う
           (ps
            #|
            let submit = document.querySelector('[type=submit]');
            submit.addEventListener('click', function(){
                let text = document.querySelector('[type=text]');
                say (text.value);
                return false; // for not submit
            });

            function say (message){
                let request = new XMLHttpRequest()

                function response_handler (){
                    if (request.readyState === request.DONE) {
                        if (request.status === 200) {
                            let img = document.createElement ('img');
                            var body = document.getElementsByTagName('body')[0];
                            img.src = "data:image/svg+xml;base64," + btoa (request.response); 
                            body.appendChild (img);
                        }
                    }
                }

                request.addEventListener ("load", response_handler);
                request.open("GET","http://localhost:8000/api/svg/" + message);
                request.send ();
            }
            |# ))))
      (:body (:h2 "Parenscript test")
       "Please click the link"
       (:a :href "#" :onclick (ps (alert "Parenscript!"))
        "hello ...")))))

実際にParenscript で記述してみる (少しづつ)

    #|
    let submit = document.querySelector('[type=submit]');
    submit.addEventListener('click', function(){
        let text = document.querySelector('[type=text]');
        say (text.value);
        return false; // for not submit
    });
    |#


そうだ、ページ全部を記述する必要はなくて、ps 関数でどんなjs が吐き出されるかを十分観察できるぞ。

    ここで一旦環境が落ちた。
    毎回REPL に対話的にhuncentoot サーバーを起動したり、必要なライブラリーを読み込んだりが
    めんどうになったので、
        package.lisp
    にそのへんのバッチを書いた。
    なので、この２行で済む。
        (load "package.lisp")
        (in-package :test) ; これ、減らせないかな。
    あるいは.asd でやったほうがいいのかも。

(ps (let ((submit "hello"))
      (alert submit)))

"(function () {
    var submit = 'hello'; // ここ、let じゃないんだ. まあいいか。
    __PS_MV_REG = [];
    return alert(submit);
})();"


(ps (let ((submit
            ;; document.querySelector("[type=submit]");
            (chain document (query-selector "[type=submit]"))))))

(ps (let ((submit
            (chain document (query-selector "[type=submit]"))))
      ;; submit.addEventListener('click',function(){ say("hello"); });
      (chain submit (add-evelnt-listener "click"
                                         (lambda () (say "hello"))))))

(ps (let ((submit
            (chain document (query-selector "[type=submit]"))))
      (chain submit
             (add-evelnt-listener
               "click"
               ;; var text = document(querySelector('[type=text]'));
               ;; return say(text.value);
               (lambda ()
                 (let ((text (chain (document (query-selector "[type=text]")))))
                   (say (chain text value))))))))

ここまで書いてみて。
文法はlisp だが、JavaScript コーディングをもろにやっている。
たまにlet やlambda を置き換えてくれる。

JavaScriptでのコーディングを知らないと結局書けないな。

いやいや、まてよ。
    document.querySelector ("");
    は、JavaScriptではなく、DOM のAPI ではないか。
    
    さすがにAPI は知らないと書けないぞ。だからいいのか。
    (chain document (query-selector ""))
    と書くのもどうかと思ったけど、
    (send 'document 'query-slector "")
    という文法だったらリスト操作がしにくかったりするのかな？
    あ、 (@ document query-selector "") というマクロがあるんだ。

    (ps (@ document query-selector ""))
    ; document.querySelector['']; 最後が ("") じゃない
    ; そうか、最後は関数呼び出しだからこうじゃないとだめか？
    (ps (@ document (query-selector "")))
    ; "document[querySelector('')];"    あらら！？
     
    
    よく読んだら

        Note the @ and chain property access convenience macros.
        (@ object slotA slotB) expands to (getprop (getprop object 'slotA) 'slotB). chain is similar and also provides nested method calls. 

    @ はプロパティへアクセスするマクロで、
    chain はネストしたメソッド呼び出しのマクロだから、
    全然別物だ

先に進める。

(ps (new (xml-http-request "")))
; new xmlHttpRequest('');"

(ps
  (defun say (message)
    (let ((request (new (xml-http-requests ""))))
      (defun response-handler ()
        ;; eq が === に相当する
        (if (eq (@ request ready-state)
                ;; DONE は大文字にしたい！
                (@ request DONE)
                (@ request 'DONE)
                (@ request '|DONE|)
                (@ request "DONE"))
                ;; どれも大文字にならない
            (say "hello")     
                ;; ただし、このeq 式の展開は意図通りになっている！
                ;; var _cmp1;
                ;; var _cmp2;
                ;; var _cmp3;
                ;; var _cmp4;
                ;; var _cmp5;
                ;; var _cmp6;
                ;; __PS_MV_REG = [];
                ;; return (
                ;;   _cmp4 = request.done,
                ;;   _cmp5 = request.done,
                ;;   _cmp6 = request.done,
                ;;   request.readyState === _cmp4 &&
                ;;   _cmp4 === _cmp5 &&
                ;;   _cmp5 === _cmp6 &&
                ;;   _cmp6 === request['DONE']) ? say('hello') : null;
                )))))

https://common-lisp.net/project/parenscript/reference.html
ps:*js-target-version* => 1.3
    古いバージョンのJavaScript しか知らないのかな？
    まあ、差支えはないと思う。 (ECMAScript 2021 を読んでおこう)
    async
        https://developer.mozilla.org/ja/docs/Web/JavaScript/Reference/Statements/async_function
    なども、そう表現できればいいので。 
    (文法を変換する仕組みさえあればParenscript が知っている必要はない)
        しかし、できるのかな？
        👎予約語には例えばNEW は入っているが、async は入っていないのでだめだろう。
        https://common-lisp.net/project/parenscript/reference.html#reserved-symbols


        MEMO Parenscript にES6 を導入するParen6 があった。Parenscript の代わりにこっちを使えばいい。
        https://github.com/BnMcGn/paren6/
            ES5 とES6 (2015) の違い
            https://codeaid.jp/js-es2015/
                →ただ、ES2021 のようなモダンなものはまだないようだ
        

https://common-lisp.net/project/parenscript/reference.html#section-symbolconv
(ps *done*)
    ; これで大文字にできる
    ; "DONE;"

(ps
  (defun say (message)
    (let ((request (new (xml-http-requests ""))))
      (defun response-handler ()
        ;; eq が === に相当する
        (when (eq (@ request ready-state)
                (@ request *DONE*))
            (when (eq (@ request status) 200))
            'hello
                )))))

(ps (@ (chain document (get-elements-by-tag-name 'body)) 0))
; "document.getElementsByTagName('body')[0];"
; あ、できてる。よくわかったな、おれ。

(ps
  (defun say (message)
    (let ((request (new (xml-http-requests ""))))
      (defun response-handler ()
        ;; eq が === に相当する
        (when (eq (@ request ready-state)
                (@ request *DONE*))
            (when (eq (@ request status) 200)
                (let ((img (chain document (create-element 'img)))
                      (body (@ (chain document (get-elements-by-tag-name 'body)) 0)))
                  (setf (@ img src)
                        (concatenate 'string "data:image/svg+xml;base64,"
                                                  (btoa (@ request response)))) 
                  (chain body (append-child img))
                  ))))
      (chain request (add-event-listener 'load response-handler))
      (chain request (open "get"
                           (concatenate 'string
                                        "http://localhost:8000/api/svg/"
                                        message)))
      (chain request (send)))))
    
JavaScript? コーディングが完了したからページ記述に組み込む。

その前に、XMLHttpRequest が書けていないことに気づいた。
    (ps xml-http-request)
    ; "xmlHttpRequest;"
    (ps *xml*-http-request)
    ; "XMLHTTPREQUEST;" おっと！
    (ps "XMLHttpRequest")
    ; 'XMLHttpRequest';"    ...。

[TODO] ↑の問題を片付けたい

= [2021-10-08] LEVEL3 Day2 - 調査
[2021-10-08 22:29]

https://blog.jeaye.com/2015/09/27/parenscript-ajax/
	:smackjack というのを使うといいようだ。
https://github.com/helmutkian/cl-react
	Parenscript のユーティリティでReact を使うものがある。
	しかし、古すぎる。
Common Lisp でReact を使えるかという話題
https://www.reddit.com/r/lisp/comments/de5ug0/using_react_with_parenscript/
https://stackoverflow.com/questions/61027537/common-lisp-how-to-do-a-highly-interactive-single-page-web-app
https://morioh.com/p/ae477b8016e7
https://stackshare.io/stackups/common-lisp-vs-react-native
https://michaeljforster.tumblr.com/post/135442858967/dont-panic-generate-react-components-with-common
WebSocket なISSR ライブラリーはスジが良いと思った
https://github.com/interactive-ssr/client/blob/master/main.org/
	https://github.com/interactive-ssr/client
Web にGUI をCommon Lisp で書く
https://github.com/rabbibotton/clog
フロントエンドはClojureScript で書くという方向
https://news.ycombinator.com/item?id=16592459
https://qiita.com/fireflower0/items/26de28562cb00e5df63c
	フロントエンドはJS のReact コーディング
React を学ぶ前に知っておきたかったこと
https://hirokikaneko.medium.com/%E7%A7%81%E3%81%8Creact%E3%82%92%E5%A7%8B%E3%82%81%E3%82%8B%E5%89%8D%E3%81%AB%E7%9F%A5%E3%81%A3%E3%81%A6%E3%81%8A%E3%81%91%E3%81%B0%E8%89%AF%E3%81%8B%E3%81%A3%E3%81%9F%E4%BA%8B-2cba80d32423
Web フレームワークUtopian
https://github.com/fukamachi/utopian/tree/next
	それを使った例
	https://qiita.com/fireflower0/items/b04d1f91f2e0ca636db1
	https://qiita.com/fireflower0/items/1a36e14e7a0d45464c10

ライブラリー一覧
https://lisp-journey.gitlab.io/blog/state-of-the-common-lisp-ecosystem-2020/#web-development
https://github.com/CodyReichert/awesome-cl#clack-plugins
https://asmen.icopy.site/awesome/awesome-cl/

チュートリアル
http://lispcookbook.github.io/cl-cookbook/web.html#weblocks---solving-the-javascript-problem
http://www.adamtornhill.com/articles/lispweb.htm

= [2021-11-01] LEVEL3 Day3
[2021-11-01 18:04]

今抱えている問題を整理:

1. Parenscript でXMLHttpRequest が書けない
	- 大文字小文字の任意の組み合わせを表現出来ない
		- Parenscript でそれをやる方法はあるか？
			- Parenscript をHack する?
			- https://eshamster.hatenablog.com/entry/2015/11/08/132128
                (ps (@ -x-m-l-http-request)) と書けばいいらしい。そうか！ 
                    CL-USER> (ps (@ -x-m-l-http-request))
                    "XMLHttpRequest;"   いいね

		Day2 で調べたことを元にすると、
			- Parenscript でXMLHttpRequest を使うには SmackJack と組み合わせる
			- Parenscript 以外
				- JSCL
				- Weblocks
		たまたま昨日勉強して分かったこと
			- Fetch API を使えば良いんじゃない？
				2021\11\2021-11-01-205651.txt|1| = [javascript][WebAPI] Fetch - XMLHttpRequest の代わりに使えるより便利なAPI
	- そもそも Ajax 通信部分までLisp で書かなくて良いんじゃないかな？
		- 糊の部分はJavaScript で書くのがスマート (だし、"スクリプト言語" らしい使い方だ)
	→ つまり、逃げ方は複数ある！

2. サーバー側でJS コードを生成したとして、ブラウザ側で実行できるのか？
	- eval への不安
	- ブラウザ側のセキュリティモデルを知る
		↓調査をしました
	2021\11\2021-11-01-180535.txt|2| = [lisp][JavaScript] JavaScript で、XMLHttpRequest でサーバーから取得したJavaScript コードを実行する方法
		→ eval の代わりに new Function() を使え
			基本グローバル環境が見え、
			環境を指定してローカルオブジェクトを見せることもできる
		→ サーバー側で CSP で規制しない限り、 new Function() は使える
		→ つまり、ほぼ問題無い！

問題は払拭できた


まずこの記事にあったSmackJack ライブラリーを試してみた.

https://blog.jeaye.com/2015/09/27/parenscript-ajax/

```
(ql:quickload '(:hunchentoot :cl-who :parenscript :smackjack))
(defpackage :jank-repl
  (:use :cl :hunchentoot :cl-who :parenscript :smackjack))
(in-package :jank-repl)

(setf *js-string-delimiter* #\")
(defparameter *ajax-processor*
  (make-instance 'ajax-processor :server-uri "/repl-api"))
(defun-ajax echo (data) (*ajax-processor* :callback-data :response-text)
  (concatenate 'string "echo: " data))
(define-easy-handler (repl :uri "/repl") ()
  (with-html-output-to-string (s)
    (:html
      (:head
        (:title "Jank REPL")
        (str (generate-prologue *ajax-processor*))                                      ;; ajax 通信のためのJavaScript が展開される
                                                                                        ;; その中身はIE10時代の古式ゆかしいもの
                                                                                        ;; ajax 通信に必要な相手先uri なども
                                                                                        ;; *ajax-processor* から取得してここに書かれる 
        (:script :type "text/javascript"
          (str
            (ps
              (defun on-click ()                                                        ;; ajax 通信の本体は↑に押し込まれているので
                (chain smackjack                                                        ;; ここで書かれるスクリプトは小さなもので済んでいる
                       (echo (chain document (get-element-by-id "data") value)
                                       callback)))
              (defun callback (response) (alert response))))))
      (:body
        (:p (:input :id "data" :type "text"))                                           ;; 1. ここに入力された文字が
        (:p (:button :type "button" :onclick (ps-inline (on-click)) "Submit!"))))))     ;; 2. ajax 通信後、alert でポップアップされる
(defparameter *server*
  (start (make-instance 'easy-acceptor :address "localhost" :port 8080)))
(setq *dispatch-table* (list 'dispatch-easy-handlers
                             (create-ajax-dispatcher *ajax-processor*)))
```
http://localhost:8080/repl
で動作確認ができる。

わたしは、これを使う代わりに、必要な通信を行う糊となるJavaScript を書くことにした。

以前書いたajax 通信のコードは、この通り。
```
	function say (message){
		let request = new XMLHttpRequest()

		function response_handler (){
			if (request.readyState === request.DONE) {
				if (request.status === 200) {
					let img = document.createElement ('img');
					var body = document.getElementsByTagName('body')[0];
					img.src = "data:image/svg+xml;base64," + btoa (request.response); 
					body.appendChild (img);
				}
			}
		}

		request.addEventListener ("load", response_handler);
		request.open("GET","http://localhost:8000/api/svg/" + message);
		request.send ();
	}
```

このままでも良いのだが、XMLHttpRequest のモダンな代替である Fetch API を使って書き直す。
https://developer.mozilla.org/ja/docs/Web/API/Fetch_API/Using_Fetch

https://developer.mozilla.org/ja/docs/Web/JavaScript/Reference/Global_Objects/encodeURI
	encodeURI('日本語') => "%E6%97%A5%E6%9C%AC%E8%AA%9E"

基本形

	fetch( 'http://localhost:8000/api/svg/hello' )
		.then( response => console.log(response) )

メッセージを仕込む

	fetch( 'http://localhost:8000/api/svg/' + encodeURI('日本語') )
		.then( response => console.log(response) )

レスポンスから画像を取り出す

	1. Blob とするか

	https://developer.mozilla.org/ja/docs/Web/API/Blob

	fetch( 'http://localhost:8000/api/svg/' + encodeURI('日本語') )
		.then( response => response.blob() ) 
		.then( svg => console.log(svg) )
	=> Blob { size: 419, type: "image/svg+xml" }

	2. Text とするか

	fetch( 'http://localhost:8000/api/svg/' + encodeURI('日本語') )
		.then( response => response.text() ) 
		.then( svg => console.log(svg) )
	=>
		<svg width="1000" height="800" version="1.1" id="toplevel" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
		  <text x="10" y="10" transform="rotate(30 20,40)" style="font-family: Times New Roman; font-size: 44px; stroke: #00ff00; fill: #0000ff;">
			æ�¥æ�¬èª�     <--- ここでは化けているが、↓以降では問題ない
		  </text>
		</svg>

画像をBASE64 エンコーディング (btoa)

	fetch( 'http://localhost:8000/api/svg/' + encodeURI('日本語') )
		.then( response => response.text() ) 
		.then( svg => console.log("data:image/svg+xml;base64," + btoa(svg) ))
	=> data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwMCIgaGVpZ2h0PSI4MDAiIHZlcnNpb249IjEuMSIgaWQ9InRvcGxldmVsIgogICAgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIgogICAgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiPgogIDx0ZXh0IHg9IjEwIiB5PSIxMCIgdHJhbnNmb3JtPSJyb3RhdGUoMzAgMjAsNDApIgogICAgICAgc3R5bGU9ImZvbnQtZmFtaWx5OiBUaW1lcyBOZXcgUm9tYW47CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZm9udC1zaXplOiA0NHB4OwogICAgICAgICAgICAgICAgICAgICAgICAgICAgIHN0cm9rZTogIzAwZmYwMDsKICAgICAgICAgICAgICAgICAgICAgICAgICAgICBmaWxsOiAjMDAwMGZmOyI+CiAgICDml6XmnKzoqp4KICA8L3RleHQ+Cjwvc3ZnPgo=

	あとはこれを img src にセットすればいい

img 要素を作り、body に追加する部品を作る

	let img = document.createElement ('img')
	let body = document.getElementsByTagName('body')[0]
	img.src = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwMCIgaGVpZ2h0PSI4MDAiIHZlcnNpb249IjEuMSIgaWQ9InRvcGxldmVsIgogICAgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIgogICAgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiPgogIDx0ZXh0IHg9IjEwIiB5PSIxMCIgdHJhbnNmb3JtPSJyb3RhdGUoMzAgMjAsNDApIgogICAgICAgc3R5bGU9ImZvbnQtZmFtaWx5OiBUaW1lcyBOZXcgUm9tYW47CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZm9udC1zaXplOiA0NHB4OwogICAgICAgICAgICAgICAgICAgICAgICAgICAgIHN0cm9rZTogIzAwZmYwMDsKICAgICAgICAgICAgICAgICAgICAgICAgICAgICBmaWxsOiAjMDAwMGZmOyI+CiAgICDml6XmnKzoqp4KICA8L3RleHQ+Cjwvc3ZnPgo="
	body.appendChild (img)
	
	-> 「日本語」のSVG が追加された

Fetch API -> img -> body 追加の流れ一式をアッセンブルする

	fetch( 'http://localhost:8000/api/svg/' + encodeURI('日本語') )
		.then( response => response.text() ) 
		.then( svg => {
			let img = document.createElement ('img')
			let body = document.getElementsByTagName('body')[0]
			img.src = "data:image/svg+xml;base64," + btoa(svg)
			body.appendChild(img)
		})

エラー処理を入れる

	fetch( 'http://localhost:8000/api/svg/' + encodeURI('日本語'), { mode: 'same-origin' } )
		.then( response => {
			if (!response.ok) throw new Error('Fetch API: Network response was not ok')
			if ( response.headers.get('content-type') !== 'image/svg+xml' ) throw new Error('Fetch API: Allow SVG only')
			return response.text()
		}) 
		.then( svg => {
			let img = document.createElement ('img')
			let body = document.getElementsByTagName('body')[0]
			img.src = "data:image/svg+xml;base64," + btoa(svg)
			body.appendChild(img)
			return false;
		})

関数にする

	function say(message){
		const options = { mode: 'same-origin', headers: { 'Content-Type': 'image/svg+xml' } }
		fetch( 'http://localhost:8000/api/svg/' + encodeURI(message), options )
			.then( response => {
				if (!response.ok) throw new Error('Fetch API: Network response was not ok')
				if ( response.headers.get('content-type') !== 'image/svg+xml' ) throw new Error('Fetch API: Allow SVG only')
				return response.text()
			}) 
			.then( svg => {
				let img = document.createElement ('img')
				let body = document.getElementsByTagName('body')[0]
				img.src = "data:image/svg+xml;base64," + btoa(svg)
				body.appendChild(img)
			})
	}

	say('lisp') => OK

TODO mode: 'same-origin' のCORS やCSP の周りを整理

MEMO async/await を使うかな？
https://developer.mozilla.org/ja/docs/Web/JavaScript/Reference/Statements/async_function
	async および await キーワードを使用することで、プロミスベースの非同期の動作を、プロミスチェーンを明示的に構成する必要なく、よりすっきりとした方法で書くことができます。

	-> 今回はPromise を陽につかう形で問題ない
			Promise
			https://developer.mozilla.org/ja/docs/Web/JavaScript/Guide/Using_promises
		なお書き直すとしたら次の様な骨格となる。

		async function say(message) {
		  const response = await fetch(url)
		  return response.test()
		}
		say('hello').then(svg => console.log(svg) });

画面上のUI と連携させる

	const submit = document.querySelector('[type=submit]');
	submit.addEventListener('click', function(){
		const text = document.querySelector('[type=text]');
		say(text.value);
		return false; // for not to submit
	});

これでJavaScript コーディングは完了。まとめ:

	glue.js:
		const submit = document.querySelector('[type=submit]');
		submit.addEventListener('click', function(){
			const text = document.querySelector('[type=text]');
			say(text.value);
			return false; // for not to submit
		});

		function say(message){
			const options = { mode: 'same-origin', headers: { 'Content-Type': 'image/svg+xml' } }
			fetch( 'http://localhost:8000/api/svg/' + encodeURI(message), options )
				.then( response => {
					if (!response.ok) throw new Error('Fetch API: Network response was not ok')
					if ( response.headers.get('content-type') !== 'image/svg+xml' ) throw new Error('Fetch API: Allow SVG only')
					return response.text()
				}) 
				.then( svg => {
					let img = document.createElement ('img')
					let body = document.getElementsByTagName('body')[0]
					img.src = "data:image/svg+xml;base64," + btoa(svg)
					body.appendChild(img)
				})
		}


= [2021-11-03] LEVEL3 Day4
[2021-11-02 22:31]

この glue.js をアセット配信(静的コンテンツ配信)する。

	Hunchentoot ではどうすればいいかな？
	https://edicl.github.io/hunchentoot/#teen-age
		デフォルトでは、Hunchentootは
			   www/ソースツリー内のディレクトリ
		からのファイルを提供します

	www/glue.js とすれば、
	http://localhost:8000/glue.js

https://lisp-journey.gitlab.io/blog/web-development-in-common-lisp/#serve-local-files	
~/quicklisp/dists/quicklisp/software/hunchentoot-v1.2.38/

こんなところにあったよ
	cd ~/.roswell
	fzf で hunchentoot www で検索
	~/.roswell/lisp/quicklisp/dists/quicklisp/software/hunchentoot-v1.3.0/www/
	cd ~/common-lisp/webapp-sample1/
	ln -s ~/.roswell/lisp/quicklisp/dists/quicklisp/software/hunchentoot-v1.3.0/www/
	mkdir www/js
	cp glue.js www/js/

	http://localhost:8000/js/glue.js
		→だめだね～

static content の配信は folder dispatcher
https://t-cool.hateblo.jp/entry/2018/08/14/110039
	/slideshow-images/{スライドショーの名前}/{画像のファイル名}
	にある画像をサーブするために、Hunchentootのfolder dispatcher関数を使います

https://edicl.github.io/hunchentoot/#create-folder-dispatcher-and-handler
(ql:quickload '(:hunchentoot :easy-routes :cl-who :cl-svg :cl-ppcre :parenscript :cl-fad :drakma))
(defparameter *accepter* (make-instance 'easy-routes:routes-acceptor :port 8000)) <--- こうしておけば
(hunchentoot:start *accepter*)
(hunchentoot:stop *accepter*)                       <--- これや
(hunchentoot:acceptor-document-root *accepter*)     <--- これができる
==> #P"/home/harupiyo/.roswell/lisp/quicklisp/dists/ultralisp/software/edicl-hunchentoot-20210930224628/www/"
    これが静的コンテンツ置き場
https://edicl.github.io/hunchentoot/#acceptor-document-root
    setf できるとのこと
    (make-pathname :directory "./www/")
(setf (hunchentoot:acceptor-document-root *accepter*) (make-pathname :directory "./www/"))     <--- これができる
(hunchentoot:acceptor-document-root *accepter*)     <--- これができる
==> #P"/./www//"

mkdir www
vi www/glue.js

http://localhost:8000/glue.js
    -> 見えないなー

(hunchentoot:ACCEPTOR-ERROR-TEMPLATE-DIRECTORY *accepter*)
#P"/home/harupiyo/.roswell/lisp/quicklisp/dists/ultralisp/software/edicl-hunchentoot-20210930224628/www/errors/"
    -> ちなみにこのフォルダは存在しない

MEMO
Lisp のWeb クライアントを使って確認もできるな
    (ql:quickload :drakma)
    (drakma:http-request "http://localhost:8000/glue.js") => 404 Not Found

(hunchentoot:create-static-file-dispatcher-and-handler "/www/" (make-pathname :directory "./www/"))
    (drakma:http-request "http://localhost:8000/glue.js") => 404 Not Found
    (drakma:http-request "http://localhost:8000/www/glue.js") => 404 Not Found

https://stackoverflow.com/questions/8285115/how-to-tell-hunchentoot-where-to-find-static-web-pages-to-serve

(hunchentoot:stop *accepter*)
(setf *accepter* (make-instance 'easy-routes:routes-acceptor :port 8000 :document-root #p"./www/"))
(hunchentoot:start *accepter*)
    (drakma:http-request "http://localhost:8000/www/glue.js") => 404 Not Found

(push (hunchentoot:create-static-file-dispatcher-and-handler "/glue.js" "./www/glue.js")
      hunchentoot:*dispatch-table*)  
    (drakma:http-request "http://localhost:8000/glue.js") => 404 Not Found
    
うーん

https://comp.lang.lisp.narkive.com/61j5HjS3/please-post-recipie-for-hunchtoot-to-serve-static-files-from-a-folder

(push (hunchentoot:create-folder-dispatcher-and-handler "/www/" #p"./www/")
    hunchentoot:*dispatch-table*)
    
    (drakma:http-request "http://localhost:8000/www/glue.js") => 404 Not Found

うーん

https://github.com/mmontone/gestalt/blob/master/src/lwt.lisp
(hunchentoot:create-static-file-dispatcher-and-handler "/glue.js"
					    (make-pathname :name "glue" :type "js"))
    (drakma:http-request "http://localhost:8000/glue.js") => 404 Not Found

基礎がためが必要
2021\11\2021-11-10-161935.txt|1| = [lisp][web] Hunchentoot で静的コンテンツ配信の方法を調べる
    -> ここで調べました

= [2021-11-16] LEVEL3 Day5
[2021-11-16 12:58]

2021\11\2021-11-10-161935.txt|1| = [lisp][web] Hunchentoot で静的コンテンツ配信の方法を調べる
    で実施した実験により、easy-route は使わない方向で進めます。

(ql:quickload '(:hunchentoot :cl-svg :cl-who :parenscript))
(defpackage test
  (:shadow cl-svg:stop) ; hunchentoot:stop とかぶるため
  (:use :cl :parenscript :cl-who :cl-svg :hunchentoot))
(in-package :test)

1. glue.js を静的配信
mkdir web
cp glue.js web/
(defparameter accepter (make-instance 'hunchentoot:easy-acceptor :port 8000 :document-root "./web"))
(hunchentoot:start accepter)
(hunchentoot:stop accepter)
http://localhost:8000/web/glue.js
    -> OK
        MIME 型はどうか？
            Content-Type text/javascript; charset=utf-8
                -> 正しく出力されている

2. SVG を出力するAPI の実装

(hunchentoot:define-easy-handler (svg :uri "/api/svg") (name)
  (setf (hunchentoot:content-type*) "image/svg+xml")
  (let ((canvas (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 100 :width 1200)))
    (svg:text canvas (:x 10 :y 50 :font-family "serif" :font-size 50)
      name) ; URL parts
    (let ((svg-string (with-output-to-string (string)
                        (svg:stream-out string canvas) string)))
      svg-string)))

http://localhost:8000/api/svg?name=hello
    -> OK
http://localhost:8000/api/svg?name=%E6%97%A5%E6%9C%AC%E8%AA%9E
    -> OK "日本語"

3. 入力画面を表示

Made with Lisp のロゴを用意

$ wget https://upload.wikimedia.org/wikipedia/commons/9/99/Lisp-glossy-120.jpg --output-file=web/Lisp-glossy-120.jpg

favicon.ico を用意
    .ico ファイルを
    https://icon-icons.com/ja/%E3%82%A2%E3%82%A4%E3%82%B3%E3%83%B3/%E5%85%B1%E9%80%9A-Lisp/132483
    からダウンロードし、web/favicon.ico に置いておく

(hunchentoot:define-easy-handler (index :uri "/") ()
  (with-html-output-to-string (s)
    (:html
      (:head
        (:title "SVG TEXT GENERATOR")
        (:meta :charset "UTF-8")
        (:link :rel "icon" :type "image/vnd.microsoft.icon" :href "web/favicon.ico")) ; favicon を.png にしたければ :type "image/png" とする
      (:body (:h1 "SVG TEXT GENERATOR")
       (:form
         (:input :type "text")
         (:input :type "submit"))
       (:img :src "web/Lisp-glossy-120.jpg" :alt "Made with Lisp.")
       (:script :src "web/glue.js")))))

http://localhost:8000/

### 日本語を含むSVG が表示されない

https://www.softel.co.jp/blogs/tech/archives/4133

    img.src = "data:image/svg+xml;base64," + btoa(svg)
        ↓
    img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svg)))

    -> OK

### 見た目の調整
- web/glue.js
    画像を挿入したあとにbr で改行を入れるようにした
        let br = document.createElement ('br')
        body.appendChild(br)
- html の調整
  - Made with Lisp のロゴをfooter にし、footer は画面下に固定
    - style.css の追加
(hunchentoot:define-easy-handler (index :uri "/") ()
  (with-html-output-to-string (s)
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
       (:footer (:img :src "web/Lisp-glossy-120.jpg" :alt "Made with Lisp."))
       (:script :src "web/glue.js")))))

TODO footer の下に少し白い隙間ができてしまっている

### TODO JavaScript を動かす

web/glue.js のAPI 呼び出しがルーティングではなくGET メソッド呼び出しとなったので書き換える
	fetch( 'http://localhost:8000/api/svg/' + encodeURI(message), options )
        ↓
	fetch( 'http://localhost:8000/api/svg?name=' + encodeURI(message), options )

### text 入力後Enter で表示されるようにしたい

https://1-notes.com/javascript-fire-event-of-enter-key/

    function send(){
        const text = document.querySelector('[type=text]');
        say(text.value);
        return false; // for not to submit
    }

    const submit = document.querySelector('[type=submit]');
    submit.addEventListener('click', send);

    const input = document.querySelector('[type=text]');
    input.addEventListener('keypress', (e) => {
        console.log(e)
        if (e.keyCode == 13 ) send()
    });

### 入力エリアと送信ボタンの間に余白をもたせる

style.css で調整

### 最後に追加されたSVG の位置まで自動スクロールするようにしたい

img にid を発行し、その位置までジャンプ
https://developer.mozilla.org/ja/docs/Web/JavaScript/Closures
    function genRandomId(){
        let counter = 1
        return () => {
            return 'G' + counter++
        }
    }

    let randomId = genRandomId()

    randomId() => "G1"
    randomId() => "G2"


https://developer.mozilla.org/ja/docs/Web/API/Window/location
    location.href = "#G17"
        -> これで#svg-container 内だけでスクロールし、移動できることを確認

仕上げ
web/glue.js
		.then( svg => {
			let id = randomId() <----
			let img = document.createElement ('img')
			img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svg)))
			img.id = id <----
			let container = document.querySelector('#svg-container')
			container.appendChild(img)
			let br = document.createElement ('br')
			container.appendChild(br)
			location.href = "#" + id
		})

### HTML のコーディングの改善

https://edicl.github.io/cl-who/

1. <!DOCTYPE html> を含める

   - (SETF (cl-who:HTML-MODE) :HTML5)
   - with-html-output-to-string に :prologue t を与える

2. 属性の表記を src='some.png' ではなく src="some.png" とする

   - (setf cl-who:*attribute-quote-char* #\")

3. 適切に改行/インデントを入れる

https://edicl.github.io/cl-who/#*html-no-indent-tags*

    - with-html-output-to-string に :indent t を与える

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


## 4. 送信結果を受信し、
   それを<img src="XXX"> に指定するJavaScript を書く

   -> すでに web/glue.js として作成済み
   
### ここまでのlisp コードを svg-server.lisp として保存する

app/svg-server.lisp:

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
   
