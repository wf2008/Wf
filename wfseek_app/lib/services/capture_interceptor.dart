/// JavaScript that hooks fetch & XHR and forwards captured requests/responses
/// to the Dart side via the `CaptureChannel` JavaScript channel.
const String captureJS = r"""
(function() {
  if (window.__wfseekCaptureInstalled) return;
  window.__wfseekCaptureInstalled = true;

  function shouldSkip(url, contentType) {
    if (!url) return true;
    const lower = url.toLowerCase();
    const skipExt = ['.png','.jpg','.jpeg','.gif','.webp','.svg','.ico',
                     '.woff','.woff2','.ttf','.otf','.eot',
                     '.mp4','.webm','.mp3','.wav','.ogg'];
    for (const ext of skipExt) {
      if (lower.endsWith(ext) && !lower.includes('api')) return true;
    }
    if (lower.endsWith('.css')) return true;
    if (lower.endsWith('.js') && !lower.includes('api')) return true;
    if (contentType) {
      const ct = contentType.toLowerCase();
      if (ct.startsWith('image/')) return true;
      if (ct.startsWith('video/')) return true;
      if (ct.startsWith('audio/')) return true;
      if (ct.startsWith('font/')) return true;
      if (ct.includes('css')) return true;
    }
    return false;
  }

  function post(entry) {
    try {
      window.CaptureChannel.postMessage(JSON.stringify(entry));
    } catch (e) { /* channel may not be attached yet */ }
  }

  // fetch hook
  const origFetch = window.fetch;
  window.fetch = function(input, init) {
    const url = (typeof input === 'string') ? input : (input && input.url);
    const method = (init && init.method) || (input && input.method) || 'GET';
    const reqHeaders = (init && init.headers) || {};
    const reqBody = (init && init.body) || null;
    return origFetch.apply(this, arguments).then(async (resp) => {
      try {
        const ct = resp.headers.get('content-type') || '';
        if (!shouldSkip(url, ct)) {
          const clone = resp.clone();
          let body = '';
          try { body = await clone.text(); } catch (e) {}
          post({
            type: 'fetch',
            url: url,
            method: method,
            status: resp.status,
            requestHeaders: reqHeaders,
            requestBody: typeof reqBody === 'string' ? reqBody : null,
            responseHeaders: Object.fromEntries(resp.headers.entries()),
            responseBody: body.substring(0, 200000),
            ts: Date.now(),
          });
        }
      } catch (e) {}
      return resp;
    });
  };

  // XHR hook
  const OrigXHR = window.XMLHttpRequest;
  function PatchedXHR() {
    const xhr = new OrigXHR();
    let _url = '', _method = 'GET', _reqHeaders = {}, _reqBody = null;
    const origOpen = xhr.open;
    xhr.open = function(method, url) {
      _method = method; _url = url;
      return origOpen.apply(xhr, arguments);
    };
    const origSetHeader = xhr.setRequestHeader;
    xhr.setRequestHeader = function(k, v) {
      _reqHeaders[k] = v;
      return origSetHeader.apply(xhr, arguments);
    };
    const origSend = xhr.send;
    xhr.send = function(body) {
      _reqBody = body;
      xhr.addEventListener('loadend', function() {
        try {
          const ct = xhr.getResponseHeader('content-type') || '';
          if (shouldSkip(_url, ct)) return;
          post({
            type: 'xhr',
            url: _url,
            method: _method,
            status: xhr.status,
            requestHeaders: _reqHeaders,
            requestBody: typeof _reqBody === 'string' ? _reqBody : null,
            responseHeaders: ct ? {'content-type': ct} : {},
            responseBody: (typeof xhr.responseText === 'string'
                          ? xhr.responseText.substring(0, 200000) : ''),
            ts: Date.now(),
          });
        } catch (e) {}
      });
      return origSend.apply(xhr, arguments);
    };
    return xhr;
  }
  window.XMLHttpRequest = PatchedXHR;
})();
""";
