<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Robots Indexing Configuration
    |--------------------------------------------------------------------------
    | Control search engine crawler visibility via <meta name="robots"> tag
    | and 'X-Robots-Tag' HTTP headers.
    */

    'allow_indexing' => env('ROBOTS_ALLOW_INDEXING', true),

    /*
    | Automatically apply noindex, nofollow to admin and private paths.
    */
    'admin_noindex' => env('ROBOTS_ADMIN_NOINDEX', true),

    /*
    | URL patterns that must be hidden from search engines with noindex, nofollow.
    | Admin URLs are omitted from robots.txt to prevent URL exposure and are
    | instead protected via <meta> tags and HTTP headers.
    */
    'noindex_patterns' => [
        'admin*',
        'nova*',
        'backend*',
        'dashboard*',
        'management*',
        'portal*',
        'telescope*',
        'horizon*',
        'login*',
        'register*',
        'password/*',
        'api/*',
    ],

    /*
    | Standard directives for public pages.
    */
    'default_content' => 'index, follow',

    /*
    | Directives for admin, authentication, and private endpoints.
    */
    'noindex_content' => 'noindex, nofollow, noarchive, nosnippet',

    /*
    | Automatically send 'X-Robots-Tag' HTTP response header.
    */
    'send_header' => true,

];

