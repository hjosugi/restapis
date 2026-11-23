;;;; REST API に CRUD + 検索を一通り投げるクライアント（dexador + jzon）。

(defpackage #:users-client
  (:use #:cl)
  (:local-nicknames (#:jzon #:com.inuoe.jzon))
  (:export #:main))

(in-package #:users-client)

(defstruct user
  id name email age)

(defstruct user-input ; jzon:stringify で {"name":..,"email":..,"age":..} になる
  name email age)

(defun base-url ()
  (or (uiop:getenv "API_URL") "http://127.0.0.1:8015"))

(defun call (method path &optional input)
  "リクエストを 1 本送り、送った内容と返ってきた内容を表示する。レスポンスのボディ（文字列）を返す。"
  (let ((url (concatenate 'string (base-url) path))
        (json (and input (jzon:stringify input))) ; 構造体 → JSON 文字列
        (headers (and input '(("Content-Type" . "application/json")))))
    (format t "> ~A ~A~@[ ~A~]~%" method path json)
    ;; 4xx / 5xx は dex:http-request-failed になるので、再起動 ignore-and-continue で普通の戻り値にする
    (handler-bind ((dex:http-request-failed #'dex:ignore-and-continue))
      (multiple-value-bind (body status) (dex:request url :method method :headers headers :content json)
        (format t "< ~D ~A~%~%" status body)
        body))))

(defun parse-user (json)
  "JSON 文字列 → user 構造体（jzon:parse はオブジェクトをハッシュテーブルで返す）。"
  (let ((object (jzon:parse json)))
    (make-user :id (gethash "id" object)
               :name (gethash "name" object)
               :email (gethash "email" object)
               :age (gethash "age" object))))

(defun run ()
  (format t "--- 1. 一覧取得~%")
  (call :get "/users")

  (format t "--- 2. 作成~%")
  (let* ((input (make-user-input :name "Carol" :email "carol@example.com" :age 35))
         (created (parse-user (call :post "/users" input)))
         (user-path (format nil "/users/~D" (user-id created))))

    (format t "--- 3. 1件取得~%")
    (call :get user-path)

    (format t "--- 4. 更新~%")
    (call :put user-path (make-user-input :name "Carol Smith" :email "carol@example.com" :age 36))

    (format t "--- 5. 検索（名前の部分一致）~%")
    (call :get (format nil "/users?~A" (quri:url-encode-params '(("name" . "car")))))

    (format t "--- 6. 検索（年齢の下限）~%")
    (call :get (format nil "/users?~A" (quri:url-encode-params '(("min_age" . "30")))))

    (format t "--- 7. 削除~%")
    (call :delete user-path)

    (format t "--- 8. 削除されたことを確認（404 になる）~%")
    (call :get user-path)))

(defun main ()
  ;; 接続タイムアウト付きだと、サーバー未起動（接続拒否）でもタイムアウトまで待たされるので無効にする
  (let ((dex:*default-connect-timeout* nil))
    (handler-case (run)
      (usocket:socket-error (e)
        (format *error-output* "リクエスト失敗（サーバーは起動していますか？）: ~A~%" e)
        (uiop:quit 1)))))
