<?php

declare(strict_types=1);

// REST API に CRUD + 検索を一通り投げるクライアント（Guzzle）。

use GuzzleHttp\Client;
use GuzzleHttp\Exception\ConnectException;
use Psr\Http\Message\ResponseInterface;

require __DIR__ . '/vendor/autoload.php';

final readonly class User
{
    public function __construct(
        public int $id,
        public string $name,
        public string $email,
        public int $age,
    ) {}
}

// http_errors => false: 4xx / 5xx でも例外にせず、そのままレスポンスを返す
$client = new Client([
    'base_uri' => getenv('API_URL') ?: 'http://127.0.0.1:8018',
    'http_errors' => false,
]);

/**
 * リクエストを 1 本送り、送った内容と返ってきた内容を表示する。
 *
 * @param array<string, mixed>|null $body
 */
function call(Client $client, string $method, string $path, ?array $body = null): ResponseInterface
{
    $options = [];
    if ($body === null) {
        echo "> {$method} {$path}\n";
    } else {
        echo "> {$method} {$path} " . json_encode($body, JSON_THROW_ON_ERROR) . "\n";
        $options['json'] = $body; // JSON にエンコードし、Content-Type: application/json を付けて送る
    }

    try {
        $response = $client->request($method, $path, $options);
    } catch (ConnectException $e) {
        fwrite(STDERR, "リクエスト失敗（サーバーは起動していますか？）: {$e->getMessage()}\n");
        exit(1);
    }
    echo "< {$response->getStatusCode()} {$response->getBody()}\n\n";

    return $response;
}

echo "--- 1. 一覧取得\n";
call($client, 'GET', '/users');

echo "--- 2. 作成\n";
$response = call($client, 'POST', '/users', ['name' => 'Carol', 'email' => 'carol@example.com', 'age' => 35]);
// JSON を連想配列にデコードし、名前付き引数として User のコンストラクタに渡す
/** @var array{id: int, name: string, email: string, age: int} $data */
$data = json_decode((string) $response->getBody(), true, flags: JSON_THROW_ON_ERROR);
$created = new User(...$data);
$userPath = "/users/{$created->id}";

echo "--- 3. 1件取得\n";
call($client, 'GET', $userPath);

echo "--- 4. 更新\n";
call($client, 'PUT', $userPath, ['name' => 'Carol Smith', 'email' => 'carol@example.com', 'age' => 36]);

echo "--- 5. 検索（名前の部分一致）\n";
call($client, 'GET', '/users?' . http_build_query(['name' => 'car']));

echo "--- 6. 検索（年齢の下限）\n";
call($client, 'GET', '/users?' . http_build_query(['min_age' => 30]));

echo "--- 7. 削除\n";
call($client, 'DELETE', $userPath);

echo "--- 8. 削除されたことを確認（404 になる）\n";
call($client, 'GET', $userPath);
