// Performance and hardware feature detection for graceful fallback rendering
(function () {
  'use strict';

  function detectLowSpec() {
    let isWeak = false;

    // 1. Device memory check (if available)
    if (navigator.deviceMemory && navigator.deviceMemory < 4) {
      isWeak = true;
    }

    // 2. Hardware concurrency / CPU core count
    if (navigator.hardwareConcurrency && navigator.hardwareConcurrency <= 2) {
      isWeak = true;
    }

    // 3. WebGL GPU unmasked renderer check
    try {
      const canvas = document.createElement('canvas');
      const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
      if (gl) {
        const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
        if (debugInfo) {
          const renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL).toLowerCase();
          if (
            renderer.includes('swiftshader') ||
            renderer.includes('llvmpipe') ||
            renderer.includes('software rasterizer') ||
            renderer.includes('microsoft basic render')
          ) {
            isWeak = true;
          }
        }
      }
    } catch (err) {
      console.warn('WebGL context check unavailable in current environment:', err);
    }

    // 4. Battery status check (< 15% charge and discharging)
    if (navigator.getBattery) {
      navigator.getBattery().then(function (battery) {
        if (!battery.charging && battery.level < 0.15) {
          document.documentElement.classList.add('low-spec-mode');
        }
      }).catch(function (err) {
        console.warn('Battery status API unavailable:', err);
      });
    }

    // Apply class to HTML tag for CSS zero-blur fallback on low-spec hardware
    if (isWeak) {
      document.documentElement.classList.add('weak-graphics');
      document.documentElement.classList.add('low-spec-mode');
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', detectLowSpec);
  } else {
    detectLowSpec();
  }
})();
