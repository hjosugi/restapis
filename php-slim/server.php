<?php

declare(strict_types=1);

// users リソースの CRUD を提供する REST API サーバー（Slim 4 / インメモリ保存）。
// PHP は普通リクエストごとに状態が消えるので、ReactPHP の HTTP サーバー（1 プロセスのイベントループ）の上で
// Slim アプリを動かし、ユーザー一覧をプロセスのメモリに持ち続ける。

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use React\Http\HttpServer;
use React\Socket\SocketServer;
use Slim\Exception\HttpBadRequestException;
use Slim\Exception\HttpException;
use Slim\Exception\HttpNotFoundException;
use Slim\Factory\AppFactory;
use Slim\Handlers\Strategies\RequestResponseArgs;

require __DIR__ . '/vendor/autoload.php';

// API で扱うリソース。public プロパティがそのまま JSON のキーになる。
final readonly class User
{
    public function __construct(
        public int $id,
        public string $name,
        public string $email,
        public int $age,
    ) {}
}

// POST / PUT のリクエストボディ。
final readonly class UserInput
{
    public function __construct(
        public string $name,
        public string $email,
        public int $age,
    ) {}

    // JSON を検証して UserInput にする。不正なら 400。
    public static function fromRequest(Request $request): self
    {
        try {
            $data = json_decode((string) $request->getBody(), true, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException $e) {
            throw new HttpBadRequestException($request, 'invalid JSON: ' . $e->getMessage());
        }
        if (!is_array($data)) {
            throw new HttpBadRequestException($request, 'body must be a JSON object');
        }

        // json_decode は JSON の型をそのまま PHP の型にするので、文字列 "1" の age は is_int で弾ける
        $name = $data['name'] ?? null;
        $email = $data['email'] ?? null;
        $age = $data['age'] ?? null;
        if (!is_string($name) || $name === '') {
            throw new HttpBadRequestException($request, 'name must be a non-empty string');
        }
        if (!is_string($email) || $email === '') {
            throw new HttpBadRequestException($request, 'email must be a non-empty string');
        }
        if (!is_int($age) || $age < 0) {
            throw new HttpBadRequestException($request, 'age must be an integer >= 0');
        }

        return new self($name, $email, $age);
    }
}

// メモリ上のユーザー一覧。ReactPHP は 1 スレッドのイベントループなのでロック不要。
final class UserStore
{
    /** @var array<int, User> id => User */
    private array $users = [];
    private int $nextId = 1;

    public function __construct()
    {
        $this->create(new UserInput('Alice', 'alice@example.com', 30));
        $this->create(new UserInput('Bob', 'bob@example.com', 25));
    }

    /** @return list<User> */
    public function list(string $name, ?int $minAge): array
    {
        $result = array_filter(
            $this->users,
            fn(User $u): bool => ($name === '' || mb_stripos($u->name, $name) !== false)
                && ($minAge === null || $u->age >= $minAge),
        );
        ksort($result); // id 昇順

        return array_values($result);
    }

    public function get(int $id): ?User
    {
        return $this->users[$id] ?? null;
    }

    public function create(UserInput $in): User
    {
        $user = new User($this->nextId++, $in->name, $in->email, $in->age);
        $this->users[$user->id] = $user;

        return $user;
    }

    public function update(int $id, UserInput $in): ?User
    {
        if (!isset($this->users[$id])) {
            return null;
        }

        return $this->users[$id] = new User($id, $in->name, $in->email, $in->age);
    }

    public function delete(int $id): bool
    {
        if (!isset($this->users[$id])) {
            return false;
        }
        unset($this->users[$id]);

        return true;
    }
}

// $data を JSON にしてレスポンスを作る。
function jsonResponse(Response $response, mixed $data, int $status = 200): Response
{
    $response->getBody()->write(json_encode($data, JSON_THROW_ON_ERROR));

    return $response->withStatus($status)->withHeader('Content-Type', 'application/json');
}

$store = new UserStore();
$app = AppFactory::create();
// ルートのプレースホルダ（{id}）をハンドラの引数（string $id）として受け取る
$app->getRouteCollector()->setDefaultInvocationStrategy(new RequestResponseArgs());

// Slim 既定のエラー（HTML や {"message": ...}）を {"error": ...} + application/json にそろえる。
// ハンドラで投げた HttpBadRequestException (400) / HttpNotFoundException (404) もここで JSON になる。
$errorMiddleware = $app->addErrorMiddleware(displayErrorDetails: false, logErrors: false, logErrorDetails: false);
$errorMiddleware->setDefaultErrorHandler(function (Request $request, Throwable $e) use ($app): Response {
    $response = $app->getResponseFactory()->createResponse();
    if ($e instanceof HttpException) {
        return jsonResponse($response, ['error' => $e->getMessage()], $e->getCode());
    }
    error_log((string) $e);

    return jsonResponse($response, ['error' => 'internal server error'], 500);
});

// GET /users?name=al&min_age=20（両方指定したら AND）
$app->get('/users', function (Request $request, Response $response) use ($store): Response {
    $query = $request->getQueryParams();
    $name = is_string($query['name'] ?? null) ? $query['name'] : '';
    $minAge = null;
    if (($query['min_age'] ?? '') !== '') {
        $minAge = filter_var($query['min_age'], FILTER_VALIDATE_INT);
        if ($minAge === false) {
            throw new HttpBadRequestException($request, 'min_age must be an integer');
        }
    }

    return jsonResponse($response, $store->list($name, $minAge));
});

// {id:[0-9]+} は数字だけにマッチする（/users/abc はどのルートにも当たらず 404）
$app->get('/users/{id:[0-9]+}', function (Request $request, Response $response, string $id) use ($store): Response {
    $user = $store->get((int) $id) ?? throw new HttpNotFoundException($request, 'user not found');

    return jsonResponse($response, $user);
});

$app->post('/users', function (Request $request, Response $response) use ($store): Response {
    $user = $store->create(UserInput::fromRequest($request));

    return jsonResponse($response, $user, 201);
});

$app->put('/users/{id:[0-9]+}', function (Request $request, Response $response, string $id) use ($store): Response {
    $user = $store->update((int) $id, UserInput::fromRequest($request))
        ?? throw new HttpNotFoundException($request, 'user not found');

    return jsonResponse($response, $user);
});

$app->delete('/users/{id:[0-9]+}', function (Request $request, Response $response, string $id) use ($store): Response {
    if (!$store->delete((int) $id)) {
        throw new HttpNotFoundException($request, 'user not found');
    }

    return $response->withStatus(204); // ボディなし
});

// ReactPHP の HTTP サーバーに Slim アプリ（PSR-15 のリクエストハンドラ）を渡して待ち受ける
$port = getenv('PORT') ?: '8018';
$http = new HttpServer($app->handle(...));
$http->listen(new SocketServer("127.0.0.1:{$port}"));
echo "Listening on http://127.0.0.1:{$port}\n";
