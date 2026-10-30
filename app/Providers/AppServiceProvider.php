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
        //
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
