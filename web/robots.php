<?php
// 由 /robots.txt 重写而来（见 .htaccess），这样 sitemap 地址能跟随实际域名。
require_once __DIR__ . '/inc/lang.php';
header('Content-Type: text/plain; charset=utf-8');
echo "User-agent: *\n";
echo "Disallow: /inc/\n\n";
echo 'Sitemap: ' . site_url() . "/sitemap.xml\n";
