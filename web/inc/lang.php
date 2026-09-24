<?php
/**
 * 语言处理：?lang=zh|en → Cookie → 浏览器 Accept-Language → 默认英文
 */

const LANGS = ['zh' => '中文', 'en' => 'English'];

function detect_lang(): string
{
    if (isset($_GET['lang']) && is_string($_GET['lang']) && isset(LANGS[$_GET['lang']])) {
        setcookie('lang', $_GET['lang'], ['expires' => time() + 86400 * 365, 'path' => '/', 'httponly' => true, 'samesite' => 'Lax', 'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off']);
        return $_GET['lang'];
    }
    if (isset($_COOKIE['lang']) && is_string($_COOKIE['lang']) && isset(LANGS[$_COOKIE['lang']])) {
        return $_COOKIE['lang'];
    }
    $accept = strtolower($_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? '');
    return str_contains($accept, 'zh') ? 'zh' : 'en';
}

// 显式写入全局作用域：即使本文件在函数内被引入（如本地路由的 404），t() 也能取到文案。
$GLOBALS['LANG'] = detect_lang();
$GLOBALS['T'] = require __DIR__ . '/strings.php';
$LANG = $GLOBALS['LANG'];
$T = $GLOBALS['T'];

/** 取当前语言文案 */
function t(string $key): string
{
    global $T, $LANG;
    return $T[$LANG][$key] ?? $T['en'][$key] ?? $key;
}

/** 取当前语言的数组文案（功能列表、FAQ 等） */
function ta(string $key): array
{
    global $T, $LANG;
    return $T[$LANG][$key] ?? $T['en'][$key] ?? [];
}

/** 当前页面切换语言后的地址 */
function lang_url(string $lang): string
{
    $path = strtok($_SERVER['REQUEST_URI'] ?? '/', '?');
    return $path . '?lang=' . $lang;
}

function e(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}

const APP_STORE_URL = 'https://apps.apple.com/us/app/iexif/id6814786080';
const APP_STORE_ID = '6814786080';

/**
 * 网站正式地址（不带结尾斜杠），用于 canonical、hreflang、分享卡片和 sitemap。
 * 可用环境变量 IEXIF_SITE_URL 设置；未设置时按当前请求的域名推断。
 */
function site_url(): string
{
    $configured = getenv('IEXIF_SITE_URL');
    if ($configured) return rtrim($configured, '/');
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https';
    $host = preg_replace('/[^a-z0-9.:\-\[\]]/i', '', $_SERVER['HTTP_HOST'] ?? 'localhost');
    return ($https ? 'https://' : 'http://') . $host;
}

/** 当前页面在指定语言下的完整地址 */
function page_url(?string $lang = null): string
{
    $path = strtok($_SERVER['REQUEST_URI'] ?? '/', '?') ?: '/';
    $path = str_ends_with($path, '/index.php') ? substr($path, 0, -9) : $path;
    return site_url() . $path . ($lang ? '?lang=' . $lang : '');
}
define('CONTACT_EMAIL', filter_var(getenv('IEXIF_SUPPORT_EMAIL') ?: 'caojiacheng38@gmail.com', FILTER_VALIDATE_EMAIL) ?: '');
const UPDATED = '2026-09-22';

/**
 * 苹果官方 App Store 徽章（assets/img/badge，来自 tools.applemediaservices.com，不得修改图形）。
 * $onDark：放在深色背景上时强制用白色徽章；否则浅色模式黑色、深色模式白色。
 */
function appstore_badge(bool $onDark = false, int $height = 54): string
{
    global $LANG;
    $loc = $LANG === 'zh' ? 'zh-cn' : 'en-us';
    $black = "/assets/img/badge/appstore-$loc-black.svg";
    $white = "/assets/img/badge/appstore-$loc-white.svg";
    $alt = $LANG === 'zh' ? '在 App Store 下载' : 'Download on the App Store';
    $img = '<img src="' . ($onDark ? $white : $black) . '" alt="' . e($alt) . '" height="' . $height . '" width="' . round($height * ($LANG === 'zh' ? 2.721 : 2.992)) . '">';
    $inner = $onDark ? $img : '<picture><source srcset="' . $white . '" media="(prefers-color-scheme: dark)">' . $img . '</picture>';
    return '<a class="appstore-badge" href="' . APP_STORE_URL . '" target="_blank" rel="noopener">' . $inner . '</a>';
}

/**
 * 截图：浅色模式用普通版本，深色模式自动换成 _dark 版本（有的话）。
 * $name 例如 '1_library'；$ipad 为 true 时取 iPad 截图。
 */
function shot_img(string $name, string $alt, bool $ipad = false, string $attrs = ''): string
{
    global $LANG;
    $base = '/assets/img/shots/' . ($ipad ? 'ipad_' : '') . $LANG . '_' . $name;
    $dark = $base . '_dark.jpg';
    [$w, $h] = $ipad ? [1200, 1600] : [560, 1217];
    $img = '<img src="' . $base . '.jpg" alt="' . e($alt) . '" width="' . $w . '" height="' . $h . '" ' . $attrs . '>';
    if (!is_file(__DIR__ . '/..' . $dark)) return $img;
    return '<picture><source srcset="' . $dark . '" media="(prefers-color-scheme: dark)">' . $img . '</picture>';
}
