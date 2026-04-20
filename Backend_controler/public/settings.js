document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('settings-form');
  const resetBtn = document.getElementById('reset-btn');
  const messageEl = document.getElementById('settings-message');
  const configPathEl = document.getElementById('config-path');
  const navLinks = document.querySelectorAll('.nav-link');
  const homePage = document.getElementById('home-page');
  const settingsPage = document.getElementById('settings-page');

  let currentConfig = {};

  function showMessage(text, isError = false) {
    messageEl.textContent = text;
    messageEl.className = 'message ' + (isError ? 'error' : 'success');
    messageEl.style.display = 'block';
    setTimeout(() => {
      messageEl.style.display = 'none';
    }, 3000);
  }

  async function loadConfig() {
    try {
      const res = await fetch('/api/config');
      currentConfig = await res.json();
      populateForm(currentConfig);
      configPathEl.textContent = '/home/' + (await res.json()).configPath || '~/.config/cheaptroller/config.json';
    } catch (err) {
      showMessage('Failed to load config', true);
    }
  }

  function populateForm(config) {
    document.getElementById('webPort').value = config.webPort;
    document.getElementById('udpPort').value = config.udpPort;
    document.getElementById('bonjourName').value = config.bonjourName;
    document.getElementById('stickDeadzone').value = config.stickDeadzone;
    document.getElementById('clientTimeoutMs').value = config.clientTimeoutMs;
    document.getElementById('latencyStatsMaxSize').value = config.latencyStatsMaxSize;
    document.getElementById('openBrowser').checked = config.openBrowser;
    document.getElementById('debugProtocol').checked = config.debugProtocol;
  }

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(form);
    const newConfig = {
      webPort: parseInt(formData.get('webPort'), 10),
      udpPort: parseInt(formData.get('udpPort'), 10),
      bonjourName: formData.get('bonjourName'),
      stickDeadzone: parseFloat(formData.get('stickDeadzone')),
      clientTimeoutMs: parseInt(formData.get('clientTimeoutMs'), 10),
      latencyStatsMaxSize: parseInt(formData.get('latencyStatsMaxSize'), 10),
      openBrowser: formData.get('openBrowser') === 'on',
      debugProtocol: formData.get('debugProtocol') === 'on'
    };

    try {
      const res = await fetch('/api/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newConfig)
      });
      if (res.ok) {
        showMessage('Settings saved! Restart required for changes to take effect.');
      } else {
        showMessage('Failed to save settings', true);
      }
    } catch (err) {
      showMessage('Error: ' + err.message, true);
    }
  });

  resetBtn.addEventListener('click', async () => {
    if (!confirm('Reset all settings to defaults?')) return;
    try {
      const res = await fetch('/api/config/reset', { method: 'POST' });
      const config = await res.json();
      populateForm(config);
      showMessage('Settings reset to defaults. Restart required.');
    } catch (err) {
      showMessage('Failed to reset settings', true);
    }
  });

  function handleNavigation() {
    const path = window.location.pathname;
    if (path === '/settings') {
      homePage.classList.add('hidden');
      settingsPage.classList.remove('hidden');
      navLinks[0].classList.remove('active');
      navLinks[1].classList.add('active');
      loadConfig();
    } else {
      settingsPage.classList.add('hidden');
      homePage.classList.remove('hidden');
      navLinks[1].classList.remove('active');
      navLinks[0].classList.add('active');
    }
  }

  navLinks.forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      const page = link.dataset.page;
      if (page === 'settings') {
        window.history.pushState({}, '', '/settings');
      } else {
        window.history.pushState({}, '', '/');
      }
      handleNavigation();
    });
  });

  window.addEventListener('popstate', handleNavigation);
  handleNavigation();
});