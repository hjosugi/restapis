// users リソースの CRUD を提供する REST API サーバー（Gin / インメモリ保存）。
package main

import (
	"cmp"
	"net/http"
	"os"
	"slices"
	"strconv"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"
)

// User は API で扱うリソース。
type User struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
	Age   int    `json:"age"`
}

// UserInput は POST / PUT のリクエストボディ。binding タグで入力チェックする。
type UserInput struct {
	Name  string `binding:"required"       json:"name"`
	Email string `binding:"required"       json:"email"`
	Age   *int   `binding:"required,gte=0" json:"age"` // 0 歳を許すためポインタで「未指定」と区別
}

// Store はメモリ上のユーザー一覧。Gin はリクエストを並行処理するので Mutex で守る。
type Store struct {
	mu     sync.Mutex
	users  map[int]User
	nextID int
}

func NewStore() *Store {
	s := &Store{users: map[int]User{}, nextID: 1}
	s.Create(UserInput{Name: "Alice", Email: "alice@example.com", Age: new(30)})
	s.Create(UserInput{Name: "Bob", Email: "bob@example.com", Age: new(25)})

	return s
}

func (s *Store) List(name string, minAge *int) []User {
	s.mu.Lock()
	defer s.mu.Unlock()

	result := []User{} // nil だと JSON が null になるので空スライスで初期化
	for _, u := range s.users {
		if name != "" && !strings.Contains(strings.ToLower(u.Name), strings.ToLower(name)) {
			continue
		}
		if minAge != nil && u.Age < *minAge {
			continue
		}
		result = append(result, u)
	}
	slices.SortFunc(result, func(a, b User) int { return cmp.Compare(a.ID, b.ID) })

	return result
}

func (s *Store) Get(id int) (User, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	u, ok := s.users[id]

	return u, ok
}

func (s *Store) Create(in UserInput) User {
	s.mu.Lock()
	defer s.mu.Unlock()
	u := User{ID: s.nextID, Name: in.Name, Email: in.Email, Age: *in.Age}
	s.users[u.ID] = u
	s.nextID++

	return u
}

func (s *Store) Update(id int, in UserInput) (User, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.users[id]; !ok {
		return User{}, false
	}
	u := User{ID: id, Name: in.Name, Email: in.Email, Age: *in.Age}
	s.users[id] = u

	return u, true
}

func (s *Store) Delete(id int) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.users[id]; !ok {
		return false
	}
	delete(s.users, id)

	return true
}

func errorJSON(c *gin.Context, status int, msg string) {
	c.JSON(status, gin.H{"error": msg})
}

// pathID は /users/:id の id を取り出す。数値でなければ「見つからない」扱い。
func pathID(c *gin.Context) (int, bool) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		errorJSON(c, http.StatusNotFound, "user not found")

		return 0, false
	}

	return id, true
}

func newRouter(store *Store) *gin.Engine {
	r := gin.Default()

	// GET /users?name=al&min_age=20
	r.GET("/users", func(c *gin.Context) {
		var minAge *int
		if v := c.Query("min_age"); v != "" {
			n, err := strconv.Atoi(v)
			if err != nil {
				errorJSON(c, http.StatusBadRequest, "min_age must be an integer")

				return
			}
			minAge = &n
		}
		c.JSON(http.StatusOK, store.List(c.Query("name"), minAge))
	})

	r.GET("/users/:id", func(c *gin.Context) {
		id, ok := pathID(c)
		if !ok {
			return
		}
		u, found := store.Get(id)
		if !found {
			errorJSON(c, http.StatusNotFound, "user not found")

			return
		}
		c.JSON(http.StatusOK, u)
	})

	r.POST("/users", func(c *gin.Context) {
		var in UserInput
		if err := c.ShouldBindJSON(&in); err != nil {
			errorJSON(c, http.StatusBadRequest, err.Error())

			return
		}
		c.JSON(http.StatusCreated, store.Create(in))
	})

	r.PUT("/users/:id", func(c *gin.Context) {
		id, ok := pathID(c)
		if !ok {
			return
		}
		var in UserInput
		if err := c.ShouldBindJSON(&in); err != nil {
			errorJSON(c, http.StatusBadRequest, err.Error())

			return
		}
		u, found := store.Update(id, in)
		if !found {
			errorJSON(c, http.StatusNotFound, "user not found")

			return
		}
		c.JSON(http.StatusOK, u)
	})

	r.DELETE("/users/:id", func(c *gin.Context) {
		id, ok := pathID(c)
		if !ok {
			return
		}
		if !store.Delete(id) {
			errorJSON(c, http.StatusNotFound, "user not found")

			return
		}
		c.Status(http.StatusNoContent)
	})

	return r
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8003"
	}
	if err := newRouter(NewStore()).Run("127.0.0.1:" + port); err != nil {
		panic(err)
	}
}
