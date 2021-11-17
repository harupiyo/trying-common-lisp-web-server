# Trying Web-Application Programming written by Common Lisp

「Common Lisp でWeb アプリケーションを記述する試み」

*メインの文章に進むには [今回調査した方式](#今回調査した方式) にジャンプしてください*

# まえがき

この文書はCommon Lisp 入門者である私(harupiyo) が、Common Lisp をWeb に適用するということに関し、

1. その意義について考えるという思想をはらみつつ
2. 具体的な方法を示す

ことを目的として書かれました。

試行錯誤の様子は [trying-log/](https://github.com/harupiyo/trying-common-lisp-web-server/tree/main/trying-log) 下に記録してあります。

この文書ではそれらの成果をまとめて整理したものです。

# Common Lisp を作動させたいWeb の２箇所の場所 - サーバーとクライアント

Web はサーバー・クライアントモデル※ であり、この両方でCommon Lisp を使うことができれば Lisper としては嬉しい.

サーバー側は問題ないが、クライアント側(Web ブラウザー) はJavaScript言語のみであり、Common Lisp を選ぶことができない.

従ってWeb ブラウザー上のJavaScript 言語の上に、いかにCommon Lisp 環境を用意するかというのが課題である.
ときにはサーバー側と協調することも選択肢に入る.

-----

※ サーバー・クライアントモデル:
利用者視点からはクライアントのことをフロントエンド(ユーザーに対面している手前側の意)、
サーバーのことをバックエンド(ユーザーからは垣間見えない裏側)とも言う。
またWeb ブラウザーは利用者の要望に応じて適切な通信・処理を担う代行者(agent)であるため、ユーザーエージェント(利用者の代理人) とも言う。

		役割による名前			場所による名前
	クライアント(Web Client)			フロントエンド
	サーバー(Web Server)			バックエンド

		担当者
	ユーザー(利用する人間自身)
	ユーザーエージェント(Web ブラウザー)

# Web ブラウザーでCommon Lisp を使うことの意義

なぜWeb ブラウザー上でCommon Lisp を使いたいのか？
可能性も含めこれを整理しておく。

- Lisper だから. JavaScript より高級な言語を使いたいから.
- Web アプリケーションを作りたいから.
	- Web アプリケーションは全てのインターネット利用者に開かれた、アクセス容易な、インストール不要なアプリケーション形態である.
	- Web ブラウザーさえがあれば利用できる. 今やスマートフォンにもWeb ブラウザーが入っている. これを "最も普及したOS" であるとみなせる.
		- モバイルコンピューティングの可能性を開く.
- サーバー側では不可能な、フロントエンド特有の仕事をさせたいから
	- リアルタイム処理
		- アニメーションやインタラクティブ処理
- ブラウザーが提供するAPI(ブラウザーAPI) を使いたいから
	- 非常に沢山のものが出てきている
		- Web の文書(HTML)、スタイル(CSS) を操作する - DOM API
		- サーバーからデータを取得する - Fetch API
		- グラフィックスを操作するAPI - Canvas API, WebGL API
		- 動画と音声のAPI、ビデオ通話のための - WebRTC API
		- 一覧はこちら [MDN|Web APIs](https://developer.mozilla.org/ja/docs/Web/API)
		- 概要はこちら [MDN|Web API の紹介](https://developer.mozilla.org/ja/docs/Learn/JavaScript/Client-side_web_APIs/Introduction)
	- 一方、セキュリティの観点から限定されてもいる
		- PC 上のファイルを直接開いた場合に動作しないAPI がある. localhost でもいいので、Web サーバー経由でファイルを供給する必要がある.
		- same-origin ポリシーの存在
		- HTTPS 配信下でしか利用できないAPI がある(ServiceWorkers, Push)
		- ユーザーからの許可が必要なものがある(Camera, Microphone, Notification, VR, メディアの自動再生)
	- あるいは、セキュリティ機能を利用できる
		- HTTPS(TLS/旧称・通称SSL)通信
		- sandbox 環境 [iframe 要素のsandbox属性](https://developer.mozilla.org/ja/docs/Web/HTML/Element/iframe#attr-sandbox)、[Content-Security-Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/sandbox)
		- [オリジン間リソース共有 (CORS;Cross-Origin Resource Sharing)](https://developer.mozilla.org/ja/docs/Web/HTTP/CORS)
		- ユーザー認証 - OAuth
- 他のWeb サービスが提供するWeb API(サードパーティAPI) と組み合わせたアプリケーションを作りたいから([マッシュアップ](https://e-words.jp/w/%E3%83%9E%E3%83%83%E3%82%B7%E3%83%A5%E3%82%A2%E3%83%83%E3%83%97.html))
	- Google マップ、ストリートビュー
	- Yahoo! Japan [日本語形態素解析](https://developer.yahoo.co.jp/webapi/jlp/ma/v1/parse.html)
	- [機械学習](https://goworkship.com/magazine/machine_learning_api/)
	- 音声認識、テキスト音声合成([Text-to-Speech; TTS](https://ja.wikipedia.org/wiki/%E9%9F%B3%E5%A3%B0%E5%90%88%E6%88%90))
- その逆として、他のWeb アプリケーションが利用できるAPI 基盤を提供したいから
	- セマンティック・ウェブ
- Web を巨大なデータベースとみなせるから
	- 大規模な用法はサーバー側のバッチ処理が適しているが、クライアント側でできればそれをインタラクティブなグラフに描画するなど、各種API と組み合わせた表現ができる
- ユーザーの秘書としての用法をしたいから
	- [ソフトウェア・エージェント](https://ja.wikipedia.org/wiki/%E3%82%BD%E3%83%95%E3%83%88%E3%82%A6%E3%82%A7%E3%82%A2%E3%82%A8%E3%83%BC%E3%82%B8%E3%82%A7%E3%83%B3%E3%83%88)
	- 通知API (Notification API, Vibration API)
- デバイスが持つセンサーを利用したいから(デバイス API)
	- カメラ、マイク、スピーカー
	- Geo Location
	- 加速度センサー
- 今後一層のインターネットの普及が見込めるから
	- [ユビキタス・コンピュ－ティング](https://kotobank.jp/word/%E3%83%A6%E3%83%93%E3%82%AD%E3%82%BF%E3%82%B9-9539)
	- [IoT](https://ja.wikipedia.org/wiki/%E3%83%A2%E3%83%8E%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%BF%E3%83%BC%E3%83%8D%E3%83%83%E3%83%88)

# 考えうる方式

サーバーとクライアントそれぞれの役割別に考えられる組み合わせについて列挙する.

1. サーバー側でCommon Lisp を動かす
	- 1-1. 従来型のWeb アプリケーション(Web 1.0) の形態
	- 1-2. Webブラウザーをターミナル、SLIME クライアントとして利用する
2. クライアント側でCommon Lisp を動かす
	- 2-1. クライアント側JavaScript からサーバー側のCommon Lisp をWeb API として呼び出す
	- 2-2. サーバー側でJavaScript にトランスパイルしたコードをクライアントで動かす
		- 2-2-1. [Parenscript](https://common-lisp.net/project/parenscript/)
			- 2-2-1-1. Parenscript を採用した[weblocks](https://40ants.com/weblocks/)
		- 2-2-2. [JSCL](https://github.com/jscl-project/jscl) で .lisp ファイルを .js に変換し、HTML に埋め込む
	- 2-3. クライアント側でCommon Lisp を動かす
		- 2-3-1. JavaScript 言語上で実装されたCommon Lisp 言語を利用する
			- 2-3-1-1. JSCL をブラウザー上で動かす
				- (まだフルスペックのCommon Lisp では無い)
		- 2-3-2. WebAssembly によってビルドされたCommon Lisp バイナリーを直接実行する
			- まだWebAssembly 化されたCommon Lisp 実装が無いようだ. ECL、SBCL でその言及が見られる程度
			- もしできたとしても、バイナリーデータサイズなど、フットプリントの重さが問題になる
				- さらに、ASDF,Quicklisp が利用できるかはわからない
			- しかしながら、JavaScript とは別スレッドで動作させることができ、またJavaScript とも通信が可能であるため、期待値の高い方式である
		- 2-3-2. Web ブラウザーを仮想マシンとするエミュレーター上にLinux 上でCommon Lisp を動かす
			- 実在する方式であるが、大変に動作が重い
			- 現状JavaScript と通信ができないのでほとんど意味がない
3. クライアント側のCommon Lisp とサーバー側のCommon Lisp がお互いに通信する
	3-1. JSON データのやり取り
	3-2. S 式のやり取り
		- 理想の方式であるが、セキュリティ上は大変危険である
			- サーバー側でサンドボックス環境を構築し、できることを制限する必要がある
4. その他？

# 今回調査した方式

今回調査・検討した方式は以下の３つ.

- 2-1. クライアント側JavaScript からサーバー側のCommon Lisp をWeb API として呼び出す
	- → 本稿で扱う
- 2-3-1-1. JSCL をブラウザー上で動かす
	- → この話題については別途 https://github.com/harupiyo/running-krep1-in-browser-using-JSCL に報告をまとめた.
		- なお、次のことも実現したかったが、まだ試せていない
			- 2-2-2. JSCL で .lisp ファイルを .js に変換し、HTML に埋め込む

# 2-1. クライアント側JavaScript からサーバー側のCommon Lisp をWeb API として呼び出す

入力画面から入力したテキストを、サーバー側 で生成したSVG でエコーバックするアプリケーションを作成する.

## 1. Common Lisp 製のWeb サーバーを立てる

Common Lisp 製Web サーバーであるHunchentoot を利用する

	https://edicl.github.io/hunchentoot/

Hunchentoot ではサーバーの設定を担うアクセプター(HUNCHENTOOT:EASY-ACCEPTOR)という名のオブジェクトを最初に作成(MAKE-INSTANCE)し、
アクセプターを引数にしてHunchentoot サーバーを起動する.

```
(ql:quickload :hunchentoot)

;;; start http server

(defvar *acceptor* (make-instance 'hunchentoot:easy-acceptor
                                  :port 8000
								  :document-root "./web"))

(hunchentoot:start *acceptor*)  ; Web サーバーの起動
; (hunchentoot:stop *acceptor*) ; (サーバーを停止したい時)
```

アクセプターに指定しているキーワード引数の意味は次の通り.

- :PORT 8000 ... Web サーバーが使うTCP のポート番号. HTTP は通常80 番を使うが、Unix-Like OS(Linux) の[ユーザーランド](https://e-words.jp/w/%E3%83%A6%E3%83%BC%E3%82%B6%E3%83%BC%E3%83%A9%E3%83%B3%E3%83%89.html) では、999番以下はprivileged(特権) ポートであるとして利用できない. そのため8000 番台を選ぶのが通例である. 8000番台はWeb サーバーのテスト環境であるという含みもある. 今どきの本番環境(公開サーバー) では、TLS(SSL)を導入しHTTPS(ポート番号は443) として運用することになるが、別途特権ユーザ－でApache, Nginx 等の実績のあるWeb サーバーと組み合わせることができる. Apache/Nginx をHunchentoot のProxy として前面に立て(この用法を[Reverse Proxy](https://ja.wikipedia.org/wiki/%E3%83%AA%E3%83%90%E3%83%BC%E3%82%B9%E3%83%97%E3%83%AD%E3%82%AD%E3%82%B7) と言う)、その内側にあるHunchentoot の8000番台と接続する方式を取る. TLS はApache, Nginx 側に設定すればよく、それらReverse Proxy とHunchentoot との間は暗号化なしでやり取りする. Apache, Nginx 等のメジャーなソフトウェアを採用することは導入の容易さ、信頼性、安全性など大きなメリットがある.
- :DOCUMENT-ROOT "./web" ... 静的コンテンツを設置するルートフォルダを指定している. またそのフォルダより上のフォルダにあるファイルを決して公開しないというセキュリティの意味も含む.

## 2. .css, .js, .png 等、静的コンテンツ(素材、[アセット](https://e-words.jp/w/%E3%82%A2%E3%82%BB%E3%83%83%E3%83%88.html)とも言う) の配信

現在は以下のアセットを使用しており、それぞれに対応するURL にアクセスすることで存在を確認できる.
ファイルのパスとURL は一対一で対応する.

- web/favicon.ico         ... http://localhost:8000/web/favicon.ico
- web/Lisp-glossy-120.jpg ... http://localhost:8000/web/Lisp-glossy-120.jpg
- web/style.css           ... http://localhost:8000/web/style.css
- web/glue.js             ... http://localhost:8000/web/glue.js

## 3. Common Lisp からWeb ページを配信する

この章ではCommon Lisp でHTML ページを記述する方法と、それをHunchentoot で配信する方法を扱う.

### 3-1. HTML ページを書く

Common Lisp からHTML を記述するために、CL-WHO ライブラリを導入する.

https://github.com/edicl/cl-who

```
(ql:quickload :cl-who)
```

今回のエコーバックするアプリは一行のテキスト入力を行う <input type="text"> と、送信ボタン <input type="submit"> の２つがコアになる要素であり、CL-WHO では次のように記述する.

```
(cl-who:with-html-output (*standard-output*)
  (:input :type "text")
  (:input :type "submit"))
==>
<input type='text' /><input type='submit' />   <--- *standard-output* に出力された情報
"<input type='text' /><input type='submit' />" <--- 返り値
```

- HTML 要素を直接に書き下した (:input ...) の表記は、WITH-HTML-OUTPUT マクロの中でのみ有効.

- 評価結果はXHTML 構文で出力されている. HTML5 以後もXHTML 構文は正式な仕様に含まれており妥当ではあるが、今回はXHTML である必要が無いため、読みやすいHTML 構文を選ぶことにする.
	```
	<input type='text' />	XHTML 構文
		↓
	<input type='text'>		HTML 構文
	```

	そのために次を評価しておく.

	```
	(setf (cl-who:html-mode) :html5)
	```

- 好みの問題だが、属性値の指定にシングルクォートではなくダブルクォートを使いたい.

	```
	<input type='text'>
		↓
	<input type="text">
	```
	次のようにする.
	```
	(setf cl-who:*attribute-quote-char* #\")
	```

- *standard-output* 等への、副作用的なストリームへの出力は不要で、返り値だけほしい場合には WITH-HTML-OUTPUT-TO-STRING マクロを使う
	```
	(cl-who:with-html-output-to-string (new-variable-as-string-stream)
	  (:input :type "text")
	  (:input :type "submit"))
	"<input type=\"text\"><input type=\"submit\">"
	```

- HTML に適宜改行を含めるには :INDENT T を指定する
	https://edicl.github.io/cl-who/#with-html-output-to-string
		キーワード引数の前に必要な省略できない第２引数の "&optional string-form" はCommon Lisp のWITH-OUTPUT-TO-STRING と同じ意味であり、ここでは NIL を指定する.
		http://www.lispworks.com/documentation/HyperSpec/Body/m_w_out_.htm

	```
	(cl-who:with-html-output-to-string (s nil :indent t)
	  (:input :type "text")
	  (:input :type "submit"))
	==>
	"
	<input type=\"text\">
	<input type=\"submit\">"
	```

### 3-2. HTML ページを配信する

このままHTML ページを完成させたとして、Hunchentoot から配信するには URL とページの結びつけ(ルーティング) が必要となる.

Hunchentoot ではこれをHandler と呼んでいる.
Handler を定義するにはDEFINE-EASY-HANDLER マクロを使う.

```
(hunchentoot:define-easy-handler (index :uri "/") ()
	"HTMLをここへ")
```

- 第一引数 INDEX は定義の名称で、Web 利用者には見えない部分である.
- 第二引数 :URI "/" はURL のパスの一部であり、http://localhost:8000/ の最後の / のこと.

### 3-3. HTML を完成させる

最終的なHTML のマークアップは次のようになった.

WITH-HTML-OUTPUT-TO-STRING に:PROLOGUE T が追加されているが、これはDOCTYPE 宣言(<!DOCTYPE html>)を出力することを指示している。

```
(cl-who:with-html-output-to-string (s nil :prologue t :indent t)
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
     (:script :src "web/glue.js"))))
==>
"<!DOCTYPE html>

<html>
  <head>
    <title>SVG TEXT GENERATOR
    </title>
    <meta charset=\"UTF-8\">
    <link rel=\"stylesheet\" href=\"web/style.css\">
    <link rel=\"icon\" type=\"image/vnd.microsoft.icon\" href=\"web/favicon.ico\">
  </head>
  <body>
    <header>
      <h1>SVG TEXT GENERATOR
      </h1>
      <input type=\"text\">
      <input type=\"submit\">
    </header>
    <div id=\"svg-container\"></div>
    <footer>
      <img id=\"made-with-lisp\" src=\"web/Lisp-glossy-120.jpg\" alt=\"Made with Lisp.\">
    </footer>
    <script src=\"web/glue.js\"></script>
  </body>
</html>"
```

### 3-4. ここまでで完成したソースの全体

```
(ql:quickload '(:hunchentoot :cl-who))

;;; start http server

(defvar *acceptor* (make-instance 'hunchentoot:easy-acceptor
                                  :port 8000
								  :document-root "./web"))

(hunchentoot:start *acceptor*)  ; Web サーバーの起動

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
```

ここで作成したWeb ページは、
http://localhost:8000/ 
から確認できる.

#### コラム 考察: Common Lisp でHTML を記述することの意義

HTML を書いた経験のある人なら、CL-WHO を使ったコーディングにはなんら抵抗がないであろうが、S 式で書いたからといって特に生産性が上がらないという疑問を持つ. 
「HTML で書けばいいことをなぜS式で書き直せばならないのだろう？それに、Lisper 以外が保守できなくなる点で邪悪である」と思うかもしれない.

特に試行錯誤の連続である制作の過程において、デザイナーやHTML/CSS のコーダーが気軽に触れなくなるのは厄介なボトルネックとなる.

またLisper にあっても、頭の中に別の言語の事情(HTMLとCSSとJavaScript、及びそれらの相互作用) を考えながらS 式に置き換えていくことは、そちらに熟達していないと難しい。

きちんとした制作チームがいる場合は、分業の観点からもそれぞれの専門職が担当したほうが理にかなっている.

したがってCL-WHO を導入する意味を押さえて置く必要がある.

それにはここにあるexample を見ると良い.
https://edicl.github.io/cl-who/#example
手でHTML を書くにはちょっと困難なような事をあっさりやってのけている.

S式で表現すれば、Common Lisp と渾然一体となる.
CL-WHO そのものが生産性を上げるのではなく、それ自身がCommon Lisp の一部であるという理解が必要だ.
CL-WHO とCommon Lisp は**直交している**ので、自由に組み合わせが可能なのだ.
ゆえにコード量を減らすのが目的であればマクロを書くなど、"寝技" に持ち込むことがいかようにも可能である.

なお、HTML/CSS のコーダーと協業する必要があれば、HTML/CSS の中に部分的にCommon Lisp コードがお邪魔するという形の「テンプレートエンジン」の仕組みが問題を解決するだろう.
[Djula](https://github.com/mmontone/djula) 等がある.

#### コラム: URI? URL? URN???

ある情報資源に固有値を割り振って特定できるようにする手段のことで、[URL](https://ja.wikipedia.org/wiki/Uniform_Resource_Locator)(場所を示す住所によって特定)と[URN](https://ja.wikipedia.org/wiki/Uniform_Resource_Name)(名前によって特定) の２種があり、そのスーパーセットとして[URI](https://ja.wikipedia.org/wiki/Uniform_Resource_Identifier) がある.

これらの関係はこの図が分かりやすい.
	https://ja.wikipedia.org/wiki/Uniform_Resource_Identifier#/media/%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB:URI_Venn_Diagram.svg

なお、関連してURI をUnicode が利用できるように国際対応化した[IRI](https://ja.wikipedia.org/wiki/Internationalized_Resource_Identifier)、IRI の拡張として[XRI](https://ja.wikipedia.org/wiki/Extensible_Resource_Identifier) がある.


##### Web における扱い

さて、(狭義の、個人的な経験としての)Web 業界では、URI とURL の２つのみが使われてきた.
しかもURI とURL はほぼ同じ意味で使われていて、それを言う本人自身に疑問を抱かせる種でもあった.

それには次のようないささか罪深い背景がある.

https://ja.wikipedia.org/wiki/Uniform_Resource_Identifier#%E8%A8%AD%E8%A8%88

> 2001年、W3CはRFC 3305内で、上記の考え方を古典的な見解とした。ここで示されたW3Cの新たな考え方により、従来のURLとURNとはすべてURIと呼ばれることになった。URLやURNといった語はW3Cによって非公式な表現とされた。

> 2012年、WHATWGによってURL Standardの開発が開始された。URL Standardでは、目標の1つとしてRFC 3986 (URI)とRFC 3987 (IRI)を過去のものにすることを掲げている。また、従来のURIやIRIを区別する必要が無いとして、すべてURLの語を用いている。さらに、W3Cでも、このURL Standardのスナップショットをワーキンググループノートとして公開している。

Hunchentoot のキーワード引数が :URI になっているのはこの名残であろう.
Webブラウザーが内蔵するAPI の名にもURI とURL の乱れが認められる.

##### HTML における最新の見解はURL

W3C HTML5 以降、その立場を引き継いだ最新仕様である [WHATWG HTML Living Standard](https://html.spec.whatwg.org/) で用いられる語はすべて"URL" で統一されている.

## 4. Common Lisp からSVG 画像を配信する API を作る

SVG はベクターグラフィックスのフォーマットであり、XML ベースのマ－クアップ言語である.

SVG(Scalable Vector Graphics)
https://ja.wikipedia.org/wiki/Scalable_Vector_Graphics

最新の仕様はW3C によるSVG1.1 第２版である.

Scalable Vector Graphics (SVG) 1.1 (Second Edition) W3C Recommendation 16 August 2011
https://www.w3.org/TR/SVG11/

ここではCommon Lisp によるSVG の生成とその配信(Web APIづくり)を扱う.

4-1. SVG を生成する CL-SVG
4-2. SVG を配信するハンドラーを記述する
	4-2-1. GET 引数の受け取り方
	4-2-2. HTTP-Response のMIME 型を指定する
4-3. 完成形

### 4-1. SVG を生成する CL-SVG

cl-svg:
https://github.com/wmannis/cl-svg
Document:
https://github.com/wmannis/cl-svg/blob/master/docs/API.md

```
(ql:quickload :cl-svg)
```

使い方は、具体例が掲載された
https://github.com/wmannis/cl-svg/blob/master/testing.lisp
を眺めるのがよい.

まず、SVG を描画する対象となる媒体を作成する.
ここではscene という名前をつけている.

```
(defparameter *scene* (cl-svg:make-svg-toplevel 'cl-svg:svg-1.1-toplevel :height 300 :width 300))
```

- :height 300 ... 高さ300px 
- :width  300 ... 幅  300px 

次にDRAW マクロを使ってscene に描画する.

```
(cl-svg:draw *scene* (:rect :x 5 :y 5 :height 30 :width 30))
```

:RECT はSVG にある基本的な図形の一つである矩形をしめしている.

その他の基本図形はここに記述がある.
https://www.w3.org/TR/SVG11/shapes.html

このようにDRAW マクロを使ってscene に次々と描画していくことができる.

出来上がったscene を最終的にSVG を出力するにはこのようにする.

```
(with-output-to-string (string)
   (cl-svg:stream-out string *scene*) string)
==>
"<?xml version=\"1.0\" standalone=\"no\"?>
<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\"
  \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">
<svg width=\"300\" height=\"300\" version=\"1.1\" id=\"toplevel\"
    xmlns=\"http://www.w3.org/2000/svg\"
    xmlns:xlink=\"http://www.w3.org/1999/xlink\">
  <rect x=\"5\" y=\"5\" height=\"30\" width=\"30\"/>
</svg>
"
```

さて、今回は入力画面に入れたテキストをSVG でエコーバックする仕組みとするのだった.

そこでSVG でテキストを描画する仕組みとした.
```
(let ((scene (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 100 :width 1200)))
    (svg:text scene (:x 10 :y 50 :font-family "serif" :font-size 50) ; font 指定ができる
	    "Hello Common Lisp!") 		; 埋め込みたいテキストをここに指定
    (with-output-to-string (string)
        (svg:stream-out string scene)
		string))
==>
"<?xml version=\"1.0\" standalone=\"no\"?>
<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\"
  \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">
<svg width=\"1200\" height=\"100\" version=\"1.1\" id=\"toplevel\"
    xmlns=\"http://www.w3.org/2000/svg\"
    xmlns:xlink=\"http://www.w3.org/1999/xlink\">
  <text x=\"10\" y=\"50\" font-family=\"serif\" font-size=\"50\">
    Hello Common Lisp!
  </text>
</svg>
"
```

- SVG: はCL-SVG: パッケージのニックネームである.

- テキストの場合には、CL-SVG:DRAW ではなく、CL-SVG:TEXT を使う.
	https://github.com/wmannis/cl-svg/blob/master/testing.lisp#L176

	- なお、SVG のText はここに仕様がある.
		https://www.w3.org/TR/SVG11/text.html

### 4-2. SVG を配信するハンドラーを記述する

SVG 生成API のURL を http://localhost:8000/api/svg とすると、ハンドラーの定義は次のようになる.
```
(hunchentoot:define-easy-handler (svg :uri "/api/svg") ()
	"生成したSVGをここへ")
```

#### 4-2-1. GET 引数の受け取り方

URL に埋め込まれて渡されたテキスト(GET パラメーターと言う) をもとに、SVG を生成したい.
この場合のURL は次のようになる.

http://localhost:8000/api/svg?name=Hello%20Common%20Lisp!

URL 末尾の? 以降がGET パラメーターである.
name=Hello%20Common%20Lisp!

GET パラメーターは name=value の形をしている.

ここでは名"name" の値として "Hello%20Common%20Lisp!" が渡されている.

"%20" は空白文字のことである.
URL では含めて良い文字が限定されており、それ以外の文字はUTF-8 符号のそれぞれのバイトを "%FF" の形のエスケープシーケンスに置き換える必要がある.(これを[パーセントエンコーディング、俗にURL エンコーディングとも](https://ja.wikipedia.org/wiki/%E3%83%91%E3%83%BC%E3%82%BB%E3%83%B3%E3%83%88%E3%82%A8%E3%83%B3%E3%82%B3%E3%83%BC%E3%83%87%E3%82%A3%E3%83%B3%E3%82%B0) 言う)

このふるまいはWeb サーバーであるHunchentoot 側で処理してくれるため、プログラマは意識する必要はない.

さて、GET パラメーターで指定された値を Common Lisp 側の引数として受け取るには次のようにする:

```
(hunchentoot:define-easy-handler (svg :uri "/api/svg") (name) ; ←GET パラメーターの名前と同じ変数名を指定する
	name) ; "Hello Common Lisp!" 
```

#### 4-2-2. HTTP Response のMIME 型を指定する

本API が返すコンテンツが SVG だということを、[HTTP Response Header](https://developer.mozilla.org/ja/docs/Glossary/Response_header) 内の[MIME 型](https://developer.mozilla.org/ja/docs/Web/HTTP/Basics_of_HTTP/MIME_types)で示す必要がある.
HTML であれば "text/html"を、CSS であれば "text/css"を、JavaScript であれば "text/javascript" をそれぞれ返す必要があり、そのMIME 型にしたがってブラウザーは適切にふるまう.

SVG のMIME 型は "image/svg+xml" である.
https://developer.mozilla.org/ja/docs/Web/HTTP/Basics_of_HTTP/MIME_Types#svg

Hunchentoot にMIME 型を指定するには、次のようにする:
```
(hunchentoot:define-easy-handler (svg :uri "/api/svg") (name)
  (setf (hunchentoot:content-type*) "image/svg+xml") ; <---- MIME 型
  "生成したSVG")
```

### 4-3. 完成形

ここまでのことをまとめたSVG API のソースコードは次の通り:

```
;;; Making SVG API

(hunchentoot:define-easy-handler (svg :uri "/api/svg") (name)
  (setf (hunchentoot:content-type*) "image/svg+xml")
  (let ((scene (svg:make-svg-toplevel 'svg:svg-1.1-toplevel :height 100 :width 1200)))
    (svg:text scene (:x 10 :y 50 :font-family "serif" :font-size 50)
      name) ; <--- NAME is a GET parameter value passing by in URL.
    (with-output-to-string (string)
       (svg:stream-out string scene) string)))
```

### 4-4. Common Lisp コーディング総まとめ

さて、ここまでがCommon Lisp 側の実装のすべてであり、

	[app/svg-server.lisp](https://github.com/harupiyo/trying-common-lisp-web-server/blob/main/app/svg-server.lisp)

にまとめた.

## 5. Web ページ上の入力フォームとCommon Lisp 側SVG 配信API を接続するJavaScript を作る

話はWeb ブラウザー側(フロントエンド)へと移る.

ここには
http://localhost:8000/
による入力画面が見えており、送信ボタンも付いている.

それらインタラクティブ要素の操作をきっかけに、Web サーバー側API を叩いて取得したSVG を画面に表示するJavaScript の仕事について述べる.

JavaScriptはボタンの操作とサーバー側のAPI とを、またSVG 画像と画面を結びつける "糊(glue)" であるように思う.
[Glue Code](https://ja.wikipedia.org/wiki/%E3%82%B0%E3%83%AB%E3%83%BC%E3%82%B3%E3%83%BC%E3%83%89) から引用すると、
> プログラムの要求仕様の実現には一切寄与しないが、もともと互換性がない部分同士を結合するためだけに働くコードである。
と説明されている. まさにこれである.

"糊だ" という時、本質的な仕事を担うわけではないので、プログラミングのレイヤーとしては薄いものである. (重要ではある)

その意味を込めて [js/glue.js](https://github.com/harupiyo/trying-common-lisp-web-server/blob/main/web/glue.js) というファイル名にした.
[MVC モデル](https://ja.wikipedia.org/wiki/Model_View_Controller)のV やVC、[Document-View アーキテクチャ](https://docs.microsoft.com/ja-jp/cpp/mfc/document-view-architecture?view=msvc-170)の View と言ってもよい.

ソースコードは次の通り:
```
// 1.
function send(){
	const text = document.querySelector('[type=text]')
	say(text.value)
	return false // for not to submit
}

// 2.
const submit = document.querySelector('[type=submit]')
submit.addEventListener('click', send)

// 3.
const input = document.querySelector('[type=text]')
input.addEventListener('keypress', (e) => {
	console.log(e)
	if (e.keyCode == 13 ) send()
});

// 4.
function genRandomId(){
	let counter = 1
	return () => {
		return 'G' + counter++
	}
}
const randomId = genRandomId()

// 5.
function say(message){
	const options = { mode: 'same-origin', headers: { 'Content-Type': 'images/svg+xml' } }
	fetch( 'http://localhost:8000/api/svg?name=' + encodeURI(message), options ) // 6.
	.then( response => {
		if (!response.ok) throw new Error('Fetch API: Network response was not ok')
		if ( response.headers.get('content-type') !== 'image/svg+xml' ) throw new Error('Fetch API: Allow SVG only')
		return response.blob()											// 7.
	}) 
	.then( svg => {
		const container = document.querySelector('#svg-container')
		const id = randomId()
		const img = document.createElement('img')
		const br = document.createElement('br')
		const reader = new FileReader()										// 8.
		reader.addEventListener("load", () => {
			img.src = reader.result;
			img.id = id											// 9.
			img.alt = message
			container.appendChild(img)									// 10.
			container.appendChild(br)
			location.href = "#" + id									// 11.
		})
		reader.readAsDataURL(svg)
	})
}
```

薄いと言ったが、東奔西走する有能なマネージャーのように? 忙しいコードとなっている.
上下水道のようなインフラの配管があちこちに走っている状態である.

本稿ではJavaScript プログラミングを述べることは主眼ではないので、要点のみをまとめる.

1. send() はテキスト入力欄の中身を関数 say() に渡す. return false は<input type="submit"> の「送信ボタン」を押した際に、画面遷移の動きをさせないための約束事である.
2. <input type="submit"> をクリックした時に send() を呼び出すように紐づけている.
3. <input type="text"> のテキスト入力欄の中でEnter キーを押した時に send() を呼び出すように紐づけている.
4. JavaScript でのクロージャの書き方. GENSYM のように呼び出される度に固有値を生成する仕組み.
5. say() は中核となる関数で、SVG API を呼び出し、画像を受け取って画面に貼り付ける一連の仕事を行う.
6. SVG API をコールするためのURL を作っている. 日本語等Unicode の文字を送信するために、パーセントエンコーディングを行う encodeURI() API を呼び出している.
7. サーバから返ってきたSVG を[Blob; Binary Large OBject](https://developer.mozilla.org/ja/docs/Web/API/Blob) 形式にして次の処理にまわしている. SVG 自体はUTF-8のテキストなので response.text() メソッドでテキスト形式で扱うのが適切なように思うが、JavaScript の文字列の内部表現はUTF-16 でありややこしくなる(HTML 側はUTF-8だ). またBlob 形式では欲しい [Data URI Scheme](https://ja.wikipedia.org/wiki/Data_URI_scheme) 形式に簡単に変換できる手段があるため、Blob とみなして処理を続けるのが近道である. Blob とはいえせいぜいが500Bytes 程度の小さなバイナリーで、決してLarge ではない. Binary であることが望ましいだけだ.
8. ここでBlob 形式のSVG を[Data URI Scheme](https://ja.wikipedia.org/wiki/Data_URI_scheme) に変換する. FileReader.readAsDataURL() メソッドによってそれがなされる.その処理が終われば<img> 要素のsrc 属性にセットすることができる.
9. 4 の関数で生成した固有ID を<img> 要素に割りつけている. これは10. のため.
10. JavaScript で作り上げた<img> 要素を、画面内の要素の子に割り付けることで初めて可視化される.
11. 今、追加したての<img> 要素の位置までページ内ジャンプ(スクロール)する.

### これでエコーバックをするWeb アプリケーションは完成となる.

## 6. これらを VPS サーバー等に構築し、公開する

固有のサーバーのセットアップの詳細は避けるが、およそ以下のことを行う.

- ユーザー作成
- インプットメソッドを含む日本語環境設定
- sshd 等セキュリティ設定
- SBCL & QuickLisp インストール
- SLIME が使えるようにテキストエディタの環境設定(vim/emacs)
- Reverse Proxy としてNginx Webサーバーを立てる
- Nginx にLet's Encrypt のTLS を導入する
- GitHub からのファイルのデプロイ
- Common Lisp のHunchentoot サーバーを起動する
	- 落ちた時に自動的に再起動するよう、デーモン化を行う
- 接続テスト

# 参考記事
- https://lispcookbook.github.io/cl-cookbook/web.html
