<?php

declare(strict_types=1);

namespace App\PhpCommon\Tests;

use App\PhpCommon\Greeter;
use PHPUnit\Framework\TestCase;

final class GreeterTest extends TestCase
{
    public function test_greet_with_default(): void
    {
        $greeter = new Greeter;
        $this->assertSame('Hello, World!', $greeter->greet());
    }

    public function test_greet_with_name(): void
    {
        $greeter = new Greeter;
        $this->assertSame('Hello, Laravel!', $greeter->greet('Laravel'));
    }
}
