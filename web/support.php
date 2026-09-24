<?php
require_once __DIR__ . '/inc/lang.php';
$page = 'support';
$pageTitle = ($LANG === 'zh' ? 'iExif 技术支持' : 'iExif Support');
require __DIR__ . '/inc/header.php';
?>
<div class="wrap">
  <div class="page-head">
    <h1><?= e(t('support_title')) ?></h1>
    <p><?= e(t('support_lead')) ?></p>
  </div>

  <div class="content"><div class="lead-card"><?= $LANG === 'zh' ? '反馈问题时，请提供设备型号、系统版本、App 版本和复现步骤。无需发送私人原图；截图请先遮盖个人信息。' : 'For troubleshooting, include your device, iOS version, app version and steps to reproduce. Please redact personal details and avoid sending private original photos.' ?></div><h2><?= $LANG === 'zh' ? '常见问题' : 'Frequently asked questions' ?></h2>
    <?php foreach (ta('faq') as $i => $qa): ?>
      <details<?= $i === 0 ? ' open' : '' ?>>
        <summary><?= e($qa[0]) ?></summary>
        <p><?= e($qa[1]) ?></p>
      </details>
    <?php endforeach; ?>

    <h2><?= e(t('support_contact_title')) ?></h2>
    <p><?= e(t('support_contact_body')) ?></p>
    <?php if (CONTACT_EMAIL): ?><a class="mail-btn" href="mailto:<?= e(CONTACT_EMAIL) ?>?subject=iExif"><?= e(t('support_mail')) ?></a><p><?= e(CONTACT_EMAIL) ?></p><?php else: ?><p><?= $LANG === 'zh' ? '请通过 App Store 产品页面的开发者联系入口获取帮助。' : 'Please use the developer contact links on the App Store product page for assistance.' ?></p><a class="mail-btn" href="<?= APP_STORE_URL ?>"><?= $LANG === 'zh' ? '打开 App Store 页面' : 'Open App Store page' ?></a><?php endif; ?>

    <h2><?= $LANG === 'zh' ? '关于 App' : 'About the app' ?></h2>
    <p>
      <?= $LANG === 'zh'
        ? 'iExif 需要 iOS 17 或更高版本，支持 iPhone 和 iPad，下载与价格信息以 App Store 页面为准。'
        : 'iExif requires iOS 17 or later, runs on iPhone and iPad, with current availability and pricing listed on the App Store.' ?>
      <a href="<?= APP_STORE_URL ?>" target="_blank" rel="noopener"><?= e(t('download')) ?> →</a>
    </p>
  </div>
</div>
<?php require __DIR__ . '/inc/footer.php'; ?>
