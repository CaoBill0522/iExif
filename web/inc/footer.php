</main>
<footer class="site-footer">
  <div class="inner">
    <div class="f-brand">
      <img src="/assets/img/icon.png" alt="" width="40" height="40">
      <div>
        <strong>iExif</strong>
        <div class="muted small"><?= e(t('updated')) ?>: <?= UPDATED ?></div>
      </div>
    </div>
    <nav class="f-links">
      <a href="/"><?= $LANG === 'zh' ? '首页' : 'Home' ?></a>
      <a href="/support.php"><?= e(t('nav_support')) ?></a>
      <a href="/privacy.php"><?= e(t('nav_privacy')) ?></a>
      <?php if (CONTACT_EMAIL): ?><a href="mailto:<?= e(CONTACT_EMAIL) ?>"><?= e(CONTACT_EMAIL) ?></a><?php endif; ?>
      <a href="<?= APP_STORE_URL ?>" target="_blank" rel="noopener">App Store</a>
    </nav>
    <p class="muted small note"><?= e(t('footer_note')) ?></p>
  </div>
</footer>
<dialog id="screenshot-viewer" aria-label="<?= $LANG === 'zh' ? '截图预览' : 'Screenshot preview' ?>">
<button type="button" class="close-viewer" aria-label="<?= $LANG === 'zh' ? '关闭' : 'Close' ?>">×</button>
<img alt=""><p></p>
</dialog>
<script src="/assets/js/site.js" defer></script>
</body></html>
