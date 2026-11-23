{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

-- | REST API に CRUD + 検索を一通り投げるクライアント（servant-client）。
-- HTTP の組み立ては書かず、サーバーと同じ API 型 (Api.UsersAPI) から関数を導出して呼ぶ。
module Main (main) where

import Api (User (..), UserInput (..), UsersAPI)
import Control.Monad.Error.Class (catchError, throwError)
import Control.Monad.IO.Class (liftIO)
import Data.ByteString.Builder (toLazyByteString)
import Data.ByteString.Lazy.Char8 qualified as BLC
import Data.Foldable (toList)
import Data.Maybe (fromMaybe)
import Data.Proxy (Proxy (..))
import Data.Text (Text)
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Network.HTTP.Types (renderQuery, statusCode)
import Servant.API (NoContent, (:<|>) (..))
import Servant.Client
import Servant.Client.Core (Request, RequestBody (..), RequestF (..))
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.IO (BufferMode (..), hPutStrLn, hSetBuffering, hSetEncoding, stderr, stdout, utf8)

-- | API 型からクライアント関数を導出する（並びは UsersAPI の :<|> と同じ）。
-- QueryParam は Maybe、Capture / ReqBody は引数、レスポンスは FromJSON でデコードされた値になる。
listUsers :: Maybe Text -> Maybe Int -> ClientM [User]
getUser :: Int -> ClientM User
createUser :: UserInput -> ClientM User
updateUser :: Int -> UserInput -> ClientM User
deleteUser :: Int -> ClientM NoContent
listUsers :<|> getUser :<|> createUser :<|> updateUser :<|> deleteUser = client (Proxy @UsersAPI)

-- | 送ったリクエストと受け取ったレスポンスを表示する servant-client のミドルウェア (ClientEnv の middleware)。
-- 2xx 以外は ClientError の FailureResponse になるので、そこから status とボディを取り出して表示する。
logExchange :: (Request -> ClientM Response) -> Request -> ClientM Response
logExchange send req = do
  let path =
        toLazyByteString req.requestPath
          <> BLC.fromStrict (renderQuery True (toList req.requestQueryString))
      body = case req.requestBody of
        Just (RequestBodyLBS b, _) -> " " <> b
        _ -> ""
  liftIO $ BLC.putStrLn ("> " <> BLC.fromStrict req.requestMethod <> " " <> path <> body)
  res <-
    send req `catchError` \err -> do
      case err of
        FailureResponse _ failed -> printResponse failed
        _ -> pure ()
      throwError err
  printResponse res
  pure res
  where
    printResponse res = liftIO $ do
      let status = BLC.pack (show (statusCode res.responseStatusCode))
      BLC.putStrLn ("< " <> status <> " " <> res.responseBody <> "\n")

main :: IO ()
main = do
  -- ロケールに関係なく UTF-8 で出力し、パイプ先でも 1 行ずつ出す
  mapM_ (`hSetEncoding` utf8) [stdout, stderr]
  hSetBuffering stdout LineBuffering
  url <- fromMaybe "http://127.0.0.1:8005" <$> lookupEnv "API_URL"
  manager <- newManager defaultManagerSettings
  base <- parseBaseUrl url
  let env = (mkClientEnv manager base) {middleware = logExchange}
      -- ClientM を実行する。4xx は表示済みなので Nothing、接続できなければ終了。
      run :: ClientM a -> IO (Maybe a)
      run action =
        runClientM action env >>= \case
          Right a -> pure (Just a)
          Left (FailureResponse _ _) -> pure Nothing
          Left err -> do
            hPutStrLn stderr ("リクエスト失敗（サーバーは起動していますか？）: " <> show err)
            exitFailure

  putStrLn "--- 1. 一覧取得"
  _ <- run (listUsers Nothing Nothing)

  putStrLn "--- 2. 作成"
  -- 戻り値はレスポンスの JSON をデコードした User。id はそこから取り出す
  Just created <- run (createUser UserInput {name = "Carol", email = "carol@example.com", age = 35})

  putStrLn "--- 3. 1件取得"
  _ <- run (getUser created.id)

  putStrLn "--- 4. 更新"
  let carolSmith = UserInput {name = "Carol Smith", email = "carol@example.com", age = 36}
  _ <- run (updateUser created.id carolSmith)

  putStrLn "--- 5. 検索（名前の部分一致）"
  _ <- run (listUsers (Just "car") Nothing)

  putStrLn "--- 6. 検索（年齢の下限）"
  _ <- run (listUsers Nothing (Just 30))

  putStrLn "--- 7. 削除"
  _ <- run (deleteUser created.id)

  putStrLn "--- 8. 削除されたことを確認（404 になる）"
  _ <- run (getUser created.id)
  pure ()
