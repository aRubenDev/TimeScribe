<?php

// tests/Feature/WebRuntimeTest.php

declare(strict_types=1);

use App\Enums\TimestampTypeEnum;
use App\Models\Timestamp;
use App\Native\NullClient;
use App\Providers\AppServiceProvider;
use Illuminate\Support\Facades\Facade;
use Native\Desktop\Client\Client;
use Native\Desktop\Facades\App as NativeApp;

function switchToWebRuntime(): void
{
    config(['app.runtime' => 'web']);
    (new AppServiceProvider(app()))->register();
    Facade::clearResolvedInstances();
}

it('defaults to the desktop runtime', function (): void {
    expect(config('app.runtime'))->toBe('desktop');
});

it('keeps the real NativePHP client in desktop mode', function (): void {
    expect(app(Client::class))->not->toBeInstanceOf(NullClient::class);
});

it('swaps the NativePHP client for the null client in web mode', function (): void {
    switchToWebRuntime();

    expect(app(Client::class))->toBeInstanceOf(NullClient::class);
});

it('answers desktop-only queries with neutral values in web mode', function (): void {
    switchToWebRuntime();

    expect(NativeApp::openAtLogin())->toBeFalse();
});

it('renders the general settings page in web mode', function (): void {
    switchToWebRuntime();

    $this->get(route('settings.general.edit'))->assertOk();
});

it('stops the timer and responds normally in web mode', function (): void {
    switchToWebRuntime();

    Timestamp::create([
        'type' => TimestampTypeEnum::WORK,
        'started_at' => now()->subHour(),
        'last_ping_at' => now(),
        'paid' => false,
    ]);

    $this->post(route('menubar.storeStop'))
        ->assertRedirect(route('menubar.index'));

    expect(Timestamp::whereNull('ended_at')->exists())->toBeFalse();
});