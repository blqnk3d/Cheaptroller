async function init() {
  const ipListEl = document.getElementById('ip-list');
  const qrEl = document.getElementById('qr-code');

  // Fetch local IPs
  const res = await fetch('/api/myip');
  const data = await res.json();

  // Display IPs
  data.ips.forEach(ip => {
    const span = document.createElement('span');
    span.textContent = ip;
    ipListEl.appendChild(span);
  });

  // Generate QR code for the first IP
  if (data.ips.length > 0) {
    const url = `http://${data.ips[0]}:${data.port}`;
    QRCode.toCanvas(qrEl, url, { width: 200 }, function (error) {
      if (error) console.error(error);
      else console.log('QR code generated for', url);
    });
  }

  // Shutdown button
  const shutdownBtn = document.getElementById('shutdown-btn');
  shutdownBtn.addEventListener('click', async () => {
    if (confirm('Are you sure you want to shut down the server?')) {
      try {
        // Update UI to show shutdown status
        shutdownBtn.disabled = true;
        shutdownBtn.textContent = 'Shutting down...';

        // Add a message to the container
        const container = document.querySelector('.container');
        const msg = document.createElement('p');
        msg.style.color = 'red';
        msg.style.fontWeight = 'bold';
        msg.style.textAlign = 'center';
        msg.textContent = 'Server is shutting down. You can close this tab now.';
        container.appendChild(msg);

        // Send shutdown request
        await fetch('/api/shutdown', { method: 'POST' });

        // Wait a brief moment for the request to complete, then try to close
        setTimeout(() => {
          window.close();
          // Fallback if window.close() is blocked by the browser
          msg.textContent = 'Server shut down. Please close this tab manually.';
        }, 500);

      } catch (err) {
        console.error('Failed to shut down server:', err);
        shutdownBtn.disabled = false;
        shutdownBtn.textContent = 'Shutdown Server';
      }
    }
  });
}

window.addEventListener('DOMContentLoaded', init);
