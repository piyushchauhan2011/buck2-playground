<?php

namespace Tests\Feature;

use Tests\TestCase;

final class FarewellRouteTest extends TestCase
{
    public function test_farewell_returns_ok(): void
    {
        $response = $this->get('/farewell');

        $response->assertStatus(200);
        $response->assertJson(['status' => 'ok', 'message' => 'Goodbye, Admin!']);
    }
}
