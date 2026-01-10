const JavaScriptObfuscator = require('javascript-obfuscator');
const fs = require('fs');
const path = require('path');

console.log('🔒 Bắt đầu obfuscate code...\n');

// Tạo thư mục build nếu chưa có
const buildDir = path.join(__dirname, 'build');
if (!fs.existsSync(buildDir)) {
    fs.mkdirSync(buildDir);
}

// Tạo thư mục build/html
const buildHtmlDir = path.join(buildDir, 'html');
if (!fs.existsSync(buildHtmlDir)) {
    fs.mkdirSync(buildHtmlDir);
}

// Copy server và client (không cần obfuscate Lua)
console.log('📁 Copy server và client files...');
const copyDir = (src, dest) => {
    if (!fs.existsSync(dest)) {
        fs.mkdirSync(dest, { recursive: true });
    }
    const entries = fs.readdirSync(src, { withFileTypes: true });
    for (let entry of entries) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        if (entry.isDirectory()) {
            copyDir(srcPath, destPath);
        } else {
            fs.copyFileSync(srcPath, destPath);
        }
    }
};

copyDir(path.join(__dirname, 'server'), path.join(buildDir, 'server'));
copyDir(path.join(__dirname, 'client'), path.join(buildDir, 'client'));

// Copy images và sounds
if (fs.existsSync(path.join(__dirname, 'html', 'images'))) {
    copyDir(path.join(__dirname, 'html', 'images'), path.join(buildHtmlDir, 'images'));
}
if (fs.existsSync(path.join(__dirname, 'html', 'sounds'))) {
    copyDir(path.join(__dirname, 'html', 'sounds'), path.join(buildHtmlDir, 'sounds'));
}

// Obfuscate script.js
console.log('🔐 Obfuscating script.js...');
const scriptContent = fs.readFileSync(path.join(__dirname, 'html', 'script.js'), 'utf8');

const obfuscatedScript = JavaScriptObfuscator.obfuscate(scriptContent, {
    compact: true,
    controlFlowFlattening: true,
    controlFlowFlatteningThreshold: 0.75,
    deadCodeInjection: true,
    deadCodeInjectionThreshold: 0.4,
    debugProtection: false,
    debugProtectionInterval: 0,
    disableConsoleOutput: false,
    identifierNamesGenerator: 'hexadecimal',
    log: false,
    numbersToExpressions: true,
    renameGlobals: false,
    selfDefending: true,
    simplify: true,
    splitStrings: true,
    splitStringsChunkLength: 10,
    stringArray: true,
    stringArrayCallsTransform: true,
    stringArrayEncoding: ['base64'],
    stringArrayIndexShift: true,
    stringArrayRotate: true,
    stringArrayShuffle: true,
    stringArrayWrappersCount: 2,
    stringArrayWrappersChainedCalls: true,
    stringArrayWrappersParametersMaxCount: 4,
    stringArrayWrappersType: 'function',
    stringArrayThreshold: 0.75,
    transformObjectKeys: true,
    unicodeEscapeSequence: false
});

fs.writeFileSync(
    path.join(buildHtmlDir, 'script.js'),
    obfuscatedScript.getObfuscatedCode()
);

// Minify CSS
console.log('📦 Minifying style.css...');
const cssContent = fs.readFileSync(path.join(__dirname, 'html', 'style.css'), 'utf8');
const minifiedCss = cssContent
    .replace(/\/\*[\s\S]*?\*\//g, '') // Remove comments
    .replace(/\s+/g, ' ') // Remove extra whitespace
    .replace(/\s*([{}:;,])\s*/g, '$1') // Remove space around special chars
    .trim();

fs.writeFileSync(path.join(buildHtmlDir, 'style.css'), minifiedCss);

// Copy index.html
console.log('📄 Copying index.html...');
fs.copyFileSync(
    path.join(__dirname, 'html', 'index.html'),
    path.join(buildHtmlDir, 'index.html')
);

// Copy fxmanifest.lua
console.log('📋 Copying fxmanifest.lua...');
fs.copyFileSync(
    path.join(__dirname, 'fxmanifest.lua'),
    path.join(buildDir, 'fxmanifest.lua')
);

// Tạo README trong build
const readme = `# F17 Câu Tôm Tích - Production Build

⚠️ ĐÂY LÀ PHIÊN BẢN ĐÃ OBFUSCATE
- Code JavaScript đã được bảo vệ
- Không chỉnh sửa trực tiếp trong thư mục này
- Để phát triển, sửa code ở thư mục gốc rồi chạy: npm run build

📁 Upload toàn bộ thư mục này lên server FiveM
`;

fs.writeFileSync(path.join(buildDir, 'README.md'), readme);

console.log('\n✅ Build hoàn tất!');
console.log('📁 Thư mục build đã sẵn sàng tại: ./build/');
console.log('🚀 Upload thư mục "build" lên FileZilla!');
console.log('\n📊 Thống kê:');
console.log('   - script.js: Đã obfuscate ✓');
console.log('   - style.css: Đã minify ✓');
console.log('   - Server/Client: Đã copy ✓');
console.log('   - Assets: Đã copy ✓');
