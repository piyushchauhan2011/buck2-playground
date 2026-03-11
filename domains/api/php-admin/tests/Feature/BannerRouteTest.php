<?php

namespace Tests\Feature;

use Tests\TestCase;

final class BannerRouteTest extends TestCase
{
    public function test_banner_returns_ok(): void
    {
        $response = $this->get('/banner');

        $response->assertStatus(200);
        $response->assertJson(['status' => 'ok', 'banner' => 'Admin Dashboard']);
    }
}
