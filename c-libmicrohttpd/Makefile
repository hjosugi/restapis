# bin/server と bin/client をビルドする。ライブラリのフラグは pkg-config から取る。
#   make            ビルド
#   bear -- make -B clangd / clang-tidy 用の compile_commands.json も作る（task compdb）

CFLAGS   ?= -g -O0
CFLAGS   += -std=c23 -Wall -Wextra -Wpedantic
CPPFLAGS += -D_GNU_SOURCE # strcasestr を使うため

SERVER_PKGS := libmicrohttpd libcjson
CLIENT_PKGS := libcurl libcjson

all: bin/server bin/client

bin/server: src/server.c | bin
	$(CC) $(CPPFLAGS) $(CFLAGS) -pthread $(shell pkg-config --cflags $(SERVER_PKGS)) \
		$< -o $@ $(LDFLAGS) $(shell pkg-config --libs $(SERVER_PKGS))

bin/client: src/client.c | bin
	$(CC) $(CPPFLAGS) $(CFLAGS) $(shell pkg-config --cflags $(CLIENT_PKGS)) \
		$< -o $@ $(LDFLAGS) $(shell pkg-config --libs $(CLIENT_PKGS))

bin:
	mkdir -p $@

clean:
	rm -rf bin compile_commands.json

.PHONY: all clean
