(ns users.client
  "REST API に CRUD + 検索を一通り投げるクライアント（babashka/http-client + jsonista）。"
  (:require
   [babashka.http-client :as http]
   [clojure.string :as str]
   [jsonista.core :as json])
  (:import
   (java.io IOException)
   (java.net URI)))

(def base-url (or (System/getenv "API_URL") "http://127.0.0.1:8014"))

(defn call
  "リクエストを 1 本送り、送った内容と返ってきた内容を表示する。レスポンス（マップ）を返す。"
  [method path & {:keys [query-params body]}]
  (let [json-body (some-> body json/write-value-as-string) ; Clojure のマップ → JSON 文字列
        res (http/request (cond-> {:method method
                                   :uri (str base-url path)
                                   :query-params query-params ; {:name "car"} → ?name=car
                                   :version :http1.1 ; JDK の HttpClient が h2c へのアップグレードを試みないように
                                   :throw false}     ; 4xx / 5xx でも例外にせずレスポンスを返す
                            json-body (assoc :headers {"Content-Type" "application/json"}
                                             :body json-body)))
        ^URI uri (:uri res)] ; 実際に送った URI（クエリ付き）
    (println (str/join " " (cond-> [">" (str/upper-case (name method))
                                    (str (.getRawPath uri) (some->> (.getRawQuery uri) (str "?")))]
                             json-body (conj json-body))))
    (println "<" (:status res) (:body res))
    (println)
    res))

(defn- parse-user
  "JSON 文字列 → キーワードキーのマップ {:id 3 :name \"Carol\" ...}"
  [s]
  (json/read-value s json/keyword-keys-object-mapper))

(defn -main [& _]
  (try
    (println "--- 1. 一覧取得")
    (call :get "/users")

    (println "--- 2. 作成")
    (let [created (parse-user (:body (call :post "/users" :body {:name "Carol" :email "carol@example.com" :age 35})))
          user-path (str "/users/" (:id created))]

      (println "--- 3. 1件取得")
      (call :get user-path)

      (println "--- 4. 更新")
      (call :put user-path :body {:name "Carol Smith" :email "carol@example.com" :age 36})

      (println "--- 5. 検索（名前の部分一致）")
      (call :get "/users" :query-params {:name "car"})

      (println "--- 6. 検索（年齢の下限）")
      (call :get "/users" :query-params {:min_age 30})

      (println "--- 7. 削除")
      (call :delete user-path)

      (println "--- 8. 削除されたことを確認（404 になる）")
      (call :get user-path))
    (catch IOException e
      (binding [*out* *err*]
        (println "リクエスト失敗（サーバーは起動していますか？）:" (str e)))
      (System/exit 1))))
