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
}

window.addEventListener('DOMContentLoaded', init);
