<?php

namespace Tests\Unit;

use App\PhpCommon\Greeter;
use PHPUnit\Framework\TestCase;

final class GreeterTest extends TestCase
{
    public function test_greeter_from_php_common_works(): void
    {
        $greeter = new Greeter;
        $this->assertSame('Hello, Admin!', $greeter->greet('Admin'));
        $this->assertSame('Goodbye, Admin!', $greeter->farewell('Admin'));
    }
}
