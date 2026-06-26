<?php
declare(strict_types=1);

// Per-request PHP code-coverage recorder, wired in as php.ini auto_prepend_file
// (see Dockerfile coverage.ini). For every REDCap page request it records line
// coverage of the executing script and writes a unique .cov file into
// /tmp/path/coverage. CI later merges those with phpcov.phar into a clover report.
//
// HARD RULE: this must never break REDCap. Every failure path is a silent no-op —
// missing driver, missing autoload, or any exception leaves the request untouched.

use SebastianBergmann\CodeCoverage\Filter;
use SebastianBergmann\CodeCoverage\Driver\Selector;
use SebastianBergmann\CodeCoverage\CodeCoverage;
use SebastianBergmann\CodeCoverage\Report\PHP as PhpReport;

// Only instrument real web requests served by Apache/mod_php.
if (strpos(php_sapi_name(), 'apache') !== 0) {
    return;
}

// php-code-coverage lives in UnitTests/vendor (the main redcap vendor/ does not
// ship it). Bail quietly if the version env or that autoload isn't present so a
// missing dependency can never fatal every page.
$redcap_version = getenv('REDCAP_VERSION');
if (!$redcap_version) {
    return;
}
$autoload = '/var/www/html/redcap_v' . $redcap_version . '/UnitTests/vendor/autoload.php';
if (!is_file($autoload)) {
    return;
}
require_once $autoload;

try {
    $filename = $_SERVER['SCRIPT_FILENAME'] ?? '';
    if ($filename === '') {
        return;
    }

    $filter = new Filter;
    $filter->includeFile($filename);

    // Selector picks pcov/xdebug automatically; throws if no driver is loaded.
    $coverage = new CodeCoverage((new Selector)->forLineCoverage($filter), $filter);
    $coverage->start($_SERVER['REQUEST_URI'] ?? $filename);

    register_shutdown_function(static function () use ($coverage) {
        try {
            $coverage->stop();
            (new PhpReport)->process(
                $coverage,
                '/tmp/path/coverage/' . bin2hex(random_bytes(16)) . '.cov'
            );
        } catch (\Throwable $e) {
            // Swallow — coverage output must not affect the response.
        }
    });
} catch (\Throwable $e) {
    // No coverage driver, or any other issue: run the request uninstrumented.
}
