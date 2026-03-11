<?php

use App\PhpAdminCommon\AdminBanner;
use App\PhpCommon\Greeter;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/health', function () {
    $greeter = new Greeter;

    return response()->json(['status' => 'ok', 'message' => $greeter->greet('Admin')]);
});

Route::get('/banner', function () {
    $banner = new AdminBanner;

    return response()->json(['status' => 'ok', 'banner' => $banner->getBanner()]);
});
