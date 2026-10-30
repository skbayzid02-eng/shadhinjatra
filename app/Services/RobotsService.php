<?php

namespace App\Services;

use App\Models\Setting;
use Illuminate\Http\Request;
use Throwable;

class RobotsService
{
    /**
     * Determine whether the given or current request should be marked as noindex.
     *
     * @param Request|null $request
     * @return bool
     */
    public static function isNoIndexRoute(?Request $request = null): bool
    {
        $request ??= request();

        // 1. Global site indexing setting (e.g. false in staging or dev)
        try {
            $allowIndexing = Setting::get('robots_allow_indexing');
        } catch (Throwable) {
            $allowIndexing = null;
        }

        if ($allowIndexing !== null) {
            $allowIndexing = ($allowIndexing === 'true' || $allowIndexing === true || $allowIndexing === '1');
        } else {
            $allowIndexing = (bool) config('robots.allow_indexing', true);
        }

        if (!$allowIndexing) {
            return true;
        }

        // 2. Admin / private paths noindex configuration
        try {
            $adminNoIndex = Setting::get('robots_admin_noindex');
        } catch (Throwable) {
            $adminNoIndex = null;
        }

        if ($adminNoIndex !== null) {
            $adminNoIndex = ($adminNoIndex === 'true' || $adminNoIndex === true || $adminNoIndex === '1');
        } else {
            $adminNoIndex = (bool) config('robots.admin_noindex', true);
        }

        if (!$adminNoIndex) {
            return false;
        }

        // 3. Match against protected patterns
        $patterns = (array) config('robots.noindex_patterns', [
            'admin*',
            'nova*',
            'backend*',
            'dashboard*',
            'management*',
            'portal*',
            'telescope*',
            'horizon*',
            'login*',
            'api/*',
        ]);

        foreach ($patterns as $pattern) {
            if ($request->is($pattern)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Get the robots meta tag content string for the current request.
     *
     * @param Request|null $request
     * @return string
     */
    public static function getMetaContent(?Request $request = null): string
    {
        if (self::isNoIndexRoute($request)) {
            try {
                $customNoIndex = Setting::get('robots_meta_admin');
            } catch (Throwable) {
                $customNoIndex = null;
            }

            return (string) ($customNoIndex ?: config('robots.noindex_content', 'noindex, nofollow, noarchive, nosnippet'));
        }

        try {
            $customDefault = Setting::get('robots_meta_default');
        } catch (Throwable) {
            $customDefault = null;
        }

        return (string) ($customDefault ?: config('robots.default_content', 'index, follow'));
    }

    /**
     * Render the complete HTML <meta name="robots"> tag.
     *
     * @param Request|null $request
     * @return string
     */
    public static function renderMetaTag(?Request $request = null): string
    {
        $content = e(self::getMetaContent($request));

        return '<meta name="robots" content="' . $content . '">';
    }
}
