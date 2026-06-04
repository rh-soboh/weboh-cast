import { DetectedVideo, VideoFormat } from '../../models/types';

function detectFormat(url: string): VideoFormat {
  const lower = url.toLowerCase();
  if (lower.includes('.m3u8')) return 'hls';
  if (lower.includes('.mpd')) return 'dash';
  if (lower.includes('.mp4') || lower.includes('.m4v')) return 'mp4';
  if (lower.includes('.webm')) return 'webm';
  if (lower.includes('.mkv')) return 'mkv';
  return 'other';
}

function generateId(): string {
  return Math.random().toString(36).substr(2, 9) + Date.now().toString(36);
}

function extractTitle(url: string, pageTitle?: string): string {
  if (pageTitle && pageTitle.length > 0 && pageTitle.length < 200) return pageTitle;
  try {
    const pathname = new URL(url).pathname;
    const filename = pathname.split('/').pop() || '';
    const decoded = decodeURIComponent(filename);
    const name = decoded.replace(/\.[^.]+$/, '').replace(/[-_]/g, ' ');
    return name || 'Video';
  } catch {
    return 'Video';
  }
}

export function parseVideoMessage(data: string, pageTitle?: string, pageURL?: string): DetectedVideo | null {
  try {
    const parsed = JSON.parse(data);
    if (!parsed.url || typeof parsed.url !== 'string') return null;
    const url = parsed.url;
    if (url.startsWith('blob:') || url.startsWith('data:') || url.length < 10) return null;

    return {
      id: generateId(),
      url,
      title: extractTitle(url, pageTitle),
      format: detectFormat(url),
      resolution: parsed.resolution,
      duration: parsed.duration,
      pageURL: pageURL || parsed.pageURL,
      pageTitle: pageTitle || parsed.pageTitle,
      detectedAt: Date.now(),
    };
  } catch {
    return null;
  }
}

export async function probeVideoMetadata(video: DetectedVideo): Promise<DetectedVideo> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    const response = await fetch(video.url, {
      method: 'HEAD',
      signal: controller.signal,
    });
    clearTimeout(timeout);

    const contentLength = response.headers.get('content-length');
    if (contentLength) {
      video.size = parseInt(contentLength, 10);
    }
    return video;
  } catch {
    return video;
  }
}

export function getDetectorScript(): string {
  return `(function() {
    'use strict';
    if (window.__webCasterDetectorInjected) return;
    window.__webCasterDetectorInjected = true;

    var DETECTED = new Set();
    var VIDEO_EXTENSIONS = /\\.(m3u8|mp4|webm|mkv|avi|mov|ts|mpd|m4v|flv|3gp)(\\?|$|#)/i;
    var STREAM_PATTERNS = /\\/(manifest|playlist|master|index|stream|video)\\.(m3u8|mpd)/i;

    function notifyDetected(url, extra) {
      if (!url || DETECTED.has(url)) return;
      if (url.startsWith('blob:') || url.startsWith('data:')) return;
      if (url.length < 10) return;
      DETECTED.add(url);
      var info = Object.assign({ url: url, timestamp: Date.now() }, extra || {});
      try { window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'videoDetected', payload: info })); } catch(e) {}
    }

    function checkURL(url, extra) {
      if (!url || typeof url !== 'string') return;
      if (VIDEO_EXTENSIONS.test(url) || STREAM_PATTERNS.test(url)) notifyDetected(url, extra);
    }

    function scanDOM() {
      document.querySelectorAll('video').forEach(function(v) {
        if (v.src) checkURL(v.src, { type: 'video-tag' });
        if (v.currentSrc) checkURL(v.currentSrc, { type: 'video-currentSrc' });
        v.querySelectorAll('source').forEach(function(s) { if (s.src) checkURL(s.src, { type: 'source-tag' }); });
        if (v.videoWidth && v.videoHeight) {
          var res = v.videoWidth + 'x' + v.videoHeight;
          if (v.src) notifyDetected(v.src, { resolution: res, type: 'video-tag' });
        }
      });
      document.querySelectorAll('iframe').forEach(function(f) { if (f.src) checkURL(f.src, { type: 'iframe' }); });
      document.querySelectorAll('meta[property="og:video"], meta[property="og:video:url"]').forEach(function(m) {
        if (m.content) checkURL(m.content, { type: 'og-meta' });
      });
      document.querySelectorAll('script[type="application/ld+json"]').forEach(function(s) {
        try {
          var d = JSON.parse(s.textContent);
          if (d.contentUrl) checkURL(d.contentUrl, { type: 'json-ld' });
          if (d.embedUrl) checkURL(d.embedUrl, { type: 'json-ld' });
        } catch(e) {}
      });
    }

    var observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(m) {
        m.addedNodes.forEach(function(node) {
          if (node.nodeType !== 1) return;
          if (node.tagName === 'VIDEO' || node.tagName === 'SOURCE') checkURL(node.src, { type: node.tagName.toLowerCase() + '-dynamic' });
          if (node.tagName === 'IFRAME') checkURL(node.src, { type: 'iframe-dynamic' });
          if (node.querySelectorAll) node.querySelectorAll('video, source, iframe').forEach(function(el) { checkURL(el.src, { type: el.tagName.toLowerCase() + '-nested' }); });
        });
        if (m.type === 'attributes' && m.attributeName === 'src') checkURL(m.target.src, { type: 'attr-change' });
      });
    });
    observer.observe(document.documentElement || document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['src'] });

    var origXHR = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) { checkURL(url, { type: 'xhr' }); return origXHR.apply(this, arguments); };

    var origFetch = window.fetch;
    window.fetch = function(input) { var url = (typeof input === 'string') ? input : (input && input.url); checkURL(url, { type: 'fetch' }); return origFetch.apply(this, arguments); };

    document.addEventListener('loadedmetadata', function(e) {
      if (e.target.tagName === 'VIDEO') {
        var v = e.target;
        var info = { type: 'loadedmetadata', resolution: v.videoWidth + 'x' + v.videoHeight, duration: v.duration };
        if (v.src) notifyDetected(v.src, info);
        if (v.currentSrc) notifyDetected(v.currentSrc, info);
      }
    }, true);

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', scanDOM);
    else scanDOM();
    setTimeout(scanDOM, 2000);
    setTimeout(scanDOM, 5000);
    setTimeout(scanDOM, 10000);
  })(); true;`;
}
