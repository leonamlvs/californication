/* Browser half of IslandVideoPlayback. Instantiated explicitly; no boot side effects. */
(() => {
  'use strict';
  if (window.IslandVideoBridge) return;

  window.IslandVideoBridge = {
    create() {
      const canvas = document.querySelector('canvas');
      if (!canvas) throw new Error('Island video requires the game canvas');
      const lifetime = new AbortController();
      const root = document.createElement('div');
      root.dataset.islandVideoLayer = '';
      Object.assign(root.style, {
        position: 'fixed', overflow: 'hidden', pointerEvents: 'none',
        zIndex: '20', background: 'transparent', display: 'none',
      });
      const poster = document.createElement('img');
      const retained = document.createElement('canvas');
      retained.width = 960;
      retained.height = 720;
      const context = retained.getContext('2d', { alpha: false });
      const action = document.createElement('button');
      action.type = 'button';
      action.dataset.islandVideoAction = '';
      action.hidden = true;
      Object.assign(action.style, {
        position: 'absolute', left: '50%', top: '78%', transform: 'translate(-50%, -50%)',
        pointerEvents: 'auto', padding: '12px 24px', font: '18px sans-serif', zIndex: '3',
      });
      for (const element of [poster, retained]) {
        Object.assign(element.style, { position: 'absolute', inset: '0', width: '100%', height: '100%', objectFit: 'fill' });
      }
      poster.alt = '';
      retained.style.display = 'none';
      root.append(poster, retained, action);
      (canvas.parentElement || document.body).append(root);

      let video = null;
      let mediaEvents = null;
      let frameHandle = null;
      let animationHandle = null;
      let generation = 0;
      let state = 'idle';
      let error = '';
      let prepared = false;
      let wanted = false;
      let hostActive = true;
      let browserActive = !document.hidden;
      let mediaTime = 0;
      let duration = 104 * 1001 / 30000;
      let frameCount = 0;
      let completionCount = 0;
      let completed = false;
      let hasRetainedFrame = false;
      let source = '';
      let posterSource = '';
      let rect = [0, 0, 1, 1];
      let clock = 'requestVideoFrameCallback';
      let pendingPlay = false;

      const active = () => hostActive && browserActive && !document.hidden;
      function showAction() {
        action.hidden = !['gesture_required', 'error'].includes(state);
        action.textContent = state === 'error' ? 'Retry' : 'Play intro';
      }
      function setState(next) {
        state = next;
        showAction();
      }
      function showHeldFrame() {
        if (video) video.style.visibility = 'hidden';
        retained.style.display = hasRetainedFrame ? 'block' : 'none';
        poster.style.display = hasRetainedFrame ? 'none' : 'block';
      }
      function retainFrame() {
        if (!video || video.readyState < 2 || !video.videoWidth) return false;
        try {
          // One retained surface, no pixel readback or per-frame image allocation.
          // Crop only the encoded side borders; the media bytes stay untouched.
          context.drawImage(video, 160, 0, 960, 720, 0, 0, 960, 720);
          hasRetainedFrame = true;
          return true;
        } catch (_) { return false; }
      }
      function sample(time) {
        if (state === 'released' || state === 'error' || completed) return;
        mediaTime = Math.max(mediaTime, Math.min(time, duration));
        frameCount++;
        retainFrame();
        if (state === 'playing' && active()) {
          video.style.visibility = 'visible';
          poster.style.display = 'none';
          retained.style.display = 'none';
        }
      }
      function scheduleFrames(token) {
        if (!video || token !== generation || state === 'released') return;
        if (typeof video.requestVideoFrameCallback === 'function') {
          frameHandle = video.requestVideoFrameCallback((_now, metadata) => {
            if (token !== generation) return;
            if (active() && !['paused', 'buffering', 'error'].includes(state)) sample(metadata.mediaTime);
            scheduleFrames(token);
          });
        } else {
          clock = 'currentTime';
          animationHandle = requestAnimationFrame(() => {
            if (token !== generation) return;
            if (state === 'playing' && active() && video.readyState >= 2 && video.currentTime > mediaTime) sample(video.currentTime);
            scheduleFrames(token);
          });
        }
      }
      function stopMedia() {
        mediaEvents?.abort();
        if (video && frameHandle !== null && video.cancelVideoFrameCallback) video.cancelVideoFrameCallback(frameHandle);
        if (animationHandle !== null) cancelAnimationFrame(animationHandle);
        frameHandle = animationHandle = null;
        if (video) {
          video.pause();
          video.removeAttribute('src');
          video.load();
          video.remove();
          video = null;
        }
        pendingPlay = false;
      }
      function fail(message) {
        if (state === 'released') return;
        retainFrame();
        wanted = false;
        prepared = false;
        video?.pause();
        error = message;
        setState('error');
        showHeldFrame();
      }
      function attemptPlay() {
        if (!video || !wanted || !prepared || completed || !active() || pendingPlay || state === 'released' || state === 'error') return;
        const token = generation;
        const currentVideo = video;
        pendingPlay = true;
        currentVideo.play().then(() => {
          if (token !== generation) return;
          pendingPlay = false;
          if (!wanted || !active()) currentVideo.pause();
        }).catch(reason => {
          if (token !== generation) return;
          pendingPlay = false;
          if (reason.name === 'AbortError' && (!wanted || !active())) return;
          if (reason.name === 'NotAllowedError') {
            wanted = false;
            setState('gesture_required');
            showHeldFrame();
          } else fail(reason.message || 'Video playback failed');
        });
      }
      function layout() {
        if (state === 'released') return;
        const bounds = canvas.getBoundingClientRect();
        Object.assign(root.style, {
          left: `${bounds.left + bounds.width * rect[0]}px`,
          top: `${bounds.top + bounds.height * rect[1]}px`,
          width: `${bounds.width * rect[2]}px`, height: `${bounds.height * rect[3]}px`,
        });
      }
      function updateFocus() {
        if (state === 'released' || completed || state === 'error') return;
        if (!active()) {
          video?.pause();
          if (prepared && wanted) setState('paused');
        } else if (wanted) attemptPlay();
      }

      const api = {
        prepare(url, posterURL) {
          if (state === 'released') return;
          generation++;
          stopMedia();
          source = url;
          posterSource = posterURL;
          error = '';
          prepared = wanted = completed = hasRetainedFrame = false;
          mediaTime = frameCount = 0;
          clock = 'requestVideoFrameCallback';
          poster.src = posterSource;
          root.style.display = 'block';
          setState('preparing');
          showHeldFrame();
          video = document.createElement('video');
          video.dataset.islandVideo = '';
          video.muted = true;
          video.defaultMuted = true;
          video.playsInline = true;
          video.setAttribute('playsinline', '');
          video.setAttribute('webkit-playsinline', '');
          video.preload = 'auto';
          video.loop = false;
          video.controls = false;
          video.disablePictureInPicture = true;
          video.playbackRate = 1;
          Object.assign(video.style, { position: 'absolute', inset: '0', width: '100%', height: '100%', objectFit: 'cover', visibility: 'hidden' });
          root.insertBefore(video, poster);
          mediaEvents = new AbortController();
          const on = (event, handler) => video.addEventListener(event, handler, { signal: mediaEvents.signal });
          on('loadedmetadata', () => {
            if (video.videoWidth !== 1280 || video.videoHeight !== 720) { fail('Unexpected intro dimensions'); return; }
            if (Number.isFinite(video.duration)) duration = video.duration;
          });
          on('loadeddata', () => {
            if (state === 'error') return;
            prepared = true;
            retainFrame();
            showHeldFrame();
            setState('ready');
            if (wanted) attemptPlay();
          });
          on('canplay', () => { if (wanted) attemptPlay(); });
          on('playing', () => {
            if (!wanted || !active()) { video.pause(); return; }
            setState('playing');
          });
          on('waiting', () => { if (wanted && active() && !completed && state !== 'error') setState('buffering'); });
          on('stalled', () => { if (video.readyState < 3 && wanted && active() && !completed && state !== 'error') setState('buffering'); });
          on('error', () => fail(`Unable to load intro (${video.error?.code || 'unknown'})`));
          on('ended', () => {
            if (completed || state === 'error') return;
            retainFrame();
            completed = true;
            wanted = false;
            mediaTime = duration;
            completionCount++;
            setState('ended');
            showHeldFrame();
          });
          video.src = source;
          video.load();
          scheduleFrames(generation);
          layout();
        },
        play() {
          if (state === 'released' || state === 'error' || completed) return;
          wanted = true;
          attemptPlay();
        },
        pause() {
          wanted = false;
          video?.pause();
          if (prepared && !completed && state !== 'error' && state !== 'released') setState('paused');
        },
        restart() {
          if (state === 'released') return;
          api.prepare(source, posterSource);
          api.play();
        },
        setFocusActive(value) { hostActive = Boolean(value); updateFocus(); },
        setPictureRect(x, y, width, height) { rect = [x, y, width, height]; layout(); },
        setOpacity(value) {
          root.style.opacity = Math.max(0, Math.min(1, value));
          root.style.visibility = value <= 0 ? 'hidden' : 'visible';
        },
        snapshot() {
          return JSON.stringify({ state, prepared, media_time: mediaTime, duration, frame_count: frameCount,
            completion_count: completionCount, error, clock, active: active(), wanted, retained_frame: hasRetainedFrame });
        },
        release() {
          if (state === 'released') return;
          generation++;
          wanted = prepared = false;
          stopMedia();
          lifetime.abort();
          observer.disconnect();
          root.remove();
          retained.width = retained.height = 1;
          setState('released');
        },
      };
      for (const event of ['pointerdown', 'pointerup', 'touchstart', 'touchend', 'keydown', 'keyup']) {
        action.addEventListener(event, e => e.stopPropagation(), { signal: lifetime.signal });
      }
      action.addEventListener('click', event => {
        event.preventDefault();
        event.stopImmediatePropagation();
        // Invoke play inside the actual user gesture, including on Safari.
        if (state === 'error') api.restart();
        else api.play();
      }, { signal: lifetime.signal });
      window.addEventListener('blur', () => { browserActive = false; updateFocus(); }, { signal: lifetime.signal });
      window.addEventListener('focus', () => { browserActive = true; updateFocus(); }, { signal: lifetime.signal });
      document.addEventListener('visibilitychange', () => { browserActive = !document.hidden && document.hasFocus(); updateFocus(); }, { signal: lifetime.signal });
      for (const event of ['resize', 'scroll', 'orientationchange']) window.addEventListener(event, layout, { signal: lifetime.signal });
      document.addEventListener('fullscreenchange', layout, { signal: lifetime.signal });
      window.visualViewport?.addEventListener('resize', layout, { signal: lifetime.signal });
      const observer = new ResizeObserver(layout);
      observer.observe(canvas);
      return api;
    },
  };
})();
