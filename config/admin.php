<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Admin Panel Credentials
    |--------------------------------------------------------------------------
    |
    | Static administrator credentials loaded from the environment file for
    | accessing the web admin panel. Leave blank in production to fail closed
    | until explicitly configured.
    |
    */

    'username' => (string) env('ADMIN_USERNAME', ''),

    'password' => (string) env('ADMIN_PASSWORD', ''),

    /*
    |--------------------------------------------------------------------------
    | Admin Session Keys
    |--------------------------------------------------------------------------
    */

    'session_key' => 'admin_authenticated',

    'username_session_key' => 'admin_username',

];

