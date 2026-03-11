<?php

use App\PhpCommon\Greeter;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/health', function () {
    $greeter = new Greeter;

    return response()->json(['status' => 'ok', 'message' => $greeter->greet('API')]);
});

Route::get('/greet/{name?}', function (?string $name = null) {
    $greeter = new Greeter;

    return response()->json(['message' => $greeter->greet($name ?? 'World')]);
});
