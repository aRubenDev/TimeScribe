<?php

// app/Native/NullClient.php

declare(strict_types=1);

namespace App\Native;

use GuzzleHttp\Psr7\Response as PsrResponse;
use Illuminate\Http\Client\Response;
use Native\Desktop\Client\Client;

/**
 * Replaces NativePHP's HTTP client when TimeScribe runs in web mode.
 *
 * In web mode there is no Electron process to talk to, so every call
 * "succeeds" with an empty JSON body. Only bound when APP_RUNTIME=web
 * (see AppServiceProvider), so the desktop app never uses it.
 */
final class NullClient extends Client
{
    public function __construct()
    {
        // Intentionally not calling parent::__construct():
        // no HTTP client is needed because nothing is sent.
    }

    public function get(string $endpoint, array|string|null $query = null): Response
    {
        return self::emptyResponse();
    }

    public function post(string $endpoint, array $data = []): Response
    {
        return self::emptyResponse();
    }

    public function delete(string $endpoint, array $data = []): Response
    {
        return self::emptyResponse();
    }

    private static function emptyResponse(): Response
    {
        return new Response(new PsrResponse(200, ['Content-Type' => 'application/json'], '{}'));
    }
}