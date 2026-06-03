(function() {
    'use strict';

    if (window.__webCasterDetectorInjected) return;
    window.__webCasterDetectorInjected = true;

    const DETECTED = new Set();
    const VIDEO_EXTENSIONS = /\.(m3u8|mp4|webm|mkv|avi|mov|ts|mpd|m4v|flv|3gp)(\?|$|#)/i;
    const STREAM_PATTERNS = /\/(manifest|playlist|master|index|stream|video)\.(m3u8|mpd)/i;

    function notifyDetected(url, extra) {
        if (!url || DETECTED.has(url)) return;
        if (url.startsWith('blob:') || url.startsWith('data:')) return;

        // Ignore tiny tracking pixels and non-video resources
        if (url.length < 10) return;

        DETECTED.add(url);
        var info = Object.assign({ url: url, timestamp: Date.now() }, extra || {});
        try {
            window.webkit.messageHandlers.videoDetected.postMessage(JSON.stringify(info));
        } catch(e) {}
    }

    function checkURL(url, extra) {
        if (!url) return;
        if (typeof url !== 'string') url = String(url);
        if (VIDEO_EXTENSIONS.test(url) || STREAM_PATTERNS.test(url)) {
            notifyDetected(url, extra);
        }
    }

    // 1. Scan existing video/source/iframe elements
    function scanDOM() {
        document.querySelectorAll('video').forEach(function(v) {
            if (v.src) checkURL(v.src, { type: 'video-tag' });
            if (v.currentSrc) checkURL(v.currentSrc, { type: 'video-currentSrc' });
            v.querySelectorAll('source').forEach(function(s) {
                if (s.src) checkURL(s.src, { type: 'source-tag' });
            });

            // Try to get resolution
            if (v.videoWidth && v.videoHeight) {
                var res = v.videoWidth + 'x' + v.videoHeight;
                if (v.src) notifyDetected(v.src, { resolution: res, type: 'video-tag' });
            }
        });

        document.querySelectorAll('iframe').forEach(function(iframe) {
            if (iframe.src) checkURL(iframe.src, { type: 'iframe' });
        });

        // Check og:video meta tags
        document.querySelectorAll('meta[property="og:video"], meta[property="og:video:url"]').forEach(function(m) {
            if (m.content) checkURL(m.content, { type: 'og-meta' });
        });

        // Check JSON-LD structured data
        document.querySelectorAll('script[type="application/ld+json"]').forEach(function(s) {
            try {
                var data = JSON.parse(s.textContent);
                if (data.contentUrl) checkURL(data.contentUrl, { type: 'json-ld' });
                if (data.embedUrl) checkURL(data.embedUrl, { type: 'json-ld' });
            } catch(e) {}
        });
    }

    // 2. MutationObserver for dynamically added elements
    var observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(m) {
            m.addedNodes.forEach(function(node) {
                if (node.nodeType !== 1) return;
                if (node.tagName === 'VIDEO' || node.tagName === 'SOURCE') {
                    checkURL(node.src, { type: node.tagName.toLowerCase() + '-dynamic' });
                }
                if (node.tagName === 'IFRAME') {
                    checkURL(node.src, { type: 'iframe-dynamic' });
                }
                if (node.querySelectorAll) {
                    node.querySelectorAll('video, source, iframe').forEach(function(el) {
                        checkURL(el.src, { type: el.tagName.toLowerCase() + '-nested' });
                    });
                }
            });

            if (m.type === 'attributes' && m.attributeName === 'src') {
                checkURL(m.target.src, { type: 'attr-change' });
            }
        });
    });

    observer.observe(document.documentElement || document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['src']
    });

    // 3. Intercept XMLHttpRequest
    var origXHROpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) {
        checkURL(url, { type: 'xhr' });
        return origXHROpen.apply(this, arguments);
    };

    // 4. Intercept fetch()
    var origFetch = window.fetch;
    window.fetch = function(input) {
        var url = (typeof input === 'string') ? input : (input && input.url);
        checkURL(url, { type: 'fetch' });
        return origFetch.apply(this, arguments);
    };

    // 5. Intercept MediaSource
    if (window.MediaSource) {
        var origAddSourceBuffer = MediaSource.prototype.addSourceBuffer;
        MediaSource.prototype.addSourceBuffer = function(mimeType) {
            try {
                window.webkit.messageHandlers.videoDetected.postMessage(JSON.stringify({
                    url: window.location.href,
                    type: 'mediasource',
                    mimeType: mimeType,
                    timestamp: Date.now()
                }));
            } catch(e) {}
            return origAddSourceBuffer.apply(this, arguments);
        };
    }

    // 6. Intercept createElement for dynamic video elements
    var origCreateElement = document.createElement;
    document.createElement = function(tag) {
        var el = origCreateElement.apply(this, arguments);
        if (tag.toLowerCase() === 'video' || tag.toLowerCase() === 'source') {
            var origSetAttr = el.setAttribute;
            el.setAttribute = function(name, value) {
                if (name === 'src') checkURL(value, { type: 'createElement-' + tag });
                return origSetAttr.apply(this, arguments);
            };
            Object.defineProperty(el, 'src', {
                set: function(v) {
                    checkURL(v, { type: 'createElement-src-' + tag });
                    origSetAttr.call(el, 'src', v);
                },
                get: function() { return el.getAttribute('src'); }
            });
        }
        return el;
    };

    // 7. Monitor video element events for resolution data
    document.addEventListener('loadedmetadata', function(e) {
        if (e.target.tagName === 'VIDEO') {
            var v = e.target;
            var info = {
                type: 'loadedmetadata',
                resolution: v.videoWidth + 'x' + v.videoHeight,
                duration: v.duration
            };
            if (v.src) notifyDetected(v.src, info);
            if (v.currentSrc) notifyDetected(v.currentSrc, info);
        }
    }, true);

    // Initial scan
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', scanDOM);
    } else {
        scanDOM();
    }

    // Re-scan periodically for late-loading content
    setTimeout(scanDOM, 2000);
    setTimeout(scanDOM, 5000);
    setTimeout(scanDOM, 10000);
})();
