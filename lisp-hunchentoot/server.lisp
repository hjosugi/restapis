;;;; users リソースの CRUD を提供する REST API サーバー（Hunchentoot + easy-routes / インメモリ保存）。

(defpackage #:users-server
  (:use #:cl)
  (:local-nicknames (#:jzon #:com.inuoe.jzon))
  (:export #:start #:main))

(in-package #:users-server)

;;; ---- ストア: id → user のハッシュテーブル。Hunchentoot はリクエストごとにスレッドを使うのでロックで守る

(defstruct user
  id name email age) ; jzon は構造体のスロットを {"id":..,"name":..} の JSON オブジェクトにする

(defvar *lock* (bt:make-lock "users"))
(defvar *users* (make-hash-table))
(defvar *next-id* 1)

(defun add-user (user)
  "次の id を振って保存する。"
  (bt:with-lock-held (*lock*)
    (setf (user-id user) *next-id*)
    (incf *next-id*)
    (setf (gethash (user-id user) *users*) user)))

(defun list-users (name min-age)
  "name は部分一致（大文字小文字を無視）、min-age は年齢の下限。両方あれば AND。id 昇順のベクタを返す。"
  (bt:with-lock-held (*lock*)
    (let ((users (loop :for user :being :the :hash-values :of *users*
                       :when (and (or (null name) (search name (user-name user) :test #'char-equal))
                                  (or (null min-age) (>= (user-age user) min-age)))
                       :collect user)))
      ;; リストのままだと空のとき nil → JSON の false になるのでベクタ（→ []）にする
      (coerce (sort users #'< :key #'user-id) 'vector))))

(defun find-user (id)
  (bt:with-lock-held (*lock*)
    (gethash id *users*)))

(defun replace-user (id user)
  "全置換。存在しない id なら nil。"
  (bt:with-lock-held (*lock*)
    (when (gethash id *users*)
      (setf (user-id user) id
            (gethash id *users*) user))))

(defun remove-user (id)
  "削除できたら t。"
  (bt:with-lock-held (*lock*)
    (remhash id *users*)))

(add-user (make-user :name "Alice" :email "alice@example.com" :age 30))
(add-user (make-user :name "Bob" :email "bob@example.com" :age 25))

;;; ---- JSON レスポンス

(defun json-response (status value)
  "ステータスコードと Content-Type を設定し、VALUE を JSON 文字列にして返す。"
  (setf (hunchentoot:return-code*) status
        (hunchentoot:content-type*) "application/json")
  (jzon:stringify value))

(defun fail (status message)
  "{\"error\": MESSAGE} を返してハンドラーを抜ける（Hunchentoot の既定の HTML エラーページを使わない）。"
  (let ((body (make-hash-table :test #'equal)))
    (setf (gethash "error" body) message)
    (hunchentoot:abort-request-handler (json-response status body))))

(defun parse-int (string status message)
  "STRING を整数にする。整数でなければ STATUS のエラーで抜ける。"
  (handler-case (parse-integer string)
    (parse-error () (fail status message))))

(defun parse-user-input ()
  "リクエストボディの JSON を検証して user を作る。不正なら 400。"
  (let ((json (handler-case (jzon:parse (hunchentoot:raw-post-data :force-text t))
                (error () (fail 400 "malformed JSON"))))) ; 壊れた JSON / ボディなし (nil)
    (unless (hash-table-p json)
      (fail 400 "body must be a JSON object"))
    (let ((name (gethash "name" json))
          (email (gethash "email" json))
          (age (gethash "age" json))) ; JSON の "1"（文字列）や 1.5 は integer ではない
      (unless (and (stringp name) (plusp (length name)))
        (fail 400 "name must be a non-empty string"))
      (unless (and (stringp email) (plusp (length email)))
        (fail 400 "email must be a non-empty string"))
      (unless (and (integerp age) (>= age 0))
        (fail 400 "age must be an integer >= 0"))
      (make-user :name name :email email :age age))))

;;; ---- ルート定義: (defroute 名前 ("パス" :method メソッド) (パラメーター) 本体)
;;; パスの :id は同名の変数 id（文字列）に束縛される

;; GET /users?name=al&min_age=20（&get の変数はクエリ文字列から。無ければ nil）
(easy-routes:defroute users-index ("/users" :method :get) (&get name (min-age :real-name "min_age"))
  (let ((min-age (and min-age (parse-int min-age 400 "min_age must be an integer"))))
    (json-response 200 (list-users name min-age))))

(easy-routes:defroute users-create ("/users" :method :post) ()
  (json-response 201 (add-user (parse-user-input))))

(easy-routes:defroute users-show ("/users/:id" :method :get) ()
  (let ((user (find-user (parse-int id 404 "user not found"))))
    (unless user
      (fail 404 "user not found"))
    (json-response 200 user)))

(easy-routes:defroute users-update ("/users/:id" :method :put) ()
  (let ((user (replace-user (parse-int id 404 "user not found") (parse-user-input))))
    (unless user
      (fail 404 "user not found"))
    (json-response 200 user)))

(easy-routes:defroute users-destroy ("/users/:id" :method :delete) ()
  (unless (remove-user (parse-int id 404 "user not found"))
    (fail 404 "user not found"))
  (setf (hunchentoot:return-code*) 204)
  nil) ; 204 はボディなし

;;; ---- 起動

(defun start (port)
  "PORT で待ち受けを始めて acceptor を返す（REPL では (users-server:start 8015) → (hunchentoot:stop acceptor)）。"
  ;; リクエスト / レスポンスの文字コードを UTF-8 に（Hunchentoot の既定は Latin-1）
  (setf hunchentoot:*hunchentoot-default-external-format*
        (flex:make-external-format :utf-8 :eol-style :lf))
  (hunchentoot:start
    (make-instance 'easy-routes:easy-routes-acceptor :address "127.0.0.1" :port port)))

(defun main ()
  "PORT（既定 8015）で起動して、Ctrl-C まで動き続ける。"
  (let ((port (parse-integer (or (uiop:getenv "PORT") "8015"))))
    (start port)
    (format t "listening on http://127.0.0.1:~D~%" port)
    ;; Hunchentoot は別スレッドで動くので、メインスレッドは待つだけ
    (handler-case (loop (sleep 60))
      (sb-sys:interactive-interrupt ()
        (uiop:quit 0)))))
