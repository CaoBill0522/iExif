<?php
require_once __DIR__ . '/lang.php';
$page = $page ?? 'home';
$pageTitle = $pageTitle ?? 'iExif';
?>
<!DOCTYPE html>
<html lang="<?= e(t('locale')) ?>">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= e($pageTitle) ?></title>
<meta name="description" content="<?= e(t('hero_sub')) ?>">
<meta name="theme-color" content="#f7f8fa">
<meta name="apple-itunes-app" content="app-id=6814786080">
<link rel="icon" href="/assets/img/icon.png">
<link rel="apple-touch-icon" href="/assets/img/icon.png">
<link rel="stylesheet" href="/assets/css/style.css?v=8">
<link rel="canonical" href="<?= e(page_url($LANG)) ?>">
<link rel="alternate" hreflang="zh-Hans" href="<?= e(page_url('zh')) ?>">
<link rel="alternate" hreflang="en" href="<?= e(page_url('en')) ?>">
<link rel="alternate" hreflang="x-default" href="<?= e(page_url()) ?>">
<meta property="og:site_name" content="iExif">
<meta property="og:title" content="<?= e($pageTitle) ?>">
<meta property="og:description" content="<?= e(t('hero_sub')) ?>">
<meta property="og:url" content="<?= e(page_url($LANG)) ?>">
<meta property="og:image" content="<?= e(site_url()) ?>/assets/img/og-<?= $LANG ?>.jpg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:locale" content="<?= $LANG === 'zh' ? 'zh_CN' : 'en_US' ?>">
<meta property="og:type" content="website">
<meta name="twitter:card" content="summary_large_image">
<?php if ($page === 'home'): ?>
<script type="application/ld+json">
<?= json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'MobileApplication',
    'name' => 'iExif',
    'operatingSystem' => 'iOS 17.0 or later',
    'applicationCategory' => 'PhotographyApplication',
    'description' => t('hero_sub'),
    'image' => site_url() . '/assets/img/icon@2x.png',
    'url' => site_url() . '/',
    'downloadUrl' => APP_STORE_URL,
    'offers' => ['@type' => 'Offer', 'price' => '0', 'priceCurrency' => 'USD'],
    'inLanguage' => ['en', 'zh-Hans'],
], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) ?>
</script>
<?php endif; ?>
</head>
<body>
<a class="skip" href="#main"><?= $LANG === 'zh' ? '跳到主要内容' : 'Skip to content' ?></a>

<header class="site-header">
  <div class="bar">
    <a class="brand" href="/">
      <img src="/assets/img/icon.png" alt="iExif" width="34" height="34">
      <span>iExif</span>
    </a>
    <nav class="nav" aria-label="<?= $LANG === 'zh' ? '主要导航' : 'Main navigation' ?>">
      <a href="/#features"><?= e(t('nav_features')) ?></a>
      <a href="/#shots"><?= e(t('nav_shots')) ?></a>
      <a href="/support.php"<?= $page === 'support' ? ' class="here" aria-current="page"' : '' ?>><?= e(t('nav_support')) ?></a>
      <a href="/privacy.php"<?= $page === 'privacy' ? ' class="here" aria-current="page"' : '' ?>><?= e(t('nav_privacy')) ?></a>
    </nav>
    <div class="right">
      <div class="langs">
        <?php foreach (LANGS as $code => $label): ?>
          <a href="<?= e(lang_url($code)) ?>" hreflang="<?= $code === 'zh' ? 'zh-Hans' : 'en' ?>" lang="<?= $code === 'zh' ? 'zh-Hans' : 'en' ?>"<?= $LANG === $code ? ' class="on" aria-current="true"' : '' ?>><?= e($label) ?></a>
        <?php endforeach; ?>
      </div>
      <a class="store-mini" href="<?= APP_STORE_URL ?>" target="_blank" rel="noopener"><?= $LANG === 'zh' ? '下载' : 'Download' ?></a>
      <details class="menu">
        <summary aria-label="<?= $LANG === 'zh' ? '菜单' : 'Menu' ?>"><span class="bars" aria-hidden="true"><i></i><i></i><i></i></span></summary>
        <nav class="menu-panel" aria-label="<?= $LANG === 'zh' ? '主要导航' : 'Main navigation' ?>">
          <a href="/#features"><?= e(t('nav_features')) ?></a>
          <a href="/#shots"><?= e(t('nav_shots')) ?></a>
          <a href="/support.php"<?= $page === 'support' ? ' aria-current="page"' : '' ?>><?= e(t('nav_support')) ?></a>
          <a href="/privacy.php"<?= $page === 'privacy' ? ' aria-current="page"' : '' ?>><?= e(t('nav_privacy')) ?></a>
          <a class="menu-store" href="<?= APP_STORE_URL ?>" target="_blank" rel="noopener"><?= $LANG === 'zh' ? '在 App Store 下载' : 'Download on the App Store' ?></a>
        </nav>
      </details>
    </div>
  </div>
</header>
<main id="main">
