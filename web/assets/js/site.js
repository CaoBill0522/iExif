'use strict';
const viewer = document.getElementById('screenshot-viewer');
if (viewer && typeof viewer.showModal === 'function') {
  document.querySelectorAll('.screenshot-link').forEach(link => {
    link.addEventListener('click', event => {
      event.preventDefault();
      const image = viewer.querySelector('img');
      // 用当前实际显示的那张（深色模式下是深色截图）
      const shown = link.querySelector('img');
      image.src = (shown && shown.currentSrc) || link.href;
      image.alt = link.getAttribute('aria-label');
      viewer.querySelector('p').textContent = image.alt;
      viewer.showModal();
    });
  });
  viewer.querySelector('button').addEventListener('click', () => viewer.close());
  viewer.addEventListener('click', event => { if (event.target === viewer) viewer.close(); });
}

// 手机菜单：点链接、点外部、按 Esc 时收起
const menu = document.querySelector('details.menu');
if (menu) {
  const close = () => { menu.open = false; };
  menu.querySelectorAll('a').forEach(a => a.addEventListener('click', close));
  document.addEventListener('click', event => { if (menu.open && !menu.contains(event.target)) close(); });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && menu.open) { close(); menu.querySelector('summary').focus(); }
  });
}
