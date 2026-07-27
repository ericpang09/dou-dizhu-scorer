// 簡單 build：將 web assets 複製到 www/
const fs = require('fs');
const path = require('path');

const SRC = __dirname;
const DEST = path.join(__dirname, 'www');

function copyRecursive(src, dest, ignore = []) {
  if (!fs.existsSync(src)) return;
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    if (ignore.includes(path.basename(src))) return;
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src)) {
      copyRecursive(path.join(src, entry), path.join(dest, entry), ignore);
    }
  } else {
    if (ignore.includes(path.basename(src))) return;
    fs.copyFileSync(src, dest);
  }
}

// 清空舊 www
fs.rmSync(DEST, { recursive: true, force: true });
fs.mkdirSync(DEST, { recursive: true });

// 複製 web assets（排除 native 開發用嘅嘢）
copyRecursive(SRC, DEST, ['node_modules', 'www', 'android', 'ios', '.git', '.vercel']);
console.log('✓ Web assets 複製到 www/');
