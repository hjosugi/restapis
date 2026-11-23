(ns users.server
  "users リソースの CRUD を提供する REST API サーバー（reitit + Ring + Jetty / インメモリ保存）。"
  (:require
   [clojure.string :as str]
   [malli.error :as me]
   [muuntaja.core :as m]
   [reitit.coercion :as coercion]
   [reitit.coercion.malli :as malli]
   [reitit.ring :as ring]
   [reitit.ring.coercion :as rrc]
   [reitit.ring.middleware.exception :as exception]
   [reitit.ring.middleware.muuntaja :as muuntaja]
   [reitit.ring.middleware.parameters :as parameters]
   [ring.adapter.jetty :as jetty]))

;; ---- ストア: 状態を 1 つの atom に入れる。swap! は不可分に更新されるのでロック不要

(defn- add-user
  "次の id を振ってユーザーを追加した新しい状態を返す。"
  [{:keys [next-id] :as state} input]
  (-> state
      (assoc-in [:users next-id] (into {:id next-id} input))
      (update :next-id inc)))

(defonce db
  (atom (-> {:next-id 1 :users (sorted-map)} ; sorted-map なので vals が id 昇順になる
            (add-user {:name "Alice" :email "alice@example.com" :age 30})
            (add-user {:name "Bob" :email "bob@example.com" :age 25}))))

(defn list-users
  "name は部分一致（大文字小文字を無視）、min_age は年齢の下限。両方あれば AND。"
  [{:keys [name min_age]}]
  (cond->> (vals (:users @db))
    name (filter #(str/includes? (str/lower-case (:name %)) (str/lower-case name)))
    min_age (filter #(>= (:age %) min_age))
    :always vec)) ; 0 件でも null ではなく [] にする

(defn get-user [id]
  (get-in @db [:users id]))

(defn create-user! [input]
  (let [[before after] (swap-vals! db add-user input)]
    (get-in after [:users (:next-id before)])))

(defn update-user!
  "全置換。存在しない id なら nil。"
  [id input]
  (-> (swap! db (fn [state]
                  (cond-> state
                    (contains? (:users state) id) (assoc-in [:users id] (into {:id id} input)))))
      (get-in [:users id])))

(defn delete-user!
  "削除できたら true。"
  [id]
  (let [[before _] (swap-vals! db update :users dissoc id)]
    (contains? (:users before) id)))

;; ---- 入力チェック: malli スキーマ。JSON の "1"（文字列）は :int にならないので 400

(def UserInput
  [:map
   [:name [:string {:min 1}]]
   [:email [:string {:min 1}]]
   [:age [:int {:min 0}]]])

(defn- error [status message]
  {:status status :body {:error message}})

(def not-found (error 404 "user not found"))

;; ---- ルート定義: パスごとにメソッド → {:parameters スキーマ, :handler 関数} をデータで書く
;; 入力チェック済みの値は (:parameters request) の :query / :path / :body に入る

(def routes
  ["/users"
   ["" {:get {:parameters {:query [:map ; GET /users?name=al&min_age=20
                                   [:name {:optional true} :string]
                                   [:min_age {:optional true} :int]]}
              :handler (fn [{{:keys [query]} :parameters}]
                         {:status 200 :body (list-users query)})}
        :post {:parameters {:body UserInput}
               :handler (fn [{{:keys [body]} :parameters}]
                          {:status 201 :body (create-user! body)})}}]
   ["/:id" {:parameters {:path [:map [:id :int]]} ; /users/abc は 400
            :get {:handler (fn [{{{:keys [id]} :path} :parameters}]
                             (if-let [user (get-user id)]
                               {:status 200 :body user}
                               not-found))}
            :put {:parameters {:body UserInput}
                  :handler (fn [{{{:keys [id]} :path :keys [body]} :parameters}]
                             (if-let [user (update-user! id body)]
                               {:status 200 :body user}
                               not-found))}
            :delete {:handler (fn [{{{:keys [id]} :path} :parameters}]
                                (if (delete-user! id)
                                  {:status 204}
                                  not-found))}}]])

;; reitit の既定のエラー応答（text/plain や coercion の詳細データ）を {"error": ...} にそろえる
(def exception-middleware
  (exception/create-exception-middleware
   (merge exception/default-handlers
          {:muuntaja/decode (fn [_ _] (error 400 "malformed JSON"))
           ::coercion/request-coercion (fn [e _] (error 400 (pr-str (me/humanize (ex-data e)))))})))

(def app
  (ring/ring-handler
   (ring/router
    routes
    {:data {:coercion malli/coercion ; malli で :parameters を検証・変換
            :muuntaja m/instance     ; JSON <-> Clojure のマップ
            :middleware [parameters/parameters-middleware      ; クエリ文字列 → :query-params
                         muuntaja/format-negotiate-middleware
                         muuntaja/format-response-middleware   ; :body のマップ → JSON
                         exception-middleware
                         muuntaja/format-request-middleware    ; JSON ボディ → :body-params
                         rrc/coerce-request-middleware]}})     ; スキーマで入力チェック
   (ring/create-default-handler)))

(defn -main [& _]
  (let [port (parse-long (or (System/getenv "PORT") "8014"))]
    (println (str "listening on http://127.0.0.1:" port))
    ;; #'app（Var）を渡すと REPL で app を再定義したとき再起動なしで反映される
    (jetty/run-jetty #'app {:host "127.0.0.1" :port port :join? true})))

(comment
  ;; REPL から起動 / 停止（Calva なら Jack-in してからこのフォームを評価）
  (def server (jetty/run-jetty #'app {:host "127.0.0.1" :port 8014 :join? false}))
  (.stop server))
