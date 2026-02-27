const express = require('express');
const http = require('http');
const chokidar = require('chokidar');
const { WebSocketServer } = require('ws');
const { execSync, exec, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const PORT = 3333;
const MACOS_APP_DIR = '/Users/shaharharel/ezLander/macos-app';
const XCODE_PROJECT = path.join(MACOS_APP_DIR, 'EzLander.xcodeproj');
const SCREENSHOTS_DIR = path.join(__dirname, 'screenshots');
const DASHBOARD_PATH = path.join(__dirname, 'dashboard.html');
const CAPTURE_SCRIPT = path.join(__dirname, 'capture.sh');
const DEBOUNCE_MS = 1000;
const CAPTURE_INTERVAL_MS = 2000;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

let buildStatus = 'idle'; // idle | building | capturing | error
let lastUpdateTime = null;
let lastBuildError = null;
let activityLog = [];
let captureTimer = null;
let appProcess = null;
let debounceTimer = null;
let captureInProgress = false;
let fileWatcher = null;
let isShuttingDown = false;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function timestamp() {
  return new Date().toISOString();
}

function log(message) {
  const entry = `[${timestamp()}] ${message}`;
  console.log(entry);
  activityLog.push(entry);
  if (activityLog.length > 50) {
    activityLog.shift();
  }
  broadcast({ type: 'log', entry });
}

function setStatus(status, error) {
  buildStatus = status;
  lastBuildError = error || null;
  if (status !== 'error') {
    lastUpdateTime = timestamp();
  }
  broadcast({
    type: 'status',
    status: buildStatus,
    lastUpdate: lastUpdateTime,
    error: lastBuildError,
    clients: wss ? wss.clients.size : 0,
  });
}

function broadcast(data) {
  if (!wss) return;
  const msg = JSON.stringify(data);
  wss.clients.forEach((client) => {
    if (client.readyState === 1) {
      client.send(msg);
    }
  });
}

// ---------------------------------------------------------------------------
// Ensure screenshots directory exists
// ---------------------------------------------------------------------------

if (!fs.existsSync(SCREENSHOTS_DIR)) {
  fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });
}

// ---------------------------------------------------------------------------
// Build
// ---------------------------------------------------------------------------

function findBuiltApp() {
  // Search DerivedData for the built .app bundle — pick the most recently modified
  const derivedDataBase = path.join(
    process.env.HOME,
    'Library/Developer/Xcode/DerivedData'
  );
  if (!fs.existsSync(derivedDataBase)) return null;

  const dirs = fs.readdirSync(derivedDataBase).filter((d) => d.startsWith('EzLander'));
  let bestApp = null;
  let bestMtime = 0;

  for (const dir of dirs) {
    const appPath = path.join(
      derivedDataBase,
      dir,
      'Build/Products/Debug/EzLander.app'
    );
    const execPath = path.join(appPath, 'Contents/MacOS/EzLander');
    if (fs.existsSync(execPath)) {
      const mtime = fs.statSync(execPath).mtimeMs;
      if (mtime > bestMtime) {
        bestMtime = mtime;
        bestApp = appPath;
      }
    }
  }

  if (bestApp) return bestApp;

  // Also check the local build directory
  const localBuild = path.join(MACOS_APP_DIR, 'build/Debug/EzLander.app');
  if (fs.existsSync(localBuild)) return localBuild;

  return null;
}

function runBuild() {
  return new Promise((resolve, reject) => {
    if (buildStatus === 'building') {
      log('Build already in progress, skipping.');
      return reject(new Error('Build already in progress'));
    }

    setStatus('building');
    log('Starting xcodebuild...');

    const buildCmd = [
      'xcodebuild',
      '-project', XCODE_PROJECT,
      '-scheme', 'EzLander',
      '-configuration', 'Debug',
      'build',
      'CODE_SIGN_IDENTITY="-"',
      'CODE_SIGNING_REQUIRED=NO',
      'CODE_SIGNING_ALLOWED=NO',
    ].join(' ');

    exec(buildCmd, { maxBuffer: 10 * 1024 * 1024, timeout: 300000 }, (err, stdout, stderr) => {
      if (err) {
        const errorLines = stderr
          ? stderr.split('\n').filter((l) => l.includes('error:')).slice(0, 10).join('\n')
          : err.message;
        log(`Build FAILED: ${errorLines || err.message}`);
        setStatus('error', errorLines || err.message);
        return reject(err);
      }
      log('Build succeeded.');
      setStatus('idle');
      resolve();
    });
  });
}

// ---------------------------------------------------------------------------
// App launch
// ---------------------------------------------------------------------------

function killApp() {
  appProcess = null;
  // Kill any EzLander processes launched with --preview-mode
  try {
    execSync('pkill -f "EzLander.*--preview-mode" 2>/dev/null || true');
  } catch (_) {
    // fine
  }
  // Also try by app name in case the flag wasn't passed through
  try {
    execSync('osascript -e \'tell application "EzLander" to quit\' 2>/dev/null || true');
  } catch (_) {
    // fine
  }
}

function launchApp() {
  killApp();

  const appPath = findBuiltApp();
  if (!appPath) {
    log('Could not find built EzLander.app in DerivedData.');
    return false;
  }

  log(`Launching app: ${appPath}`);

  // Use 'open' command to ensure proper window server registration
  // But also launch it directly so we can capture stdout for diagnostics
  const executable = path.join(appPath, 'Contents/MacOS/EzLander');

  if (!fs.existsSync(executable)) {
    log(`Executable not found at ${executable}`);
    return false;
  }

  // Launch via open first to register with window server, then monitor output
  execSync(`open -a "${appPath}" --args --preview-mode`, { timeout: 10000 });

  // Monitor the app's output by checking its log
  log('App launched with --preview-mode via open command');

  // Also get the PID so we can track it
  try {
    const pid = execSync('pgrep -f "EzLander.*--preview-mode"', { encoding: 'utf8' }).trim();
    log(`App PID: ${pid}`);
  } catch (_) {}

  return true;
}

// ---------------------------------------------------------------------------
// Screenshot capture
// ---------------------------------------------------------------------------

function captureScreenshot() {
  return new Promise((resolve, reject) => {
    const outPath = path.join(SCREENSHOTS_DIR, 'latest.png');
    exec(`bash "${CAPTURE_SCRIPT}" "${outPath}"`, { timeout: 10000 }, (err, stdout, stderr) => {
      if (err) {
        log(`Screenshot capture failed: ${stderr || err.message}`);
        return reject(err);
      }
      if (fs.existsSync(outPath)) {
        lastUpdateTime = timestamp();
        broadcast({ type: 'screenshot', ts: lastUpdateTime });
        resolve(outPath);
      } else {
        log('Screenshot file not created.');
        reject(new Error('Screenshot file not created'));
      }
    });
  });
}

function startCaptureLoop() {
  stopCaptureLoop();
  log('Starting screenshot capture loop (every 2s).');
  captureTimer = setInterval(async () => {
    if (captureInProgress) return;
    captureInProgress = true;
    try {
      await captureScreenshot();
    } catch (_) {
      // logged inside captureScreenshot
    } finally {
      captureInProgress = false;
    }
  }, CAPTURE_INTERVAL_MS);
}

function stopCaptureLoop() {
  if (captureTimer) {
    clearInterval(captureTimer);
    captureTimer = null;
  }
  captureInProgress = false;
}

// ---------------------------------------------------------------------------
// Full pipeline: build -> launch -> capture
// ---------------------------------------------------------------------------

async function fullPipeline() {
  stopCaptureLoop();
  try {
    await runBuild();
    const launched = launchApp();
    if (!launched) {
      throw new Error('Failed to launch EzLander app');
    }
    // Give the app a moment to render
    await new Promise((r) => setTimeout(r, 2000));
    setStatus('capturing');
    await captureScreenshot();
    startCaptureLoop();
    setStatus('idle');
  } catch (err) {
    const message = err && err.message ? err.message : String(err || 'Unknown pipeline error');
    if (buildStatus !== 'error') {
      setStatus('error', message);
    }
    log(`Pipeline failed: ${message}`);
  }
}

// ---------------------------------------------------------------------------
// File watcher
// ---------------------------------------------------------------------------

function setupWatcher() {
  if (fileWatcher) return;
  fileWatcher = chokidar.watch(MACOS_APP_DIR, {
    ignored: [
      /\.build/,
      /DerivedData/,
      /node_modules/,
      /\.git/,
      /\.DS_Store/,
    ],
    persistent: true,
    ignoreInitial: true,
  });

  fileWatcher.on('change', (filePath) => {
    if (!filePath.endsWith('.swift')) return;
    const relative = path.relative(MACOS_APP_DIR, filePath);
    log(`File changed: ${relative}`);
    debouncedRebuild();
  });

  fileWatcher.on('add', (filePath) => {
    if (!filePath.endsWith('.swift')) return;
    const relative = path.relative(MACOS_APP_DIR, filePath);
    log(`File added: ${relative}`);
    debouncedRebuild();
  });

  fileWatcher.on('unlink', (filePath) => {
    if (!filePath.endsWith('.swift')) return;
    const relative = path.relative(MACOS_APP_DIR, filePath);
    log(`File removed: ${relative}`);
    debouncedRebuild();
  });

  log('Watching for .swift file changes in macos-app/');
}

function debouncedRebuild() {
  if (debounceTimer) {
    clearTimeout(debounceTimer);
  }
  debounceTimer = setTimeout(() => {
    debounceTimer = null;
    fullPipeline();
  }, DEBOUNCE_MS);
}

// ---------------------------------------------------------------------------
// Express + WebSocket server
// ---------------------------------------------------------------------------

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// Serve dashboard
app.get('/', (_req, res) => {
  res.sendFile(DASHBOARD_PATH);
});

// Serve screenshots
app.use('/screenshots', express.static(SCREENSHOTS_DIR));

// API: status
app.get('/api/status', (_req, res) => {
  res.json({
    status: buildStatus,
    lastUpdate: lastUpdateTime,
    error: lastBuildError,
    clients: wss.clients.size,
    log: activityLog,
  });
});

// API: manual rebuild
app.post('/api/rebuild', (_req, res) => {
  log('Manual rebuild triggered.');
  fullPipeline();
  res.json({ ok: true, message: 'Rebuild triggered' });
});

// API: manual capture
app.post('/api/capture', async (_req, res) => {
  log('Manual capture triggered.');
  try {
    await captureScreenshot();
    res.json({ ok: true, message: 'Screenshot captured' });
  } catch (err) {
    res.status(500).json({ ok: false, message: err.message });
  }
});

// WebSocket connections
wss.on('connection', (ws) => {
  log(`WebSocket client connected (total: ${wss.clients.size})`);

  // Send current state to newly connected client
  ws.send(
    JSON.stringify({
      type: 'init',
      status: buildStatus,
      lastUpdate: lastUpdateTime,
      error: lastBuildError,
      clients: wss.clients.size,
      log: activityLog,
    })
  );

  ws.on('close', () => {
    log(`WebSocket client disconnected (total: ${wss.clients.size})`);
  });
});

// ---------------------------------------------------------------------------
// Graceful shutdown
// ---------------------------------------------------------------------------

function cleanup() {
  if (isShuttingDown) return;
  isShuttingDown = true;
  log('Shutting down...');
  stopCaptureLoop();
  if (debounceTimer) {
    clearTimeout(debounceTimer);
    debounceTimer = null;
  }
  if (fileWatcher) {
    fileWatcher.close().catch((err) => {
      log(`Watcher close error: ${err && err.message ? err.message : String(err)}`);
    });
    fileWatcher = null;
  }
  killApp();
  wss.clients.forEach((client) => client.close());
  wss.close();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 1000).unref();
}

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

server.listen(PORT, () => {
  log(`Preview server running at http://localhost:${PORT}`);
  log(`Dashboard: http://localhost:${PORT}/`);
  setupWatcher();

  // Optionally run an initial build+launch
  log('Running initial build pipeline...');
  fullPipeline();
});
