<?php

namespace Tests\Feature;

use Tests\TestCase;

final class HealthRouteTest extends TestCase
{
    public function test_health_returns_ok(): void
    {
        $response = $this->get('/health');

        $response->assertStatus(200);
        $response->assertJson(['status' => 'ok', 'message' => 'Hello, API!']);
    }
}
