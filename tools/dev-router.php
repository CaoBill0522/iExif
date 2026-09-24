<?php
/**
 * 本地预览用路由，模拟 web/.htaccess 的规则（PHP 内置服务器不读 .htaccess）。
 * 用法：php -S 127.0.0.1:8098 -t web tools/dev-router.php
 */
$root = realpath(__DIR__ . '/../web');
$path = rawurldecode(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/');

$notFound = static function () use ($root) {
    require $root . '/404.php';
    return true;
};

if (preg_match('#^/inc/|/\.(?!well-known/)|\.(md|log|ini|sh)$#', $path)) return $notFound();
if ($path === '/robots.txt') { require $root . '/robots.php'; return true; }
if ($path === '/sitemap.xml') { require $root . '/sitemap.php'; return true; }

$file = realpath($root . $path);
if ($file === false || !str_starts_with($file, $root)) return $notFound();
if (is_dir($file)) {
    if (is_file($file . '/index.php')) return false;
    return $notFound();
}
return false; // 交给内置服务器处理真实存在的文件
