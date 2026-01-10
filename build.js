const JavaScriptObfuscator = require('javascript-obfuscator');
const { minify: minifyHTML } = require('html-minifier-terser');
const fs = require('fs');
const path = require('path');

(async () => {
    console.log('🔒 Bắt đầu build & bảo vệ resource...\n');

    const buildDir = path.join(__dirname, 'build');
    const buildHtmlDir = path.join(buildDir, 'html');

    fs.mkdirSync(buildDir, { recursive: true });
    fs.mkdirSync(buildHtmlDir, { recursive: true });

    // Copy server & client
    console.log('📁 Copy server & client...');
    const copyDir = (src, dest) => {
        if (!fs.existsSync(dest)) fs.mkdirSync(dest, { recursive: true });
        const entries = fs.readdirSync(src, { withFileTypes: true });
        for (const entry of entries) {
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

    // Copy assets
    ['images', 'sounds'].forEach(folder => {
        const src = path.join(__dirname, 'html', folder);
        if (fs.existsSync(src)) {
            copyDir(src, path.join(buildHtmlDir, folder));
        }
    });

    // Obfuscate JS
    console.log('🔐 Obfuscating script.js...');
    const scriptContent = fs.readFileSync(path.join(__dirname, 'html', 'script.js'), 'utf8');

    const obfuscationResult = JavaScriptObfuscator.obfuscate(scriptContent, {
        compact: true,
        controlFlowFlattening: true,
        controlFlowFlatteningThreshold: 0.65,
        deadCodeInjection: true,
        deadCodeInjectionThreshold: 0.35,
        debugProtection: false,
        disableConsoleOutput: true,
        identifierNamesGenerator: 'hexadecimal',
        numbersToExpressions: true,
        renameGlobals: false,
        selfDefending: true,
        simplify: true,
        splitStrings: true,
        splitStringsChunkLength: 8,
        stringArray: true,
        stringArrayCallsTransform: true,
        stringArrayCallsTransformThreshold: 0.75,
        stringArrayEncoding: ['base64'],
        stringArrayIndexShift: true,
        stringArrayRotate: true,
        stringArrayShuffle: true,
        stringArrayWrappersCount: 2,
        stringArrayWrappersChainedCalls: true,
        stringArrayWrappersParametersMaxCount: 5,
        stringArrayWrappersType: 'function',
        stringArrayThreshold: 0.8,
        transformObjectKeys: true,
        unicodeEscapeSequence: false,
        preset: 'high-obfuscation',
    });

    const obfuscatedJS = obfuscationResult.getObfuscatedCode();

    // Minify CSS - AN TOÀN VỚI CALC()
    console.log('📦 Minifying style.css (safe for calc & layout)...');
    let cssContent = fs.readFileSync(path.join(__dirname, 'html', 'style.css'), 'utf8');

    // Bước 1: Xóa comment
    cssContent = cssContent.replace(/\/\*[\s\S]*?\*\//g, '');

    // Bước 2: Giảm space thừa nhưng KHÔNG động mạnh vào calc
    cssContent = cssContent
        .replace(/[\n\r\t\f\v]+/g, ' ')                    // xuống dòng → space
        .replace(/\s*([{};,()])\s*/g, '$1')                // space quanh {},;()
        .replace(/;}/g, '}')                               // xóa ; thừa trước }
        .replace(/\s+/g, ' ')                              // nhiều space → 1 space
        .trim();

    // Bước 3: Bảo vệ và sửa space trong mọi hàm calc()
    cssContent = cssContent.replace(/calc\(([^)]+)\)/gi, (match, inner) => {
        let fixed = inner
            // Đảm bảo space quanh + - * /
            .replace(/([+\-*\/])/g, ' $1 ')
            // Dọn space thừa (nhiều space liên tiếp)
            .replace(/\s+/g, ' ')
            .trim();
        return `calc(${fixed})`;
    });

    // Inline CSS + JS
    console.log('🔗 Inlining CSS & obfuscated JS...');
    let htmlContent = fs.readFileSync(path.join(__dirname, 'html', 'index.html'), 'utf8');

    htmlContent = htmlContent.replace(
        /<link[^>]*rel=["']stylesheet["'][^>]*href=["']style\.css["'][^>]*>/gi,
        `<style>${cssContent}</style>`
    );

    htmlContent = htmlContent.replace(
        /<script[^>]*src=["']script\.js["'][^>]*><\/script>/gi,
        `<script>${obfuscatedJS}</script>`
    );

    // Minify HTML - SAFE MODE (giống gốc gần 100%)
    console.log('📦 Minifying HTML - SAFE MODE (giữ layout & calc)...');
    const minifiedHTML = await minifyHTML(htmlContent, {
        collapseWhitespace: false,          // TẮT để giữ space giữa thẻ → panel không bị đè
        conservativeCollapse: false,
        collapseInlineTagWhitespace: false,
        preserveLineBreaks: true,
        removeComments: true,
        removeRedundantAttributes: true,
        removeScriptTypeAttributes: true,
        removeStyleLinkTypeAttributes: true,
        minifyCSS: false,          // Đã xử lý tay
        minifyJS: false,
        useShortDoctype: true,
        removeEmptyAttributes: true,
        collapseBooleanAttributes: true,
        sortAttributes: false,
        sortClassName: false,
        caseSensitive: true,
        keepClosingSlash: true
    });

    fs.writeFileSync(path.join(buildHtmlDir, 'index.html'), minifiedHTML);

    // Xóa file thừa
    ['script.js', 'style.css'].forEach(file => {
        const p = path.join(buildHtmlDir, file);
        if (fs.existsSync(p)) fs.unlinkSync(p);
    });

    // Copy fxmanifest
    console.log('📋 Copy fxmanifest.lua...');
    fs.copyFileSync(
        path.join(__dirname, 'fxmanifest.lua'),
        path.join(buildDir, 'fxmanifest.lua')
    );

    // README
    const readmeContent = `# F17 Câu Tôm Tích - Production Build (Obfuscated & Layout-Safe)

⚠️ ĐÃ BẢO VỆ MẠNH + GIỮ LAYOUT & CALC() GẦN NHƯ GỐC 100%
• JS obfuscate cao
• CSS inline với calc() được bảo vệ
• HTML minify an toàn (không phá panel/ul/flex/calc)
• Chỉ còn 1 file index.html

Cách dùng:
1. Sửa code gốc
2. npm run build
3. Upload thư mục build lên server FiveM

Build lúc: ${new Date().toLocaleString('vi-VN')}
`;

    fs.writeFileSync(path.join(buildDir, 'README.md'), readmeContent);

    console.log('\n' + '='.repeat(70));
    console.log('✅ BUILD HOÀN TẤT - LAYOUT & CALC() AN TOÀN!');
    console.log('📂 Vị trí: ' + buildDir);
    console.log('• Kiểm tra trong CEF browser FiveM');
    console.log('• left: calc(...) giờ đã có space đúng');
    console.log('='.repeat(70) + '\n');
})();