/// REST API に CRUD + 検索を一通り投げるクライアント（HttpClient + System.Net.Http.Json）。
module Client.Program

open System
open System.Net.Http
open System.Net.Http.Json

type User = { Id: int; Name: string; Email: string; Age: int }

type UserInput = { Name: string; Email: string; Age: int }

let baseUrl =
    match Environment.GetEnvironmentVariable "API_URL" with
    | null
    | "" -> "http://127.0.0.1:8010"
    | url -> url

let http = new HttpClient()

/// リクエストを 1 本送り、送った内容と返ってきた内容を表示する。
let call (method: HttpMethod) (path: string) (body: UserInput option) =
    task {
        use request = new HttpRequestMessage(method, baseUrl + path)

        match body with
        | Some input ->
            // JsonContent は camelCase の JSON に変換して Content-Type: application/json を付ける
            request.Content <- JsonContent.Create input
            let! sent = request.Content.ReadAsStringAsync()
            printfn $"> {method} {path} {sent}"
        | None -> printfn $"> {method} {path}"

        let! response = http.SendAsync request
        let! received = response.Content.ReadAsStringAsync()
        printfn $"< {int response.StatusCode} {received}\n"
        return response
    }

let run () =
    task {
        printfn "--- 1. 一覧取得"
        let! _ = call HttpMethod.Get "/users" None

        printfn "--- 2. 作成"
        let! response = call HttpMethod.Post "/users" (Some { Name = "Carol"; Email = "carol@example.com"; Age = 35 })

        // レスポンスの JSON を User レコードに変換して id を取り出す
        let! created = response.Content.ReadFromJsonAsync<User>()
        let userPath = $"/users/{created.Id}"

        printfn "--- 3. 1件取得"
        let! _ = call HttpMethod.Get userPath None

        printfn "--- 4. 更新"
        let! _ = call HttpMethod.Put userPath (Some { Name = "Carol Smith"; Email = "carol@example.com"; Age = 36 })

        printfn "--- 5. 検索（名前の部分一致）"
        // クエリパラメータの値は URL エンコードしてから付ける
        let! _ = call HttpMethod.Get ("/users?name=" + Uri.EscapeDataString "car") None

        printfn "--- 6. 検索（年齢の下限）"
        let! _ = call HttpMethod.Get "/users?min_age=30" None

        printfn "--- 7. 削除"
        let! _ = call HttpMethod.Delete userPath None

        printfn "--- 8. 削除されたことを確認（404 になる）"
        let! _ = call HttpMethod.Get userPath None
        return ()
    }

[<EntryPoint>]
let main _ =
    try
        run().GetAwaiter().GetResult()
        0
    with :? HttpRequestException as ex ->
        eprintfn $"リクエスト失敗（サーバーは起動していますか？）: {ex.Message}"
        1
