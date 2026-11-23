// REST API に CRUD + 検索を一通り投げるクライアント（標準ライブラリ net/http のみ）。
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
)

type User struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
	Age   int    `json:"age"`
}

type UserInput struct {
	Name  string `json:"name"`
	Email string `json:"email"`
	Age   int    `json:"age"`
}

var baseURL = func() string {
	if v := os.Getenv("API_URL"); v != "" {
		return v
	}

	return "http://127.0.0.1:8003"
}()

// call はリクエストを 1 本送り、送った内容と返ってきた内容を表示する。
func call(method, path string, body any) []byte {
	var reqBody io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			panic(err)
		}
		reqBody = bytes.NewReader(b)
		fmt.Printf("> %s %s %s\n", method, path, b)
	} else {
		fmt.Printf("> %s %s\n", method, path)
	}

	req, err := http.NewRequest(method, baseURL+path, reqBody)
	if err != nil {
		panic(err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		fmt.Fprintln(os.Stderr, "リクエスト失敗（サーバーは起動していますか？）:", err)
		os.Exit(1)
	}
	data, err := io.ReadAll(res.Body)
	_ = res.Body.Close()
	if err != nil {
		panic(err)
	}
	fmt.Printf("< %d %s\n\n", res.StatusCode, data)

	return data
}

func main() {
	fmt.Println("--- 1. 一覧取得")
	call(http.MethodGet, "/users", nil)

	fmt.Println("--- 2. 作成")
	data := call(http.MethodPost, "/users", UserInput{Name: "Carol", Email: "carol@example.com", Age: 35})
	var created User
	if err := json.Unmarshal(data, &created); err != nil {
		panic(err)
	}
	userPath := fmt.Sprintf("/users/%d", created.ID)

	fmt.Println("--- 3. 1件取得")
	call(http.MethodGet, userPath, nil)

	fmt.Println("--- 4. 更新")
	call(http.MethodPut, userPath, UserInput{Name: "Carol Smith", Email: "carol@example.com", Age: 36})

	fmt.Println("--- 5. 検索（名前の部分一致）")
	call(http.MethodGet, "/users?"+url.Values{"name": {"car"}}.Encode(), nil)

	fmt.Println("--- 6. 検索（年齢の下限）")
	call(http.MethodGet, "/users?"+url.Values{"min_age": {"30"}}.Encode(), nil)

	fmt.Println("--- 7. 削除")
	call(http.MethodDelete, userPath, nil)

	fmt.Println("--- 8. 削除されたことを確認（404 になる）")
	call(http.MethodGet, userPath, nil)
}
