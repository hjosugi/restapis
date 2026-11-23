;;;; ASDF のシステム定義。server / client を別々のシステムにして、必要なライブラリだけ読み込む

(defsystem "users"
  :description "users REST API (Hunchentoot) と Common Lisp クライアント (dexador)"
  :license "MIT"
  :depends-on ("users/server" "users/client"))

(defsystem "users/server"
  :depends-on ("hunchentoot" "easy-routes" "com.inuoe.jzon" "bordeaux-threads" "flexi-streams")
  :components ((:file "server")))

(defsystem "users/client"
  :depends-on ("dexador" "quri" "usocket" "com.inuoe.jzon")
  :components ((:file "client")))
