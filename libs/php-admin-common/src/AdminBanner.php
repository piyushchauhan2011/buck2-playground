<?php

declare(strict_types=1);

namespace App\PhpAdminCommon;

final class AdminBanner
{
    public function getBanner(): string
    {
        return 'Admin Dashboard';
    }
}
