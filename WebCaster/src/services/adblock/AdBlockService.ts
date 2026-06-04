import blocklist from './blocklist.json';

const AD_DOMAINS = [
  'googlesyndication.com', 'doubleclick.net', 'googleadservices.com',
  'google-analytics.com', 'adservice.google.com', 'facebook.net',
  'fbcdn.net', 'connect.facebook.net', 'quantserve.com',
  'scorecardresearch.com', 'outbrain.com', 'taboola.com',
  'criteo.com', 'adnxs.com', 'adsrvr.org', 'rubiconproject.com',
  'pubmatic.com', 'openx.net', 'moatads.com', 'amazon-adsystem.com',
  'popads.net', 'popcash.net', 'propellerads.com', 'adcolony.com',
  'applovin.com', 'mopub.com', 'chartbeat.com', 'hotjar.com',
  'mixpanel.com', 'segment.com', 'amplitude.com', 'newrelic.com',
  'branch.io', 'adjust.com', 'appsflyer.com',
];

const AD_URL_PATTERNS = [
  /\.ads\./i, /adserver/i, /tracking\./i, /analytics\.js/i,
  /pixel\.facebook/i, /pagead/i, /ad\.doubleclick/i,
  /\/ads\//i, /\/ad\//i, /banner.*ad/i, /popup.*ad/i,
];

export function shouldBlockURL(url: string): boolean {
  try {
    const hostname = new URL(url).hostname;
    if (AD_DOMAINS.some(d => hostname.includes(d))) return true;
    if (AD_URL_PATTERNS.some(p => p.test(url))) return true;
  } catch {}
  return false;
}

export function getAdBlockInjectionScript(blockWebRTC: boolean): string {
  return `(function() {
    if (window.__wcAdBlockInjected) return;
    window.__wcAdBlockInjected = true;

    // Remove ad elements by common selectors
    function removeAds() {
      var selectors = [
        '[id*="google_ads"]', '[id*="ad-"]', '[id*="ad_"]',
        '[class*="ad-banner"]', '[class*="ad_banner"]', '[class*="adsbygoogle"]',
        'ins.adsbygoogle', '[data-ad]', '[data-ad-slot]',
        '.ad-container', '.ad-wrapper', '.advertisement',
        'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]',
        '[id*="taboola"]', '[id*="outbrain"]', '.sponsored',
      ];
      selectors.forEach(function(sel) {
        document.querySelectorAll(sel).forEach(function(el) {
          el.remove();
        });
      });
    }

    removeAds();
    var obs = new MutationObserver(function() { removeAds(); });
    obs.observe(document.documentElement, { childList: true, subtree: true });

    // Block popups
    window.open = function() { return null; };

    // Neuter ad-related scripts
    var origAppendChild = Element.prototype.appendChild;
    Element.prototype.appendChild = function(child) {
      if (child.tagName === 'SCRIPT' && child.src) {
        var blocked = ${JSON.stringify(AD_DOMAINS)};
        if (blocked.some(function(d) { return child.src.includes(d); })) {
          return child;
        }
      }
      return origAppendChild.call(this, child);
    };

    ${blockWebRTC ? `
    // Block WebRTC leaks
    if (window.RTCPeerConnection) {
      window.RTCPeerConnection = function() { throw new Error('WebRTC blocked'); };
    }
    if (window.webkitRTCPeerConnection) {
      window.webkitRTCPeerConnection = function() { throw new Error('WebRTC blocked'); };
    }
    ` : ''}
  })();`;
}

export { blocklist };
