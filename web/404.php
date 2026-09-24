<?php
require_once __DIR__ . '/inc/lang.php';
http_response_code(404);
$page = '404';
$pageTitle = $LANG === 'zh' ? '页面不存在 — iExif' : 'Page not found — iExif';
require __DIR__ . '/inc/header.php';
?>
<div class="wrap not-found">
  <p class="code">404</p>
  <h1><?= $LANG === 'zh' ? '这个页面不存在' : 'This page doesn’t exist' ?></h1>
  <p><?= $LANG === 'zh' ? '链接可能已失效，或者地址输错了。' : 'The link may be out of date, or the address was mistyped.' ?></p>
  <a class="mail-btn" href="/"><?= $LANG === 'zh' ? '返回首页' : 'Back to home' ?></a>
</div>
<?php require __DIR__ . '/inc/footer.php'; ?>
