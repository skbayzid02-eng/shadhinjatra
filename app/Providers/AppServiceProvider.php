<?php

namespace App\Providers;

use App\Services\RobotsService;
use Illuminate\Support\Facades\Blade;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        if ($this->app->environment('local') && class_exists(\Laravel\Telescope\TelescopeServiceProvider::class)) {
            $this->app->register(\Laravel\Telescope\TelescopeServiceProvider::class);
            $this->app->register(TelescopeServiceProvider::class);
        }
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Blade::directive('robotsMeta', function () {
            return "<?php echo \App\Services\RobotsService::renderMetaTag(); ?>";
        });

        Blade::directive('robots', function () {
            return "<?php echo \App\Services\RobotsService::renderMetaTag(); ?>";
        });
    }
}
