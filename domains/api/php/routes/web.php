<?php

use App\PhpCommon\Greeter;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/greet/{name?}', function (?string $name = null) {
    $greeter = new Greeter;

    return response()->json(['message' => $greeter->greet($name ?? 'World')]);
});
