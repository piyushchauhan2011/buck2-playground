<?php

declare(strict_types=1);

namespace App\PhpAdminCommon\Tests;

use App\PhpAdminCommon\AdminBanner;
use PHPUnit\Framework\TestCase;

final class AdminBannerTest extends TestCase
{
    public function test_get_banner(): void
    {
        $banner = new AdminBanner;
        $this->assertSame('Admin Dashboard', $banner->getBanner());
    }
}
