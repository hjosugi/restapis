{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoFieldSelectors #-}

-- | サーバーとクライアントで共有する API 定義。
-- Servant ではエンドポイントを「型」で書き、サーバー (serve) もクライアント (client) もこの型から作る。
module Api (UsersAPI, User (..), UserInput (..)) where

import Control.Monad (when)
import Data.Aeson (FromJSON (..), ToJSON, withObject, (.:))
import Data.Text (Text)
import Data.Text qualified as T
import GHC.Generics (Generic, Generically (..))
import Servant.API

-- | ルート定義（上から GET /users, GET /users/{id}, POST /users, PUT /users/{id}, DELETE /users/{id}）。
-- クエリ・パス・ボディの型と、成功時のステータス (Get=200, PostCreated=201, DeleteNoContent=204) も型で表す。
type UsersAPI =
  "users" :> QueryParam "name" Text :> QueryParam "min_age" Int :> Get '[JSON] [User]
    :<|> "users" :> Capture "id" Int :> Get '[JSON] User
    :<|> "users" :> ReqBody '[JSON] UserInput :> PostCreated '[JSON] User
    :<|> "users" :> Capture "id" Int :> ReqBody '[JSON] UserInput :> Put '[JSON] User
    :<|> "users" :> Capture "id" Int :> DeleteNoContent

-- | API で扱うリソース。JSON 変換はフィールド名どおり (Generic から導出)。
data User = User {id :: Int, name :: Text, email :: Text, age :: Int}
  deriving stock (Generic)
  deriving (FromJSON, ToJSON) via Generically User

-- | POST / PUT のリクエストボディ。
data UserInput = UserInput {name :: Text, email :: Text, age :: Int}
  deriving stock (Generic)
  deriving (ToJSON) via Generically UserInput

-- | 入力チェックは JSON のパース時に行う。欠けた項目・型違い（"1" など）・空文字・負の年齢は
-- パース失敗になり、サーバーは 400 を返す。
instance FromJSON UserInput where
  parseJSON = withObject "UserInput" $ \o -> do
    input <- UserInput <$> o .: "name" <*> o .: "email" <*> o .: "age"
    when (T.null input.name) $ fail "name must not be empty"
    when (T.null input.email) $ fail "email must not be empty"
    when (input.age < 0) $ fail "age must be >= 0"
    pure input
