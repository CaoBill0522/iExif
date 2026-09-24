<?php
require_once __DIR__ . '/inc/lang.php';
$page = 'home';
$pageTitle = $LANG === 'zh' ? 'iExif — 修改照片的拍摄信息' : 'iExif — Edit your photo’s capture info';
require __DIR__ . '/inc/header.php';

/** 功能图标（线性 SVG） */
function icon(string $name): string
{
    $paths = [
        'device' => '<rect x="5" y="2" width="14" height="20" rx="3"/><circle cx="12" cy="13" r="3.2"/><path d="M9.5 6h5"/>',
        'shield' => '<path d="M12 3l7 3v5.5c0 4.3-2.9 8.2-7 9.5-4.1-1.3-7-5.2-7-9.5V6z"/><path d="M9 12.2l2.2 2.2L15.5 10"/>',
        'live'   => '<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="7.5" stroke-dasharray="2.5 3"/><path d="M12 2.5v1.2M12 20.3v1.2M2.5 12h1.2M20.3 12h1.2"/>',
        'map'    => '<path d="M9 3L3.8 5.2v15L9 18l6 3 5.2-2.2v-15L15 6z"/><path d="M9 3v15M15 6v15"/>',
        'batch'  => '<rect x="3" y="7" width="12" height="12" rx="2.5"/><path d="M7.5 4h11A2.5 2.5 0 0 1 21 6.5v11"/><path d="M6.6 13.4l2.2 2.2 3.6-4"/>',
        'lock'   => '<rect x="4.5" y="10.5" width="15" height="10.5" rx="3"/><path d="M8 10.5V7.8a4 4 0 0 1 8 0v2.7"/><circle cx="12" cy="15.6" r="1.4"/>',
    ];
    return '<svg viewBox="0 0 24 24" aria-hidden="true">' . ($paths[$name] ?? '') . '</svg>';
}

?>

<section class="hero">
  <div class="hero-inner">
    <div>
      <p class="eyebrow">PHOTO METADATA, REIMAGINED</p>
      <img class="hero-icon" src="/assets/img/icon@2x.png" alt="iExif" width="84" height="84">
      <h1><?php if ($LANG === 'zh'): ?>照片的拍摄信息，<br>随你修改。<?php else: ?><?= e(t('hero_title')) ?><?php endif; ?></h1>
      <p class="lead"><?= e(t('hero_sub')) ?></p>
      <div class="chips">
        <?php foreach (ta('hero_badges') as $b): ?><span class="chip"><?= e($b) ?></span><?php endforeach; ?>
      </div>
      <div class="hero-actions"><?= appstore_badge() ?><a class="text-link" href="#shots"><?= $LANG === 'zh' ? '看看实际界面 ↓' : 'See it in action ↓' ?></a></div>
    </div>
    <div class="hero-shot"><div class="orbit-note"><span>EXIF</span><strong><?= $LANG === 'zh' ? '每个细节，由你定义。' : 'Every detail. Yours.' ?></strong></div>
      <div class="phone"><?= shot_img('1_library', $LANG === 'zh' ? 'iExif 图库界面' : 'iExif library screen', false, 'loading="eager" fetchpriority="high"') ?></div>
    </div>
  </div>
</section>

<div class="spec-strip"><span>iOS 17+</span><span>iPhone & iPad</span><span>JPEG · HEIC · PNG</span><span><?= $LANG === 'zh' ? '照片本机处理' : 'On-device editing' ?></span></div>
<section id="features">
  <div class="wrap">
    <div class="section-head reveal">
      <h2><?= e(t('features_title')) ?></h2>
      <p><?= e(t('features_sub')) ?></p>
    </div>
    <div class="grid f3">
      <?php foreach (ta('features') as $f): ?>
        <article class="card reveal">
          <div class="ic"><?= icon($f[0]) ?></div>
          <h3><?= e($f[1]) ?></h3>
          <p><?= e($f[2]) ?></p>
        </article>
      <?php endforeach; ?>
    </div>
    <h3 class="more-title reveal"><?= e(t('more_title')) ?></h3>
    <ul class="more-list">
      <?php foreach (ta('more') as $m): ?>
        <li class="reveal"><strong><?= e($m[0]) ?></strong><span><?= e($m[1]) ?></span></li>
      <?php endforeach; ?>
    </ul>
  </div>
</section>

<section id="shots" class="alt">
  <div class="wrap">
    <div class="section-head reveal">
      <h2><?= e(t('shots_title')) ?></h2>
      <p><?= e(t('shots_sub')) ?></p>
    </div>
    <div class="shots">
      <?php foreach (ta('shots') as $s): ?>
        <figure class="shot reveal">
          <a class="screenshot-link" href="<?= e(shot($s[0])) ?>" aria-label="<?= e($s[1]) ?>"><div class="phone sm"><?= shot_img($s[0], $s[1], false, 'loading="lazy"') ?></div></a>
          <figcaption>
            <h3><?= e($s[1]) ?></h3>
            <p><?= e($s[2]) ?></p>
          </figcaption>
        </figure>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<section id="ipad">
  <div class="wrap">
    <div class="section-head reveal">
      <h2><?= e(t('ipad_title')) ?></h2>
      <p><?= e(t('ipad_sub')) ?></p>
    </div>
    <div class="ipad-shot reveal">
      <?= shot_img('1_library', $LANG === 'zh' ? 'iExif 在 iPad 上的图库界面' : 'iExif on iPad', true, 'loading="lazy"') ?>
    </div>
  </div>
</section>

<section class="alt">
  <div class="wrap">
    <div class="section-head reveal"><h2><?= e(t('detail_title')) ?></h2></div>
    <div class="fields">
      <?php foreach (ta('details') as $d): ?>
        <div class="field reveal"><strong><?= e($d[0]) ?></strong><span><?= e($d[1]) ?></span></div>
      <?php endforeach; ?>
    </div>
    <div class="spacer"></div>
    <div class="note-card reveal">
      <h3><?= e(t('data_title')) ?></h3>
      <p><?= e(t('data_body')) ?></p>
    </div>
  </div>
</section>

<section class="cta">
  <div class="wrap reveal">
    <h2><?= e(t('cta_title')) ?></h2>
    <p><?= e(t('cta_sub')) ?></p>
    <?= appstore_badge(true) ?>
  </div>
</section>

<?php require __DIR__ . '/inc/footer.php'; ?>
