<?php

namespace Tests\Feature;

use Tests\TestCase;

class StorageSecurityTest extends TestCase
{
    /**
     * Test that .htaccess file exists in both storage/app/public and public/storage.
     */
    public function test_storage_htaccess_exists_and_blocks_scripts(): void
    {
        $storageHtaccess = storage_path('app/public/.htaccess');
        $publicStorageHtaccess = public_path('storage/.htaccess');

        $this->assertFileExists($storageHtaccess, 'storage/app/public/.htaccess must exist.');
        $this->assertFileExists($publicStorageHtaccess, 'public/storage/.htaccess must exist via symlink.');

        $content = file_get_contents($storageHtaccess);

        // Assert critical script extensions are blocked
        $this->assertStringContainsString('php', $content);
        $this->assertStringContainsString('html', $content);
        $this->assertStringContainsString('htm', $content);
        $this->assertStringContainsString('js', $content);
        $this->assertStringContainsString('Options -ExecCGI -Indexes', $content);
        $this->assertStringContainsString('Require all denied', $content);
        $this->assertStringContainsString('X-Content-Type-Options "nosniff"', $content);
    }

    /**
     * Test that public/.htaccess contains perimeter rule blocking scripts in storage.
     */
    public function test_public_htaccess_contains_storage_perimeter_rule(): void
    {
        $publicHtaccess = public_path('.htaccess');
        $this->assertFileExists($publicHtaccess);

        $content = file_get_contents($publicHtaccess);

        $this->assertStringContainsString('RewriteCond %{REQUEST_URI} ^/storage/.*\.(php[0-9]?|phtml|phar|phps|pht|html?|js|cgi|pl|py|sh|bash|exe|bat|cmd|asp[x]?|jsp|vbs)$ [NC]', $content);
        $this->assertStringContainsString('RewriteRule .* - [F,L]', $content);
    }

    /**
     * Test that storage/app/public/.gitignore preserves .htaccess for version control.
     */
    public function test_storage_gitignore_whitelists_htaccess(): void
    {
        $gitignore = storage_path('app/public/.gitignore');
        $this->assertFileExists($gitignore);

        $content = file_get_contents($gitignore);
        $this->assertStringContainsString('!.htaccess', $content);
    }
}

