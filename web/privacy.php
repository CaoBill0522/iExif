<?php
require_once __DIR__ . '/inc/lang.php';
$page = 'privacy';
$pageTitle = ($LANG === 'zh' ? 'iExif 隐私政策' : 'iExif Privacy Policy');
require __DIR__ . '/inc/header.php';
?>
<div class="wrap">
  <div class="page-head">
    <h1><?= e(t('privacy_title')) ?></h1>
    <p class="muted small"><?= e(t('updated')) ?>: <?= UPDATED ?></p>
  </div>

  <div class="content">
    <div class="lead-card"><?= e(t('privacy_lead')) ?></div>

    <?php foreach (ta('privacy_sections') as $s): ?>
      <h2><?= e($s[0]) ?></h2>
      <p><?= e($s[1]) ?></p>
    <?php endforeach; ?>

    <h2><?= $LANG === 'zh' ? '联系方式' : 'Contact' ?></h2>
    <p><?php if (CONTACT_EMAIL): ?><?= e(t('privacy_contact')) ?> <a href="mailto:<?= e(CONTACT_EMAIL) ?>"><?= e(CONTACT_EMAIL) ?></a><?php else: ?><a href="/support.php"><?= e(t('nav_support')) ?></a><?php endif; ?></p>
<p><a href="https://www.apple.com/legal/privacy/data/<?= $LANG === 'zh' ? 'zh-cn' : 'en' ?>/apple-maps/" target="_blank" rel="noopener"><?= $LANG === 'zh' ? 'Apple 地图与隐私 ↗' : 'Apple Maps & Privacy ↗' ?></a></p>
  </div>
</div>
<?php require __DIR__ . '/inc/footer.php'; ?>
