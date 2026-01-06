// ============================================
// VUE.JS APP - Câu Tôm Tích
// ============================================

const { createApp, ref, onMounted, onBeforeUnmount } = Vue;

// ============================================
// CONSTANTS & SOUNDS
// ============================================
const SOUNDS = {
    win: new Audio('https://assets.mixkit.co/active_storage/sfx/2000/2000-preview.mp3'),
    lose: new Audio('https://assets.mixkit.co/active_storage/sfx/2955/2955-preview.mp3'),
    ocean: new Audio('https://assets.mixkit.co/active_storage/sfx/2393/2393-preview.mp3'),
    // Âm thanh cho tôm tích
    reelIn: new Audio('https://assets.mixkit.co/active_storage/sfx/2571/2571-preview.mp3'), // Âm thanh kéo dây
    shrimpPull: new Audio('https://assets.mixkit.co/active_storage/sfx/2573/2573-preview.mp3'), // Âm thanh tôm giật
    tension: new Audio('https://assets.mixkit.co/active_storage/sfx/2577/2577-preview.mp3') // Âm thanh căng dây
};

SOUNDS.win.volume = 0.5;
SOUNDS.lose.volume = 0.4;
SOUNDS.ocean.volume = 0.2;
SOUNDS.ocean.loop = true;
SOUNDS.reelIn.volume = 0.3;
SOUNDS.reelIn.loop = true; // Lặp lại khi đang kéo
SOUNDS.shrimpPull.volume = 0.6;
SOUNDS.tension.volume = 0.4;

// ============================================
// ROOT APP
// ============================================
const app = createApp({
    setup() {
        // App State
        const tomtichVisible = ref(false);
        const gamePhase = ref('IDLE'); // IDLE, DROPPING, FISHING, RESULT
        const tomtichStatus = ref('Sẵn sàng'); // Legacy UI status if needed
        const resultMessage = ref('');
        const tomtichResultSuccess = ref(false);

        // Game Configuration
        const SHRIMP_TYPES = [
            { id: 'tomtich', name: 'Tôm Tích', icon: '🦞', chance: 50 },
            { id: 'tomtichxanh', name: 'Tôm Tích Xanh', icon: '🦐', chance: 30 }, // Blue/Green Shrimp
            { id: 'tomtichdo', name: 'Tôm Tích Đỏ', icon: '🦑', chance: 15 },    // Red/Special
            { id: 'tomtichhoangkim', name: 'Tôm Tích Hoàng Kim', icon: '👑', chance: 5 } // Golden
        ];

        // Game State
        const currentShrimp = ref(SHRIMP_TYPES[0]);
        const currentShrimpIcon = ref('🦞');

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

        // Constants
        const TENSION_SAFE_MIN = 30;
        const TENSION_SAFE_MAX = 70;
        const GAME_TIME_LIMIT = 30000;
        const CATCH_DURATION = 20000;
        const PULL_INTERVAL_MIN = 2000;
        const PULL_INTERVAL_MAX = 4000;

        // Sound Helper
        const stopAllSounds = () => {
            SOUNDS.ocean.pause(); SOUNDS.ocean.currentTime = 0;
            SOUNDS.reelIn.pause(); SOUNDS.reelIn.currentTime = 0;
            SOUNDS.tension.pause(); SOUNDS.tension.currentTime = 0;
            SOUNDS.shrimpPull.pause(); SOUNDS.shrimpPull.currentTime = 0;
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
        };

        // Step 1: User presses Space in IDLE -> Starts Dropping
        const dropDepth = ref(0); // 0-100%

        const startDropLine = () => {
            if (gamePhase.value !== 'IDLE') return;

            gamePhase.value = 'DROPPING';
            dropDepth.value = 0;
            fishingLineHeight.value = 0;

            SOUNDS.ocean.play().catch(() => { });

            lastUpdateTime = Date.now();
            updateDropLoop();
        };

        const updateDropLoop = () => {
            if (gamePhase.value !== 'DROPPING') return;

            const now = Date.now();
            const deltaTime = (now - lastUpdateTime) / 1000;
            lastUpdateTime = now;

            if (isHoldingSpace.value) {
                // Holding = Drop line down
                dropDepth.value += 40 * deltaTime;
                if (SOUNDS.reelIn.paused) SOUNDS.reelIn.play().catch(() => { });
            } else {
                // Released = Retract line up
                dropDepth.value -= 60 * deltaTime;
                if (!SOUNDS.reelIn.paused) {
                    SOUNDS.reelIn.pause();
                    SOUNDS.reelIn.currentTime = 0;
                }
                if (dropDepth.value <= 0) {
                    dropDepth.value = 0;
                    gamePhase.value = 'IDLE';
                    fishingLineHeight.value = 0;
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
            // Random wait 5-8s
            waitTimer.value = 5000 + Math.random() * 3000;
            lastUpdateTime = Date.now();

            // Stop reel sound
            if (!SOUNDS.reelIn.paused) {
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
            biteTimer.value = 2000; // 2s window
            shrimpPulling.value = true; // Shake effect
            SOUNDS.shrimpPull.play().catch(() => { });

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
                startFishingPhase();
                return;
            }

            biteTimer.value -= deltaTime;
            if (biteTimer.value <= 0) {
                // Failed: Too slow / Didn't release -> Lose
                shrimpPulling.value = false;
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

            // Random shrimp selection
            const rand = Math.random() * 100; // 0-100
            let cumulative = 0;
            let selected = SHRIMP_TYPES[0];

            for (const type of SHRIMP_TYPES) {
                cumulative += type.chance;
                if (rand <= cumulative) {
                    selected = type;
                    break;
                }
            }
            currentShrimp.value = selected;
            currentShrimpIcon.value = selected.icon;

            // Difficulty adjustment based on rarity?
            // Rare shrimps could be harder
            let difficultyMult = 1.0;
            if (selected.id === 'tomtich_hoangkim') difficultyMult = 1.3;
            else if (selected.id === 'tomtich_do') difficultyMult = 1.1;

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
                tensionLevel.value += 35 * deltaTime; // Slightly easier to pull up
                if (SOUNDS.reelIn.paused) SOUNDS.reelIn.play().catch(() => { });
            } else {
                tensionLevel.value -= 25 * deltaTime; // Slower drop
                if (!SOUNDS.reelIn.paused) {
                    SOUNDS.reelIn.pause();
                    SOUNDS.reelIn.currentTime = 0;
                }
            }

            // Resistance
            tensionLevel.value -= shrimpResistance.value * 15 * deltaTime;
            tensionLevel.value = Math.max(0, Math.min(100, tensionLevel.value));

            // Sound warning
            if (tensionLevel.value >= 85 || tensionLevel.value <= 15) {
                if (SOUNDS.tension.paused) SOUNDS.tension.play().catch(() => { });
            } else {
                if (!SOUNDS.tension.paused) {
                    SOUNDS.tension.pause();
                    SOUNDS.tension.currentTime = 0;
                }
            }

            // Visuals
            shrimpPosition.value = 20 + (tensionLevel.value * 0.6);
            fishingLineHeight.value = shrimpPosition.value + 10;

            // Progress
            if (tensionLevel.value >= TENSION_SAFE_MIN && tensionLevel.value <= TENSION_SAFE_MAX) {
                catchProgress.value += 100 / (CATCH_DURATION / 1000) * deltaTime;
            } else {
                catchProgress.value -= 50 / (CATCH_DURATION / 1000) * deltaTime;
            }
            catchProgress.value = Math.max(0, Math.min(100, catchProgress.value));

            // End Conditions
            if (tensionLevel.value <= 5) {
                endTomTichGame(false, 'Tôm tích đã chui vào hang!');
            } else if (tensionLevel.value >= 95) {
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
                    item: currentShrimp.value.id
                })
            });
        };

        const getParentResourceName = () => 'f17_cautomtich';

        // Event Handling
        const handleMessage = (event) => {
            if (event.data.action === 'showTomTich') {
                resetGameState();
                gamePhase.value = 'IDLE';
                tomtichVisible.value = true;
            } else if (event.data.action === 'hideTomTich') {
                closeGameUI();
            }
        };

        const handleKeydown = (e) => {
            if (e.key === 'Escape' && tomtichVisible.value) {
                handleTomTichClose();
            }
            if (e.code === 'Space') {
                isHoldingSpace.value = true; // Always set true on press

                if (gamePhase.value === 'IDLE') {
                    startDropLine();
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
            gamePhase, // New
            tomtichResultSuccess,
            resultMessage,
            tensionLevel,
            catchProgress,
            timeRemaining,
            fishingLineHeight,
            shrimpPosition,
            shrimpPulling,
            currentShrimpIcon, // New
            handleTomTichClose,
            startTomTichGame: () => { /* No-op, auto start via space */ }
        };
    }
});

app.mount('#app');
