<?php

declare(strict_types=1);

namespace App\PhpCommon;

final class Greeter
{
    public function greet(string $name = 'World'): string
    {
        return 'Hello, '.$name.'!';
    }
}
