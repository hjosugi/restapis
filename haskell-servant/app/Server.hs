{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

-- | users リソースの CRUD を提供する REST API サーバー（Servant + warp / インメモリ保存）。
module Main (main) where

import Api (User (..), UserInput (..), UsersAPI)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode, object, (.=))
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Network.HTTP.Types (hContentType)
import Network.Wai.Handler.Warp (defaultSettings, runSettings, setHost, setPort)
import Servant
import System.Environment (lookupEnv)
import System.IO (hPutStrLn, stderr)

-- | メモリ上のユーザー一覧と次に振る id。warp はリクエストを並行処理するので
-- IORef を atomicModifyIORef' で更新する（読み書きが 1 回でアトミック）。
data Store = Store {users :: Map Int User, nextId :: Int}

initialStore :: Store
initialStore =
  Store
    { users = Map.fromList [(u.id, u) | u <- seed]
    , nextId = 3
    }
  where
    seed = [User 1 "Alice" "alice@example.com" 30, User 2 "Bob" "bob@example.com" 25]

-- | エラーを {"error": "..."} + Content-Type: application/json にする。
jsonError :: ServerError -> String -> ServerError
jsonError err msg =
  err
    { errBody = encode (object ["error" .= msg])
    , errHeaders = [(hContentType, "application/json")]
    }

notFound :: ServerError
notFound = jsonError err404 "user not found"

-- | Servant 既定のエラー（プレーンテキスト）を JSON に揃える。
-- ボディの JSON が壊れている / FromJSON が失敗 → 400、クエリやパスの型が違う (min_age=abc, /users/abc) → 400。
errorFormatters :: ErrorFormatters
errorFormatters =
  defaultErrorFormatters
    { bodyParserErrorFormatter = \_ _ msg -> jsonError err400 msg
    , urlParseErrorFormatter = \_ _ msg -> jsonError err400 msg
    , notFoundErrorFormatter = \_ -> jsonError err404 "not found"
    }

-- | ハンドラを UsersAPI の :<|> と同じ順に並べる（引数・戻り値の型が API 型と合わないとコンパイルエラー）。
server :: IORef Store -> Server UsersAPI
server ref = listUsers :<|> getUser :<|> createUser :<|> updateUser :<|> deleteUser
  where
    -- GET /users?name=al&min_age=20（QueryParam は指定がなければ Nothing。両方あれば AND）
    listUsers :: Maybe Text -> Maybe Int -> Handler [User]
    listUsers name minAge = do
      store <- liftIO (readIORef ref)
      let matchName u = maybe True (\n -> T.toCaseFold n `T.isInfixOf` T.toCaseFold u.name) name
          matchAge u = maybe True (u.age >=) minAge
      -- Map.elems は id 昇順で返る
      pure [u | u <- Map.elems store.users, matchName u, matchAge u]

    getUser :: Int -> Handler User
    getUser uid = do
      store <- liftIO (readIORef ref)
      maybe (throwError notFound) pure (Map.lookup uid store.users)

    -- ReqBody はハンドラに来る前に FromJSON UserInput でパース・チェック済み
    createUser :: UserInput -> Handler User
    createUser input = liftIO $ atomicModifyIORef' ref $ \s ->
      let u = toUser s.nextId input
       in (s {users = Map.insert u.id u s.users, nextId = s.nextId + 1}, u)

    updateUser :: Int -> UserInput -> Handler User
    updateUser uid input = do
      let u = toUser uid input
      found <- liftIO $ atomicModifyIORef' ref $ \s ->
        if Map.member uid s.users then (s {users = Map.insert uid u s.users}, True) else (s, False)
      if found then pure u else throwError notFound

    -- 戻り値の NoContent が 204（ボディなし）になる
    deleteUser :: Int -> Handler NoContent
    deleteUser uid = do
      found <- liftIO $ atomicModifyIORef' ref $ \s ->
        (s {users = Map.delete uid s.users}, Map.member uid s.users)
      if found then pure NoContent else throwError notFound

    toUser uid input = User {id = uid, name = input.name, email = input.email, age = input.age}

main :: IO ()
main = do
  port <- maybe 8005 read <$> lookupEnv "PORT"
  ref <- newIORef initialStore
  hPutStrLn stderr ("listening on http://127.0.0.1:" <> show port)
  -- serveWithContext: API 型 + Context（エラー整形）+ ハンドラから WAI アプリを作り、warp で動かす
  runSettings (setHost "127.0.0.1" (setPort port defaultSettings)) $
    serveWithContext (Proxy @UsersAPI) (errorFormatters :. EmptyContext) (server ref)
