// Runs only the existing emulator against an explicitly synthetic LOCAL account.
// The private fixture is transferred over stdin into debuggable app-private files.
const fs = require('fs'), cp = require('child_process'), path = require('path');
const file = process.argv[2];
const fixture = JSON.parse(fs.readFileSync(file, 'utf8'));
const config = JSON.parse(fs.readFileSync('config/backend.auth-test.local.json', 'utf8').replace(/^\uFEFF/, ''));
if (config.SUPABASE_URL !== 'http://127.0.0.1:55321' ||
    !/^task07-writer-\d+@example.test$/.test(fixture.email) ||
    !/^[A-Za-z0-9_-]{24,}$/.test(fixture.password)) {
  throw Error('Synthetic isolated local fixture required');
}
const adb = path.join(process.env.LOCALAPPDATA, 'Android/Sdk/platform-tools/adb.exe');
const pkg = 'com.msgi.nexus.msgi_nexus';
const run = (...args) => cp.execFileSync(adb, ['-s', 'emulator-5554', ...args], {
  encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000,
});
try {
  if (run('get-state').trim() !== 'device') throw Error('Emulator unavailable');
  run('reverse', 'tcp:55321', 'tcp:55321');
  run('reverse', 'tcp:55324', 'tcp:55324');
  // flutter test removes its APK after a run. Reinstall before staging privately.
  run('install', '-r', path.resolve('build/app/outputs/flutter-apk/app-debug.apk'));
  run('shell', 'run-as', pkg, 'mkdir', '-p', 'files');
  cp.execFileSync(adb, ['-s', 'emulator-5554', 'shell', 'run-as', pkg,
    'sh', '-c', "'cat > files/task08-auth-fixture.json'"], {
    input: JSON.stringify(fixture), stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000,
  });
  console.log('Private synthetic fixture staged; local Flutter integration test starting.');
  const result = cp.spawnSync('cmd.exe', ['/d', '/c',
    'flutter test integration_test/gateway_auth_test.dart -d emulator-5554 --no-pub --dart-define=LOCAL_AUTH_TESTING=true --dart-define-from-file=config/backend.auth-test.local.json > build/task08-auth-test.log 2>&1'],
  { stdio: 'pipe', timeout: 600000 });
  if (result.status !== 0) throw Error('Local emulator test failed');
  const logs = run('logcat', '-d', '-s', 'flutter:I');
  if (logs.includes(fixture.password) || /access_token=|refresh_token=/.test(logs)) {
    throw Error('Sensitive diagnostic pattern');
  }
  if (/RenderFlex overflowed|Unhandled Exception/.test(logs)) {
    throw Error('Rendering/runtime error in sampled logs');
  }
  fs.unlinkSync(file);
  console.log('PASS: Real local gateway login, demo isolation, persisted real session, cold recovery handoff, password update and login.');
  console.log('PASS: No credential, token, overflow or unhandled-exception patterns in sampled Flutter logs.');
  console.log('Private synthetic fixture removed.');
} catch {
  console.error('LOCAL_EMULATOR_ACCEPTANCE_FAILED; inspect build/task08-auth-test.log locally. Private details suppressed.');
  process.exitCode = 1;
}
