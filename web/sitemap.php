<?php
// 由 /sitemap.xml 重写而来（见 .htaccess）。每个页面列出中英两个语言版本。
require_once __DIR__ . '/inc/lang.php';
header('Content-Type: application/xml; charset=utf-8');

$base = site_url();
$pages = ['/', '/support.php', '/privacy.php'];

echo '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">' . "\n";
foreach ($pages as $path) {
    foreach (['zh' => 'zh-Hans', 'en' => 'en'] as $lang => $hreflang) {
        echo "  <url>\n";
        echo '    <loc>' . e($base . $path . '?lang=' . $lang) . "</loc>\n";
        echo '    <lastmod>' . UPDATED . "</lastmod>\n";
        echo '    <xhtml:link rel="alternate" hreflang="zh-Hans" href="' . e($base . $path . '?lang=zh') . '"/>' . "\n";
        echo '    <xhtml:link rel="alternate" hreflang="en" href="' . e($base . $path . '?lang=en') . '"/>' . "\n";
        echo "  </url>\n";
    }
}
echo "</urlset>\n";
