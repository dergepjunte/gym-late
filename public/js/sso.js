// ════════════════════════════════════════════════════════
//  SSO (Sign in with Google) — client-side wiring
// ════════════════════════════════════════════════════════
// Client IDs are fetched from the server (not hardcoded) so they can be
// rotated via env var without touching static assets. Apple's button stays
// hidden until APPLE_SERVICES_ID is configured server-side (see
// sso-credentials-progress memory — blocked on Apple Developer Program).

// The GIS script tag is `async defer`, so it can still be loading well
// after DOMContentLoaded — poll rather than assume `window.google` exists.
function waitForGoogleLib(timeoutMs = 8000) {
  return new Promise(resolve => {
    const start = Date.now();
    (function poll() {
      if (window.google?.accounts?.id) return resolve(true);
      if (Date.now() - start > timeoutMs) return resolve(false);
      setTimeout(poll, 100);
    })();
  });
}

async function initSso() {
  let cfg;
  try { cfg = await api.authConfig(); } catch { return; }
  if (!cfg.googleWebClientId) return;
  if (!await waitForGoogleLib()) {
    // The button silently never renders past this point — if that's
    // unexpected (misconfigured origin, ad-blocker, CSP), this is the only
    // signal a dev has to go on.
    console.warn('[sso] Google Identity Services script did not load in time; Google sign-in button will not render.');
    return;
  }

  google.accounts.id.initialize({
    client_id: cfg.googleWebClientId,
    callback: handleGoogleCredential,
  });
  renderGoogleButton('aa-google-btn', 'aa-sso-divider');
  renderGoogleButton('mig-google-btn', 'mig-sso-divider');
}

function renderGoogleButton(containerId, dividerId) {
  const el = document.getElementById(containerId);
  if (!el) return;
  el.style.display = '';
  document.getElementById(dividerId).style.display = '';
  google.accounts.id.renderButton(el, {
    type: 'standard', theme: 'outline', size: 'large', width: 320, text: 'continue_with',
  });
}

// Fires for BOTH the account-auth modal's button and the migration popup's
// inline button (same shared callback) — `aaPurpose` (set synchronously by
// whichever caller opened its modal, see account.js) tells afterAccountAuth
// which flow to run.
async function handleGoogleCredential(response) {
  try {
    const r = await api.accountGoogle(response.credential);
    await afterAccountAuth(r);
  } catch (e) {
    if (e.status === 401) showToast(T.aaErrWrong);
    else if (e.status === 501) showToast(T.aaErrSsoNotConfigured);
    else showToast(T.errServer);
  }
}

if (document.readyState === 'complete' || document.readyState === 'interactive') {
  initSso();
} else {
  document.addEventListener('DOMContentLoaded', initSso);
}
