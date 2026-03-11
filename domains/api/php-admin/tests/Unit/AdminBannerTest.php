<?php

namespace Tests\Unit;

use App\PhpAdminCommon\AdminBanner;
use PHPUnit\Framework\TestCase;

final class AdminBannerTest extends TestCase
{
    public function test_admin_banner_from_php_admin_common(): void
    {
        $banner = new AdminBanner;
        $this->assertSame('Admin Dashboard', $banner->getBanner());
    }
}
