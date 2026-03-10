<?php

namespace Tests\Feature;

use Tests\TestCase;

final class GreeterRouteTest extends TestCase
{
    public function test_greet_with_default_returns_hello_world(): void
    {
        $response = $this->get('/greet');

        $response->assertStatus(200);
        $response->assertJson(['message' => 'Hello, World!']);
    }

    public function test_greet_with_name_returns_hello_name(): void
    {
        $response = $this->get('/greet/Laravel');

        $response->assertStatus(200);
        $response->assertJson(['message' => 'Hello, Laravel!']);
    }
}
