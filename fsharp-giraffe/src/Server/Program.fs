/// users リソースの CRUD を提供する REST API サーバー（Giraffe / インメモリ保存）。
module Server.Program

open System
open System.Text.Json
open Microsoft.AspNetCore.Builder
open Microsoft.Extensions.DependencyInjection
open Microsoft.Extensions.Logging
open Giraffe

/// API で扱うリソース。
type User = { Id: int; Name: string; Email: string; Age: int }

/// POST / PUT のリクエストボディ。
type UserInput = { Name: string; Email: string; Age: int }

/// メモリ上のユーザー一覧。Kestrel はリクエストを並行処理するので lock で守る。
type Store() =
    let gate = obj ()

    // 起動時のデータ。Map はキー（id）順に並ぶ
    let mutable users =
        Map [
            1, { Id = 1; Name = "Alice"; Email = "alice@example.com"; Age = 30 }
            2, { Id = 2; Name = "Bob"; Email = "bob@example.com"; Age = 25 }
        ]

    let mutable nextId = 3

    member _.List(name: string option, minAge: int option) =
        lock gate (fun () ->
            users.Values
            |> Seq.filter (fun u ->
                name
                |> Option.forall (fun n -> u.Name.Contains(n, StringComparison.OrdinalIgnoreCase)))
            |> Seq.filter (fun u -> minAge |> Option.forall (fun m -> u.Age >= m))
            |> List.ofSeq)

    member _.Get(id: int) = lock gate (fun () -> users.TryFind id)

    member _.Create(input: UserInput) =
        lock gate (fun () ->
            let user = { Id = nextId; Name = input.Name; Email = input.Email; Age = input.Age }

            users <- users.Add(user.Id, user)
            nextId <- nextId + 1
            user)

    member _.Update(id: int, input: UserInput) =
        lock gate (fun () ->
            if users.ContainsKey id then
                let user = { Id = id; Name = input.Name; Email = input.Email; Age = input.Age }

                users <- users.Add(id, user)
                Some user
            else
                None)

    member _.Delete(id: int) =
        lock gate (fun () ->
            let found = users.ContainsKey id
            users <- users.Remove id
            found)

/// エラーは {"error": "..."} の JSON で返す。
let errorJson (status: int) (message: string) : HttpHandler =
    setStatusCode status >=> json {| error = message |}

let notFound = errorJson 404 "user not found"

/// 入力チェック。欠けた項目・型違いは JSON の変換時点で弾かれる。
let validate (input: UserInput) =
    if isNull (box input) then // ボディが JSON の null
        Error "body must be a JSON object"
    elif String.IsNullOrEmpty input.Name then
        Error "name is required"
    elif String.IsNullOrEmpty input.Email then
        Error "email is required"
    elif input.Age < 0 then
        Error "age must be >= 0"
    else
        Ok input

/// リクエストボディを UserInput に変換・チェックしてから handler に渡す。失敗したら 400。
let withInput (handler: UserInput -> HttpHandler) : HttpHandler =
    fun next ctx ->
        task {
            try
                let! input = ctx.BindJsonAsync<UserInput>()

                match validate input with
                | Ok input -> return! handler input next ctx
                | Error message -> return! errorJson 400 message next ctx
            with :? JsonException as ex ->
                // 壊れた JSON・型違い（"age": "1" など）・欠けた項目
                return! errorJson 400 ex.Message next ctx
        }

let webApp (store: Store) : HttpHandler =
    // GET /users?name=al&min_age=20。Int32.TryParse は (成功したか, 値) のタプルを返す
    let listUsers: HttpHandler =
        fun next ctx ->
            let name = ctx.TryGetQueryStringValue "name"

            match ctx.TryGetQueryStringValue "min_age" |> Option.map Int32.TryParse with
            | Some(false, _) -> errorJson 400 "min_age must be an integer" next ctx
            | minAge -> json (store.List(name, Option.map snd minAge)) next ctx

    let getUser id =
        match store.Get id with
        | Some user -> json user
        | None -> notFound

    let createUser input =
        setStatusCode 201 >=> json (store.Create input) // 201 Created

    let updateUser id input =
        match store.Update(id, input) with
        | Some user -> json user
        | None -> notFound

    let deleteUser id =
        if store.Delete id then Successful.NO_CONTENT else notFound // 204 はボディなし

    // ルート定義。%i は int のパスパラメータ（/users/abc はどれにも一致せず最後の 404 になる）
    choose [
        GET >=> route "/users" >=> listUsers
        GET >=> routef "/users/%i" getUser
        POST >=> route "/users" >=> withInput createUser
        PUT >=> routef "/users/%i" (fun id -> withInput (updateUser id))
        DELETE >=> routef "/users/%i" deleteUser
        errorJson 404 "not found"
    ]

/// 想定外の例外も JSON で返す。
let errorHandler (ex: exn) (logger: ILogger) =
    logger.LogError(ex, "unhandled exception")
    clearResponse >=> errorJson 500 ex.Message

[<EntryPoint>]
let main args =
    let port =
        match Environment.GetEnvironmentVariable "PORT" with
        | null
        | "" -> "8010"
        | p -> p

    let builder = WebApplication.CreateBuilder args
    builder.Services.AddGiraffe() |> ignore

    // JSON 変換は System.Text.Json。camelCase にし、欠けた項目（コンストラクタ引数）はエラーにする
    let jsonOptions =
        JsonSerializerOptions(
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            RespectRequiredConstructorParameters = true
        )

    builder.Services.AddSingleton<Json.ISerializer>(Json.Serializer jsonOptions)
    |> ignore

    let app = builder.Build()
    app.UseGiraffeErrorHandler(errorHandler).UseGiraffe(webApp (Store()))
    app.Run $"http://127.0.0.1:{port}"
    0
