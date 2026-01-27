// ============================================
// VUE.JS APP - Câu Tôm Tích
// ============================================

const { createApp, ref, onMounted, onBeforeUnmount } = Vue;

// ============================================
// CONSTANTS & SOUNDS
// ============================================
// Sound objects will be initialized in updateConfig
let SOUNDS = {
    win: null, lose: null, ocean: null, reelIn: null, shrimpPull: null, tension: null
};

// ============================================
// ROOT APP
// ============================================
const app = createApp({
    setup() {
        // App State
        const tomtichVisible = ref(false);
        const gamePhase = ref('IDLE'); // IDLE, TUNNEL_NAV, DROPPING, FISHING, RESULT
        const tomtichStatus = ref('Sẵn sàng'); // Legacy UI status if needed
        const resultMessage = ref('');
        const tomtichResultSuccess = ref(false);

        // TUNNEL NAV STATE
        const showTunnelInstruction = ref(true);
        const tunnelCanvas = ref(null);
        const tunnelCompleted = ref(false); // Validates tunnel pass
        const tunnelMessage = ref('');
        const tunnelProgress = ref(0);
        const tunnelSpeed = ref(0); // For UI display
        const tunnelCollisionWarning = ref(false); // Warning when near wall
        const tunnelCombo = ref(0); // Combo for staying in center

        // TREASURE HUNT STATE
        const treasureVisible = ref(false);
        const treasureCells = ref([]);
        const treasureAttempts = ref(5);
        const treasureFound = ref(0);
        const treasureHint = ref('');
        const treasureGameEnded = ref(false);
        const treasureSuccess = ref(false);
        const treasureResultMessage = ref('');
        const treasurePositions = ref([]); // Local treasure positions
        const treasureOpenedIndices = ref([]); // Track opened cells


        // Game Configuration (Will be synced from Lua)
        const uiConfig = ref(null);

        // Dynamic Shrimp Types (will be generated from Config)
        const shrimpTypesByLevel = ref({});

        // Player level (will be received from server)
        const playerLevel = ref(1);

        // Game State
        const currentShrimp = ref(null);
        const currentShrimpImage = ref('');

        // Tension system
        const tensionLevel = ref(50);
        const catchProgress = ref(0);
        const timeRemaining = ref(30);
        const isHoldingSpace = ref(false);

        // Visual effects
        const fishingLineHeight = ref(100);
        const shrimpPosition = ref(80);
        const shrimpPulling = ref(false);
        const shrimpResistance = ref(0.5);

        // Animation Frames & Time
        let tomtichAnimationFrame = null;
        let lastUpdateTime = 0;
        let gameStartTime = 0;

        // Constants (Updated via updateConfig)
        let TENSION_SAFE_MIN = 30;
        let TENSION_SAFE_MAX = 70;
        let GAME_TIME_LIMIT = 30000;
        let CATCH_DURATION = 20000;
        let PULL_INTERVAL_MIN = 2000;
        let PULL_INTERVAL_MAX = 4000;

        let TUNNEL_TOTAL_DEPTH = 5000;
        let TUNNEL_PATH_WIDTH = 130;
        let TUNNEL_WARNING_DIST = 20;
        let TUNNEL_MAX_SPEED = 3.0;
        let TUNNEL_ACCEL = 0.1;
        let TUNNEL_FRICTION = 0.2;
        let TUNNEL_RETRACT_SPEED = 8;
        let TUNNEL_LERP_SPEED = 0.25;
        let TUNNEL_SWAY = 80;

        let DROP_SPEED = 40;
        let DROP_RETRACT_SPEED = 60;

        let WAIT_MIN = 5000;
        let WAIT_RAND = 3000;
        let BITE_WINDOW = 2000;

        let TENSION_INC_HOLD = 35;
        let TENSION_DEC_REL = 25;
        let RESISTANCE_BASE = 15;
        let PROGRESS_DEC_RATE = 50;
        let FAIL_TENSION_MAX = 95;
        let FAIL_TENSION_MIN = 5;
        let WARN_THRESHOLD_HI = 85;
        let WARN_THRESHOLD_LO = 15;

        // Sound Helper
        const stopAllSounds = () => {
            if (SOUNDS.ocean) { SOUNDS.ocean.pause(); SOUNDS.ocean.currentTime = 0; }
            if (SOUNDS.reelIn) { SOUNDS.reelIn.pause(); SOUNDS.reelIn.currentTime = 0; }
            if (SOUNDS.tension) { SOUNDS.tension.pause(); SOUNDS.tension.currentTime = 0; }
            if (SOUNDS.shrimpPull) { SOUNDS.shrimpPull.pause(); SOUNDS.shrimpPull.currentTime = 0; }
        };

        // ============================================
        // LOGIC
        // ============================================

        const closeGameUI = () => {
            tomtichVisible.value = false;
            gamePhase.value = 'IDLE';
            resetGameState();
            stopAllSounds();
        };

        const handleTomTichClose = () => {
            closeGameUI();
            fetch(`https://${getParentResourceName()}/closeTomTich`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        };

        const resetGameState = () => {
            tensionLevel.value = 50;
            catchProgress.value = 0;
            timeRemaining.value = 30;
            fishingLineHeight.value = 0; // Start at 0 for drop phase
            shrimpPosition.value = 50;
            shrimpPulling.value = false;
            isHoldingSpace.value = false;
            resultMessage.value = '';

            if (tomtichAnimationFrame) {
                cancelAnimationFrame(tomtichAnimationFrame);
                tomtichAnimationFrame = null;
            }

            // Cleanup Tunnel
            cleanupTunnelGame();
            tunnelCompleted.value = false;
        };

        // ============================================
        // PHASE 0: TUNNEL NAVIGATION (New)
        // ============================================
        let tunnelCtx = null;
        let tunnelState = {
            active: false,
            path: [],
            hookX: 0,
            hookY: 0,
            depth: 0, // distance travelled
            linePoints: [], // trail
            speed: 0,
            maxSpeed: 3.5, // Tăng tốc độ rơi
            cameraY: 0,
            mouseX: 0,
            isMouseDown: false
        };

        // Configuration
        const TUNNEL_WIDTH = 450;
        const PATH_WIDTH = 130; // Hẹp hơn để khó hơn (giảm từ 140 xuống 100)
        const TOTAL_DEPTH = 5000;
        const WARNING_DISTANCE = 20; // Distance from wall to show warning

        const initTunnelGame = () => {
            // Wait for DOM
            setTimeout(() => {
                const canvas = tunnelCanvas.value;
                if (!canvas) return;

                // Adjust to container size
                canvas.width = canvas.parentElement.clientWidth;
                canvas.height = canvas.parentElement.clientHeight;

                tunnelCtx = canvas.getContext('2d');
                const width = canvas.width;

                // Reset State
                tunnelState = {
                    active: true,
                    path: generateTunnelPath(TUNNEL_TOTAL_DEPTH + canvas.height, width),
                    hookX: width / 2,
                    hookY: 100,
                    hookVelocityX: 0, // Vận tốc ngang của móc
                    depth: 0,
                    linePoints: [],
                    speed: 0,
                    maxSpeed: TUNNEL_MAX_SPEED,
                    acceleration: TUNNEL_ACCEL,
                    friction: TUNNEL_FRICTION,
                    cameraY: 0,
                    mouseX: width / 2,
                    targetX: width / 2, // Target position với smoothing
                    isMouseDown: false,
                    particles: [],
                    shake: 0,
                    combo: 0,
                    comboTimer: 0,
                    isRetracting: false,
                    retractSpeed: TUNNEL_RETRACT_SPEED
                };

                showTunnelInstruction.value = true;

                // Không tự động ẩn - hiển thị cố định
                // setTimeout(() => {
                //     showTunnelInstruction.value = false;
                // }, 5000);

                // Add Listeners
                canvas.addEventListener('mousemove', onTunnelMouseMove);
                canvas.addEventListener('mousedown', onTunnelMouseDown);
                canvas.addEventListener('mouseup', onTunnelMouseUp);

                // Start Loop
                tunnelLoop();
            }, 100);
        };

        const cleanupTunnelGame = () => {
            tunnelState.active = false;
            const canvas = document.getElementById('tunnelCanvas'); // Direct access fallback
            if (canvas) {
                canvas.removeEventListener('mousemove', onTunnelMouseMove);
                canvas.removeEventListener('mousedown', onTunnelMouseDown);
                canvas.removeEventListener('mouseup', onTunnelMouseUp);
            }
        };

        const generateTunnelPath = (length, screenWidth) => {
            const points = [];
            let currentX = screenWidth / 2;

            for (let y = 0; y < length; y += 20) {
                // Random sway với độ cong CỰC LỚN - đi thẳng chắc chắn đụng
                const change = (Math.random() - 0.5) * TUNNEL_SWAY;
                currentX += change;

                // Clamp to keep on screen
                const margin = TUNNEL_PATH_WIDTH / 2 + 80;
                currentX = Math.max(margin, Math.min(screenWidth - margin, currentX));

                points.push({
                    y,
                    x: currentX,
                    width: TUNNEL_PATH_WIDTH + Math.sin(y * 0.01) * 15 // Varying width ít hơn vì đã hẹp
                });
            }
            return points;
        };

        const onTunnelMouseMove = (e) => {
            if (!tunnelCanvas.value) return;
            const rect = tunnelCanvas.value.getBoundingClientRect();
            // Tăng smooth cho mouse input - mượt hơn
            const rawMouseX = e.clientX - rect.left;
            tunnelState.targetX += (rawMouseX - tunnelState.targetX) * 0.4; // Tăng từ 0.3
        };
        const onTunnelMouseDown = () => { tunnelState.isMouseDown = true; };
        const onTunnelMouseUp = () => { tunnelState.isMouseDown = false; };

        const tunnelLoop = () => {
            if (!tunnelState.active || gamePhase.value !== 'TUNNEL_NAV') return;

            const now = performance.now();
            const deltaTime = 1 / 60; // Fixed timestep for consistency

            // === RETRACT MODE (Thu dây sau khi đụng) ===
            if (tunnelState.isRetracting) {
                tunnelState.depth -= tunnelState.retractSpeed;
                tunnelState.cameraY = tunnelState.depth;
                tunnelProgress.value = Math.max(0, (tunnelState.depth / TUNNEL_TOTAL_DEPTH) * 100);

                // Khi về đến đầu
                if (tunnelState.depth <= 0) {
                    tunnelState.depth = 0;
                    tunnelState.isRetracting = false;
                    tunnelState.speed = 0;
                    tunnelMessage.value = '';
                }

                // Render và tiếp tục loop
                updateParticles(deltaTime);
                renderTunnel();
                requestAnimationFrame(tunnelLoop);
                return;
            }

            // === PHYSICS ===
            if (tunnelState.isMouseDown) {
                tunnelState.speed = Math.min(tunnelState.speed + tunnelState.acceleration, tunnelState.maxSpeed);
            } else {
                tunnelState.speed = Math.max(0, tunnelState.speed - tunnelState.friction);
            }

            tunnelState.depth += tunnelState.speed;
            tunnelState.cameraY = tunnelState.depth;

            // Update UI speed display
            tunnelSpeed.value = Math.round((tunnelState.speed / tunnelState.maxSpeed) * 100);

            // Progress calculation
            tunnelProgress.value = Math.min(100, (tunnelState.depth / TUNNEL_TOTAL_DEPTH) * 100);

            // === HOOK MOVEMENT - Direct follow mouse (no physics) ===
            const canvas = tunnelCanvas.value;

            // Móc câu theo chuột trực tiếp với smooth lerp
            const lerpSpeed = TUNNEL_LERP_SPEED; // Tốc độ theo chuột
            tunnelState.hookX += (tunnelState.targetX - tunnelState.hookX) * lerpSpeed;

            // Giới hạn trong canvas
            const margin = 50;
            tunnelState.hookX = Math.max(margin, Math.min(canvas.width - margin, tunnelState.hookX));

            // === COLLISION DETECTION ===
            const absoluteHookY = tunnelState.depth + 150;
            const currentPointIndex = Math.floor(absoluteHookY / 20);
            const currentPoint = tunnelState.path[currentPointIndex] || tunnelState.path[tunnelState.path.length - 1];

            const tunnelCenterX = currentPoint.x;
            const currentPathWidth = currentPoint.width || TUNNEL_PATH_WIDTH;
            const safeHalfWidth = currentPathWidth / 2;
            const distanceFromWall = Math.abs(tunnelState.hookX - tunnelCenterX);

            // Warning zone (near walls)
            if (distanceFromWall > safeHalfWidth - TUNNEL_WARNING_DIST) {
                tunnelCollisionWarning.value = true;
                tunnelCombo.value = 0;
                tunnelState.combo = 0;
            } else {
                tunnelCollisionWarning.value = false;

                // Combo system for staying in center
                if (tunnelState.speed > 2) {
                    tunnelState.comboTimer += deltaTime;
                    if (tunnelState.comboTimer >= 0.5) {
                        tunnelState.combo++;
                        tunnelCombo.value = tunnelState.combo;
                        tunnelState.comboTimer = 0;

                        // Spawn particle effect for combo
                        spawnParticles(tunnelState.hookX, 150, '#4CAF50', 5);
                    }
                }
            }

            // Collision with walls
            if (distanceFromWall > safeHalfWidth) {
                if (tunnelState.depth > 100 && !tunnelState.isRetracting) {
                    // Hit wall - start retracting
                    tunnelState.isRetracting = true;
                    tunnelState.speed = 0;
                    tunnelState.shake = 10;
                    tunnelState.combo = 0;
                    tunnelCombo.value = 0;
                    tunnelCollisionWarning.value = false;
                    tunnelMessage.value = 'Bạn đã đụng hang! Thu dây lại...';
                    SOUNDS.lose.play().catch(() => { });

                    // Spawn collision particles
                    spawnParticles(tunnelState.hookX, 150, '#ff5252', 20);

                    // Auto-hide message after 1 second
                    setTimeout(() => {
                        tunnelMessage.value = '';
                    }, 1000);
                }
            }

            // === WIN CONDITION ===
            if (tunnelState.depth >= TUNNEL_TOTAL_DEPTH) {
                tunnelState.active = false;
                tunnelCompleted.value = true;
                tunnelMessage.value = '✅ Hoàn thành! Chuẩn bị thả câu...';
                SOUNDS.win.play().catch(() => { });

                // Victory particles
                spawnParticles(tunnelState.hookX, 150, '#ffcc00', 30);

                setTimeout(() => {
                    tunnelMessage.value = '';
                    gamePhase.value = 'IDLE';
                }, 1500);

                return;
            }

            // === PARTICLE SYSTEM ===
            updateParticles(deltaTime);

            // === RENDERING ===
            renderTunnel();

            requestAnimationFrame(tunnelLoop);
        };

        // Particle system
        const spawnParticles = (x, y, color, count) => {
            for (let i = 0; i < count; i++) {
                tunnelState.particles.push({
                    x: x,
                    y: y,
                    vx: (Math.random() - 0.5) * 8,
                    vy: (Math.random() - 0.5) * 8,
                    life: 1.0,
                    color: color,
                    size: 2 + Math.random() * 3
                });
            }
        };

        const updateParticles = (deltaTime) => {
            for (let i = tunnelState.particles.length - 1; i >= 0; i--) {
                const p = tunnelState.particles[i];
                p.x += p.vx;
                p.y += p.vy;
                p.vy += 0.3; // Gravity
                p.life -= deltaTime * 2;

                if (p.life <= 0) {
                    tunnelState.particles.splice(i, 1);
                }
            }
        };

        const renderTunnel = () => {
            const ctx = tunnelCtx;
            const canvas = tunnelCanvas.value;
            const w = canvas.width;
            const h = canvas.height;

            // Apply screen shake
            ctx.save();
            if (tunnelState.shake > 0) {
                const shakeX = (Math.random() - 0.5) * tunnelState.shake;
                const shakeY = (Math.random() - 0.5) * tunnelState.shake;
                ctx.translate(shakeX, shakeY);
                tunnelState.shake *= 0.9;
            }

            // 1. Background with gradient
            const bgGradient = ctx.createLinearGradient(0, 0, 0, h);
            bgGradient.addColorStop(0, '#1a1510');
            bgGradient.addColorStop(1, '#0a0805');
            ctx.fillStyle = bgGradient;
            ctx.fillRect(0, 0, w, h);

            // 2. Draw tunnel path with better visuals
            const startIdx = Math.floor(tunnelState.cameraY / 20);
            const endIdx = startIdx + Math.ceil(h / 20) + 2;

            // Draw tunnel walls (darker)
            ctx.lineCap = 'round';
            ctx.lineJoin = 'round';

            // Outer walls (dark)
            for (let i = startIdx; i < endIdx; i++) {
                if (!tunnelState.path[i]) continue;
                const p = tunnelState.path[i];
                const screenY = p.y - tunnelState.cameraY;
                const screenX = p.x;
                const pathWidth = p.width || TUNNEL_PATH_WIDTH;

                // Draw wall shadows
                const wallGradient = ctx.createRadialGradient(screenX, screenY, pathWidth / 2, screenX, screenY, pathWidth / 2 + 30);
                wallGradient.addColorStop(0, 'rgba(62, 48, 32, 0.8)');
                wallGradient.addColorStop(1, 'rgba(26, 21, 16, 1)');

                ctx.fillStyle = wallGradient;
                ctx.beginPath();
                ctx.arc(screenX, screenY, pathWidth / 2 + 30, 0, Math.PI * 2);
                ctx.fill();
            }

            // Draw safe path (lighter)
            ctx.lineWidth = TUNNEL_PATH_WIDTH;
            ctx.strokeStyle = '#3e3020';
            ctx.beginPath();
            let first = true;
            for (let i = startIdx; i < endIdx; i++) {
                if (!tunnelState.path[i]) continue;
                const p = tunnelState.path[i];
                const screenY = p.y - tunnelState.cameraY;
                const screenX = p.x;
                if (first) {
                    ctx.moveTo(screenX, screenY);
                    first = false;
                } else {
                    ctx.lineTo(screenX, screenY);
                }
            }
            ctx.stroke();

            // Draw center guide line (subtle)
            ctx.strokeStyle = 'rgba(255, 204, 0, 0.15)';
            ctx.lineWidth = 2;
            ctx.setLineDash([5, 10]);
            ctx.beginPath();
            first = true;
            for (let i = startIdx; i < endIdx; i++) {
                if (!tunnelState.path[i]) continue;
                const p = tunnelState.path[i];
                const screenY = p.y - tunnelState.cameraY;
                const screenX = p.x;
                if (first) {
                    ctx.moveTo(screenX, screenY);
                    first = false;
                } else {
                    ctx.lineTo(screenX, screenY);
                }
            }
            ctx.stroke();
            ctx.setLineDash([]);

            // 3. Draw fishing line with simple curve
            ctx.strokeStyle = 'rgba(200, 200, 200, 0.8)';
            ctx.lineWidth = 3;
            ctx.shadowColor = 'rgba(255, 255, 255, 0.5)';
            ctx.shadowBlur = 5;

            // Simple bezier curve - không dựa vào velocity
            const hookX = tunnelState.hookX;
            const hookY = 150;
            const topX = w / 2;
            const topY = -100;

            // Control points đơn giản
            const cp1X = hookX;
            const cp1Y = hookY - 50;
            const cp2X = topX + (hookX - topX) * 0.3;
            const cp2Y = topY + 100;

            ctx.beginPath();
            ctx.moveTo(hookX, hookY);
            ctx.bezierCurveTo(cp1X, cp1Y, cp2X, cp2Y, topX, topY);
            ctx.stroke();
            ctx.shadowBlur = 0;

            // 4. Draw hook with glow
            const hookSize = 28;
            ctx.font = `${hookSize}px Arial`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';

            // Glow effect
            if (tunnelCollisionWarning.value) {
                ctx.shadowColor = '#ff5252';
                ctx.shadowBlur = 20;
            } else {
                ctx.shadowColor = '#4CAF50';
                ctx.shadowBlur = 15;
            }

            // Xoay canvas để vẽ con ốc ngược đầu
            ctx.save();
            ctx.translate(tunnelState.hookX, 150);
            ctx.rotate(Math.PI / 4); // Xoay 45 độ
            ctx.fillText('🐚', 0, 0);
            ctx.restore();
            ctx.shadowBlur = 0;

            // 5. Draw particles
            tunnelState.particles.forEach(p => {
                ctx.fillStyle = p.color;
                ctx.globalAlpha = p.life;
                ctx.beginPath();
                ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
                ctx.fill();
            });
            ctx.globalAlpha = 1;

            // 6. Draw speed lines when moving fast
            if (tunnelState.speed > 3) {
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
                ctx.lineWidth = 1;
                for (let i = 0; i < 10; i++) {
                    const x = Math.random() * w;
                    const y = Math.random() * h;
                    const length = 20 + Math.random() * 30;
                    ctx.beginPath();
                    ctx.moveTo(x, y);
                    ctx.lineTo(x, y + length);
                    ctx.stroke();
                }
            }

            // 7. Darkness overlay - Môi trường tối, chỉ sáng ở móc câu
            const darkness = ctx.createRadialGradient(
                tunnelState.hookX, 150, 50,
                tunnelState.hookX, 150, 180
            );
            darkness.addColorStop(0, 'rgba(0, 0, 0, 0)'); // Trong suốt ở giữa
            darkness.addColorStop(0.3, 'rgba(0, 0, 0, 0.7)'); // Bắt đầu tối
            darkness.addColorStop(1, 'rgba(0, 0, 0, 0.98)'); // Rất tối ở xa
            ctx.fillStyle = darkness;
            ctx.fillRect(0, 0, w, h);

            // 8. Lighting around hook - Ánh sáng vàng xung quanh móc
            const lightGradient = ctx.createRadialGradient(
                tunnelState.hookX, 150, 10,
                tunnelState.hookX, 150, 100
            );
            lightGradient.addColorStop(0, 'rgba(255, 204, 0, 0.3)');
            lightGradient.addColorStop(0.5, 'rgba(255, 204, 0, 0.1)');
            lightGradient.addColorStop(1, 'rgba(0, 0, 0, 0)');
            ctx.fillStyle = lightGradient;
            ctx.fillRect(0, 0, w, h);

            ctx.restore();
        };

        // Step 1: User presses Space in IDLE -> Starts Dropping
        const dropDepth = ref(0); // 0-100%

        const startDropLine = () => {
            // Logic: IDLE -> TUNNEL (if not done) -> DROPPING

            if (gamePhase.value === 'IDLE') {
                if (!tunnelCompleted.value) {
                    gamePhase.value = 'TUNNEL_NAV';
                    showTunnelInstruction.value = true;
                    initTunnelGame();
                } else {
                    // Tunnel done, start normal dropping
                    gamePhase.value = 'DROPPING';
                    dropDepth.value = 0;
                    fishingLineHeight.value = 0;
                    SOUNDS.ocean.play().catch(() => { });
                    lastUpdateTime = Date.now();
                    updateDropLoop();
                }
                return;
            }

            // Should not be called in other phases usually
        };

        const updateDropLoop = () => {
            if (gamePhase.value !== 'DROPPING') return;

            const now = Date.now();
            const deltaTime = (now - lastUpdateTime) / 1000;
            lastUpdateTime = now;

            if (isHoldingSpace.value) {
                // Holding = Drop line down
                dropDepth.value += DROP_SPEED * deltaTime;
                if (SOUNDS.reelIn && SOUNDS.reelIn.paused) SOUNDS.reelIn.play().catch(() => { });
            } else {
                // Released = Retract line up
                dropDepth.value -= DROP_RETRACT_SPEED * deltaTime;
                if (SOUNDS.reelIn && !SOUNDS.reelIn.paused) {
                    SOUNDS.reelIn.pause();
                    SOUNDS.reelIn.currentTime = 0;
                }

                if (dropDepth.value <= 0) {
                    // Reset completely if fail to hold
                    dropDepth.value = 0;
                    gamePhase.value = 'IDLE';
                    fishingLineHeight.value = 0;

                    // CRITICAL: User implies "thu lại về đầu" - does this mean redo tunnel?
                    // User requested: "chỉ có cơ chế giữ chuột mới reset lại thôi" -> Don't reset tunnel here.
                    // tunnelCompleted.value = false;

                    if (tomtichAnimationFrame) cancelAnimationFrame(tomtichAnimationFrame);
                    tomtichAnimationFrame = null;
                    return;
                }
            }

            dropDepth.value = Math.max(0, Math.min(100, dropDepth.value));
            fishingLineHeight.value = dropDepth.value;

            if (dropDepth.value >= 100) {
                startWaitingPhase();
                return;
            }

            tomtichAnimationFrame = requestAnimationFrame(updateDropLoop);
        };

        // PHASE: WAITING (Hold Space 5-8s)
        const waitTimer = ref(0);

        const startWaitingPhase = () => {
            gamePhase.value = 'WAITING';
            // Random wait from config
            waitTimer.value = WAIT_MIN + Math.random() * WAIT_RAND;
            lastUpdateTime = Date.now();

            // Stop reel sound
            if (SOUNDS.reelIn && !SOUNDS.reelIn.paused) {
                SOUNDS.reelIn.pause();
                SOUNDS.reelIn.currentTime = 0;
            }

            updateWaitLoop();
        };

        const updateWaitLoop = () => {
            if (gamePhase.value !== 'WAITING') return;

            const now = Date.now();
            const deltaTime = (now - lastUpdateTime); // ms
            lastUpdateTime = now;

            // Rule: Must HOLD Space
            if (!isHoldingSpace.value) {
                // Failed: Released too early -> Retract
                gamePhase.value = 'DROPPING';
                dropDepth.value = 99; // Slightly up
                updateDropLoop();
                return;
            }

            waitTimer.value -= deltaTime;
            if (waitTimer.value <= 0) {
                startBitingPhase();
                return;
            }

            tomtichAnimationFrame = requestAnimationFrame(updateWaitLoop);
        };

        // PHASE: BITING (Release Space within 2s)
        const biteTimer = ref(0);

        const startBitingPhase = () => {
            gamePhase.value = 'BITING';
            biteTimer.value = BITE_WINDOW; // Time window from config
            shrimpPulling.value = true; // Shake effect

            // Play urgent sound
            SOUNDS.shrimpPull.currentTime = 0;
            SOUNDS.shrimpPull.play().catch(() => { });

            // Play tension sound for urgency
            if (SOUNDS.tension && SOUNDS.tension.paused) {
                SOUNDS.tension.currentTime = 0;
                SOUNDS.tension.play().catch(() => { });
            }

            lastUpdateTime = Date.now();
            updateBiteLoop();
        };

        const updateBiteLoop = () => {
            if (gamePhase.value !== 'BITING') return;

            const now = Date.now();
            const deltaTime = (now - lastUpdateTime); // ms
            lastUpdateTime = now;

            // Check Input: Released Space?
            if (!isHoldingSpace.value) {
                // Success! Hooked!
                shrimpPulling.value = false;

                // Stop tension sound
                if (SOUNDS.tension && !SOUNDS.tension.paused) {
                    SOUNDS.tension.pause();
                    SOUNDS.tension.currentTime = 0;
                }

                startFishingPhase();
                return;
            }

            biteTimer.value -= deltaTime;
            if (biteTimer.value <= 0) {
                // Failed: Too slow / Didn't release -> Lose
                shrimpPulling.value = false;

                // Stop tension sound
                if (SOUNDS.tension && !SOUNDS.tension.paused) {
                    SOUNDS.tension.pause();
                    SOUNDS.tension.currentTime = 0;
                }

                endTomTichGame(false, 'Tôm đã thoát! (Phản xạ chậm)');
                return;
            }

            tomtichAnimationFrame = requestAnimationFrame(updateBiteLoop);
        };

        // Step 2: Dropping finished -> Hook set -> Select Shrimp -> Start Minigame
        const startFishingPhase = () => {
            gamePhase.value = 'FISHING';
            resetGameState();
            fishingLineHeight.value = 100; // Force full line for game start

            // Stop drop sound
            if (!SOUNDS.reelIn.paused) {
                SOUNDS.reelIn.pause();
                SOUNDS.reelIn.currentTime = 0;
            }

            // Random shrimp selection based on dynamic config
            const currentLevel = playerLevel.value;
            const shrimpTypes = shrimpTypesByLevel.value[currentLevel] || (shrimpTypesByLevel.value[1] || []);

            if (shrimpTypes.length === 0) {
                console.error("No shrimp types defined for level", currentLevel);
                endTomTichGame(false, 'Lỗi cấu hình (Không có tôm)');
                return;
            }

            const rand = Math.random() * 100;
            let cumulative = 0;
            let selected = shrimpTypes[0];

            for (const type of shrimpTypes) {
                cumulative += type.chance;
                if (rand <= cumulative) {
                    selected = type;
                    break;
                }
            }
            currentShrimp.value = selected;
            currentShrimpImage.value = selected.image;

            // Difficulty adjustment based on rarity multipliers in config
            let difficultyMult = 1.0;
            const rarityConfigs = uiConfig.value && uiConfig.value.Fishing ? uiConfig.value.Fishing.rarityMultipliers : {};
            if (rarityConfigs[selected.id]) {
                difficultyMult = rarityConfigs[selected.id];
            }

            shrimpResistance.value = (0.4 + Math.random() * 0.4) * difficultyMult;

            // Start loop
            lastUpdateTime = Date.now();
            gameStartTime = Date.now();
            scheduleShrimpPull();
            updateTensionLoop();

            // Sound effect for hook
            // Maybe play a splash or "bite" sound here?
            SOUNDS.shrimpPull.play().catch(() => { });
        };

        const scheduleShrimpPull = () => {
            if (gamePhase.value !== 'FISHING') return;

            const nextPullTime = PULL_INTERVAL_MIN + Math.random() * (PULL_INTERVAL_MAX - PULL_INTERVAL_MIN);

            setTimeout(() => {
                if (gamePhase.value === 'FISHING') {
                    triggerShrimpPull();
                    scheduleShrimpPull();
                }
            }, nextPullTime);
        };

        const triggerShrimpPull = () => {
            shrimpPulling.value = true;
            SOUNDS.shrimpPull.currentTime = 0;
            SOUNDS.shrimpPull.play().catch(() => { });
            tensionLevel.value = Math.min(tensionLevel.value + 15 + Math.random() * 15, 95);
            setTimeout(() => { shrimpPulling.value = false; }, 800);
        };

        const updateTensionLoop = () => {
            if (gamePhase.value !== 'FISHING') return;

            const now = Date.now();
            const deltaTime = (now - lastUpdateTime) / 1000;
            lastUpdateTime = now;

            const elapsed = (now - gameStartTime) / 1000;
            timeRemaining.value = Math.max(0, 30 - elapsed);

            // Control physics
            if (isHoldingSpace.value) {
                tensionLevel.value += TENSION_INC_HOLD * deltaTime;
                if (SOUNDS.reelIn && SOUNDS.reelIn.paused) SOUNDS.reelIn.play().catch(() => { });
            } else {
                tensionLevel.value -= TENSION_DEC_REL * deltaTime;
                if (SOUNDS.reelIn && !SOUNDS.reelIn.paused) {
                    SOUNDS.reelIn.pause();
                    SOUNDS.reelIn.currentTime = 0;
                }
            }

            // Resistance
            tensionLevel.value -= shrimpResistance.value * RESISTANCE_BASE * deltaTime;
            tensionLevel.value = Math.max(0, Math.min(100, tensionLevel.value));

            // Sound warning
            if (tensionLevel.value >= WARN_THRESHOLD_HI || tensionLevel.value <= WARN_THRESHOLD_LO) {
                if (SOUNDS.tension && SOUNDS.tension.paused) SOUNDS.tension.play().catch(() => { });
            } else {
                if (SOUNDS.tension && !SOUNDS.tension.paused) {
                    SOUNDS.tension.pause();
                    SOUNDS.tension.currentTime = 0;
                }
            }

            // Visuals
            shrimpPosition.value = 20 + (tensionLevel.value * 0.6);
            fishingLineHeight.value = shrimpPosition.value + 10;

            if (tensionLevel.value >= TENSION_SAFE_MIN && tensionLevel.value <= TENSION_SAFE_MAX) {
                catchProgress.value += 100 / (CATCH_DURATION / 1000) * deltaTime;
            } else {
                catchProgress.value -= PROGRESS_DEC_RATE / (CATCH_DURATION / 1000) * deltaTime;
            }
            catchProgress.value = Math.max(0, Math.min(100, catchProgress.value));

            // End Conditions
            if (tensionLevel.value <= FAIL_TENSION_MIN) {
                endTomTichGame(false, 'Tôm tích đã chui vào hang!');
            } else if (tensionLevel.value >= FAIL_TENSION_MAX) {
                endTomTichGame(false, 'Dây câu đã đứt!');
            } else if (catchProgress.value >= 100) {
                endTomTichGame(true, `Câu được ${currentShrimp.value.name}!`);
            } else if (timeRemaining.value <= 0) {
                endTomTichGame(false, 'Tôm tích đã trốn vào hang!');
            } else {
                tomtichAnimationFrame = requestAnimationFrame(updateTensionLoop);
            }
        };

        const endTomTichGame = (success, message) => {
            gamePhase.value = 'RESULT';
            tomtichResultSuccess.value = success;
            resultMessage.value = message;

            if (tomtichAnimationFrame) {
                cancelAnimationFrame(tomtichAnimationFrame);
            }

            stopAllSounds();

            if (success) SOUNDS.win.play().catch(() => { });
            else SOUNDS.lose.play().catch(() => { });

            // Send full object or just ID
            fetch(`https://${getParentResourceName()}/tomtichAttempt`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    success: success,
                    item: currentShrimp.value.id,
                    customMessage: (!success && message) ? message : null
                })
            });

            // Failsafe: Nếu server không phản hồi đóng UI sau 10 giây, tự đóng
            setTimeout(() => {
                if (tomtichVisible.value && gamePhase.value === 'RESULT') {
                    handleTomTichClose();
                }
            }, 5000);
        };

        const getParentResourceName = () => 'f17_cautomtich';

        const updateConfig = (config) => {
            if (!config || !config.NUI) return;
            uiConfig.value = config.NUI;
            const nui = config.NUI;

            // Update Sounds
            if (nui.Sounds) {
                for (const [key, data] of Object.entries(nui.Sounds)) {
                    if (SOUNDS[key]) {
                        // If already exists, just update volume
                        SOUNDS[key].volume = data.volume || 0.5;
                    } else {
                        SOUNDS[key] = new Audio(data.url);
                        SOUNDS[key].volume = data.volume || 0.5;
                    }
                }
                if (SOUNDS.ocean) SOUNDS.ocean.loop = true;
                if (SOUNDS.reelIn) SOUNDS.reelIn.loop = true;
            }

            // Update Fishing Mechanics
            if (nui.Fishing) {
                const f = nui.Fishing;
                TENSION_SAFE_MIN = f.tensionSafeMin || 30;
                TENSION_SAFE_MAX = f.tensionSafeMax || 70;
                GAME_TIME_LIMIT = f.gameTimeLimit || 30000;
                CATCH_DURATION = f.catchDuration || 20000;
                PULL_INTERVAL_MIN = f.pullIntervalMin || 2000;
                PULL_INTERVAL_MAX = f.pullIntervalMax || 4000;

                TENSION_INC_HOLD = f.tensionIncreaseHolding || 35;
                TENSION_DEC_REL = f.tensionDecreaseReleased || 25;
                RESISTANCE_BASE = f.resistanceBase || 15;
                PROGRESS_DEC_RATE = f.progressDecreaseRate || 50;
                FAIL_TENSION_MAX = f.failTensionMax || 95;
                FAIL_TENSION_MIN = f.failTensionMin || 5;
                WARN_THRESHOLD_HI = f.warningThresholdHigh || 85;
                WARN_THRESHOLD_LO = f.warningThresholdLow || 15;

                timeRemaining.value = GAME_TIME_LIMIT / 1000;
            }

            // Tunnel Config
            if (nui.Tunnel) {
                const t = nui.Tunnel;
                TUNNEL_TOTAL_DEPTH = t.totalDepth || 5000;
                TUNNEL_PATH_WIDTH = t.pathWidth || 130;
                TUNNEL_WARNING_DIST = t.warningDistance || 20;
                TUNNEL_MAX_SPEED = t.maxSpeed || 3.0;
                TUNNEL_ACCEL = t.acceleration || 0.1;
                TUNNEL_FRICTION = t.friction || 0.2;
                TUNNEL_RETRACT_SPEED = t.retractSpeed || 8;
                TUNNEL_LERP_SPEED = t.lerpSpeed || 0.25;
                TUNNEL_SWAY = t.swayAmount || 80;
            }

            // Phases Config
            if (nui.Dropping) {
                DROP_SPEED = nui.Dropping.dropSpeed || 40;
                DROP_RETRACT_SPEED = nui.Dropping.retractSpeed || 60;
            }
            if (nui.Biting) {
                WAIT_MIN = nui.Biting.waitMin || 5000;
                WAIT_RAND = nui.Biting.waitRandom || 3000;
                BITE_WINDOW = nui.Biting.biteWindow || 2000;
            }

            // Generate shrimpTypesByLevel from Config.LevelConfig and Config.NUIItems
            if (config.LevelConfig && config.NUIItems) {
                const levels = {};
                for (const [lvl, data] of Object.entries(config.LevelConfig)) {
                    levels[lvl] = [];
                    for (const [itemId, chance] of Object.entries(data.rates || {})) {
                        if (chance > 0 && config.NUIItems[itemId]) {
                            levels[lvl].push({
                                id: itemId,
                                name: config.NUIItems[itemId].name,
                                image: config.NUIItems[itemId].image,
                                chance: chance
                            });
                        }
                    }
                }
                shrimpTypesByLevel.value = levels;
            }
        };

        // Event Handling
        const handleMessage = (event) => {
            if (event.data.action === 'showTomTich') {
                if (event.data.config) updateConfig(event.data.config);
                resetGameState();
                gamePhase.value = 'IDLE';
                tomtichVisible.value = true;
                if (event.data.level) {
                    playerLevel.value = Math.min(3, Math.max(1, event.data.level));
                }
            } else if (event.data.action === 'hideTomTich') {
                closeGameUI();
            } else if (event.data.action === 'updateLevel') {
                if (event.data.level) {
                    playerLevel.value = Math.min(3, Math.max(1, event.data.level));
                }
            } else if (event.data.action === 'showTreasure') {
                if (event.data.config) updateConfig(event.data.config);
                initTreasureGame();
            } else if (event.data.action === 'hideTreasure') {
                closeTreasureGame();
            } else if (event.data.action === 'treasureGameData') {
                treasureAttempts.value = event.data.data.attempts;
            } else if (event.data.action === 'tomtichResult') {
                // Server đã xác nhận kết quả, UI có thể hiển thị thêm hiệu ứng nếu cần
                console.log("TomTich Result received:", event.data.success);
            }
        };

        // ============================================
        // TREASURE HUNT FUNCTIONS
        // ============================================

        const initTreasureGame = () => {
            const config = uiConfig.value ? uiConfig.value.Treasure : null;

            treasureVisible.value = true;
            treasureGameEnded.value = false;
            treasureSuccess.value = false;
            treasureFound.value = 0;
            treasureAttempts.value = config ? config.initialAttempts : 5;
            treasureHint.value = '';
            treasureResultMessage.value = '';
            treasureOpenedIndices.value = [];

            // Initialize cells based on gridSize
            const gridSize = config ? config.gridSize : 5;
            const cellCount = gridSize * gridSize;

            treasureCells.value = [];
            for (let i = 0; i < cellCount; i++) {
                treasureCells.value.push({
                    opened: false,
                    isTreasure: false
                });
            }

            // LOCAL GENERATION: Generate treasure positions
            generateLocalTreasures();
        };

        const generateLocalTreasures = () => {
            const config = uiConfig.value ? uiConfig.value.Treasure : null;
            const gridSize = config ? config.gridSize : 5;
            const count = config ? config.treasureCount : 2;
            const minDistance = config ? config.minDistance : 3;

            const positions = [];
            const cellCount = gridSize * gridSize;

            while (positions.length < count) {
                const pos = Math.floor(Math.random() * cellCount);

                if (!positions.includes(pos)) {
                    if (positions.length === 1) {
                        const firstPos = positions[0];
                        const row1 = Math.floor(firstPos / gridSize);
                        const col1 = firstPos % gridSize;
                        const row2 = Math.floor(pos / gridSize);
                        const col2 = pos % gridSize;
                        const dist = Math.abs(row1 - row2) + Math.abs(col1 - col2);

                        if (dist >= minDistance) {
                            positions.push(pos);
                        }
                    } else {
                        positions.push(pos);
                    }
                }
            }
            treasurePositions.value = positions;
            console.log("Treasures hidden at:", positions);
        };

        const closeTreasureGame = () => {
            treasureVisible.value = false;
        };

        const handleTreasureClose = () => {
            closeTreasureGame();
            fetch(`https://${getParentResourceName()}/closeTreasure`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        };

        const openTreasureCell = (index) => {
            if (treasureGameEnded.value || treasureCells.value[index].opened) {
                return;
            }

            // LOCAL LOGIC
            const cell = treasureCells.value[index];
            cell.opened = true;
            treasureOpenedIndices.value.push(index);

            const isTreasure = treasurePositions.value.includes(index);
            cell.isTreasure = isTreasure;

            if (isTreasure) {
                treasureFound.value++;
                treasureAttempts.value++; // Bonus turn
                treasureHint.value = '🎉 Tìm được kho báu! +1 lượt thưởng!';
                SOUNDS.win.play().catch(() => { });

                // Check Win
                const config = uiConfig.value ? uiConfig.value.Treasure : null;
                const targetCount = config ? config.treasureCount : 2;
                if (treasureFound.value >= targetCount) {
                    finishTreasureGame(true);
                }
            } else {
                treasureAttempts.value--;

                // Generate Hint locally
                const hint = generateLocalHint(index);
                treasureHint.value = hint;
                SOUNDS.lose.play().catch(() => { });

                // Check Lose
                if (treasureAttempts.value <= 0) {
                    finishTreasureGame(false);
                }
            }
        };

        const generateLocalHint = (cellIndex) => {
            const config = uiConfig.value ? uiConfig.value.Treasure : null;
            const gridSize = config ? config.gridSize : 5;
            const row = Math.floor(cellIndex / gridSize);
            const col = cellIndex % gridSize;

            // Find closest unfound treasure
            let minDistance = 999;
            let closestTreasure = null;

            treasurePositions.value.forEach(tPos => {
                const isFound = treasureOpenedIndices.value.includes(tPos) && treasureCells.value[tPos].isTreasure;
                if (!isFound) {
                    const tRow = Math.floor(tPos / gridSize);
                    const tCol = tPos % gridSize;
                    const dist = Math.abs(row - tRow) + Math.abs(col - tCol);
                    if (dist < minDistance) {
                        minDistance = dist;
                        closestTreasure = tPos;
                    }
                }
            });

            if (closestTreasure === null) return "Không còn kho báu nào!";

            const tRow = Math.floor(closestTreasure / gridSize);
            const tCol = closestTreasure % gridSize;
            const rowDiff = tRow - row;
            const colDiff = tCol - col;

            if (Math.abs(rowDiff) + Math.abs(colDiff) === 1) {
                return "🔥 Kho báu đã gần bạn lắm rồi!";
            }
            if (Math.abs(rowDiff) === 1 && Math.abs(colDiff) === 1) {
                return "🎯 Kho báu ở gần đây";
            }

            const directions = [];
            if (rowDiff < 0) directions.push("Trên");
            if (rowDiff > 0) directions.push("Dưới");
            if (colDiff < 0) directions.push("Trái");
            if (colDiff > 0) directions.push("Phải");

            return "📍 Xa – " + directions.join("/");
        };

        const finishTreasureGame = (success) => {
            treasureGameEnded.value = true;
            treasureSuccess.value = success;

            // Reveal all treasures
            treasurePositions.value.forEach(pos => {
                treasureCells.value[pos].isTreasure = true;
            });

            setTimeout(() => {
                if (success) {
                    treasureResultMessage.value = '🎉 Chúc mừng! Bạn đã nhận được kho báu!';
                    SOUNDS.win.play().catch(() => { });

                    // Notify server ONLY when win to give reward
                    fetch(`https://${getParentResourceName()}/treasureFinish`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ success: true })
                    });
                } else {
                    treasureResultMessage.value = '😔 Hết lượt! Hãy thử lại lần sau.';
                    SOUNDS.lose.play().catch(() => { });

                    fetch(`https://${getParentResourceName()}/treasureFinish`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ success: false })
                    });
                }

                // Auto-close UI after 5 seconds of showing result
                setTimeout(() => {
                    handleTreasureClose();
                }, 5000);
            }, 1500);
        };

        const handleKeydown = (e) => {
            if (e.key === 'Escape') {
                if (tomtichVisible.value) {
                    handleTomTichClose();
                } else if (treasureVisible.value) {
                    handleTreasureClose();
                }
            }
            if (e.code === 'Space') {
                isHoldingSpace.value = true; // Always set true on press

                if (gamePhase.value === 'IDLE') {
                    startDropLine();
                } else if (gamePhase.value === 'TUNNEL_NAV') {
                    // Space support for tunnel? Request said "Đè chuột". Can add space too.
                    if (!tunnelState.isMouseDown) {
                        onTunnelMouseDown();
                        // Add listener for keyup
                        const upHandler = (ev) => {
                            if (ev.code === 'Space') {
                                onTunnelMouseUp();
                                document.removeEventListener('keyup', upHandler);
                            }
                        };
                        document.addEventListener('keyup', upHandler);
                    }
                } else if (['FISHING', 'DROPPING', 'WAITING', 'BITING'].includes(gamePhase.value)) {
                    e.preventDefault();
                }
            }
        };

        const handleKeyup = (e) => {
            if (e.code === 'Space') {
                isHoldingSpace.value = false;
            }
        };

        onMounted(() => {
            window.addEventListener('message', handleMessage);
            document.addEventListener('keydown', handleKeydown);
            document.addEventListener('keyup', handleKeyup);
        });

        onBeforeUnmount(() => {
            window.removeEventListener('message', handleMessage);
            document.removeEventListener('keydown', handleKeydown);
            document.removeEventListener('keyup', handleKeyup);
        });

        return {
            tomtichVisible,
            gamePhase,
            showTunnelInstruction,
            tunnelCanvas,
            tunnelCompleted,
            tomtichResultSuccess,
            resultMessage,
            tunnelMessage,
            tunnelProgress,
            tunnelSpeed,
            tunnelCollisionWarning,
            tunnelCombo,
            tensionLevel,
            catchProgress,
            timeRemaining,
            fishingLineHeight,
            shrimpPosition,
            shrimpPulling,
            currentShrimpImage,
            playerLevel,
            handleTomTichClose,
            startTomTichGame: () => { /* No-op, auto start via space */ },
            // Treasure Hunt
            treasureVisible,
            treasureCells,
            treasureAttempts,
            treasureFound,
            treasureHint,
            treasureGameEnded,
            treasureSuccess,
            treasureResultMessage,
            handleTreasureClose,
            openTreasureCell
        };
    }
});

app.mount('#app');
