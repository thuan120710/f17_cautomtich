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
        // Tomtich state
        const tomtichVisible = ref(false);
        const tomtichStatus = ref('Sẵn sàng');

        // Tomtich game state - CƠ CHẾ MỚI
        const tomtichGameStarted = ref(false);
        const tomtichGameEnded = ref(false);
        const tomtichResultSuccess = ref(false);
        const resultMessage = ref('');

        // Tension system (Lực căng dây)
        const tensionLevel = ref(50); // 0-100, 50 là giữa
        const catchProgress = ref(0); // 0-100, tiến độ câu tôm
        const timeRemaining = ref(30); // Thời gian còn lại (giây)
        const isHoldingSpace = ref(false);

        // Visual effects
        const fishingLineHeight = ref(100); // Chiều dài dây câu
        const shrimpPosition = ref(80); // Vị trí tôm (% từ trên xuống)
        const shrimpPulling = ref(false); // Tôm đang giật
        const shrimpResistance = ref(0.5); // Sức kháng của tôm (0-1)

        // Animation
        let tomtichAnimationFrame = null;
        let lastUpdateTime = 0;
        let gameStartTime = 0;

        // Game constants
        const TENSION_SAFE_MIN = 30; // Dưới 30% = tôm thoát
        const TENSION_SAFE_MAX = 70; // Trên 70% = đứt dây
        const GAME_TIME_LIMIT = 30000; // 30 giây giới hạn thời gian
        const CATCH_DURATION = 20000; // 15 giây để đầy tiến độ (nếu chơi hoàn hảo)
        const PULL_INTERVAL_MIN = 2000; // Tôm giật ít nhất 2s một lần
        const PULL_INTERVAL_MAX = 4000; // Tôm giật nhiều nhất 4s một lần

        // Game keys state
        const oceanMusicStarted = ref(false);

        // ============================================
        // GAME LOGIC METHODS
        // ============================================

        const handleTomTichClose = () => {
            // Reset toàn bộ state
            tomtichVisible.value = false;
            tomtichGameStarted.value = false;
            tomtichGameEnded.value = false;
            tomtichResultSuccess.value = false;
            resultMessage.value = '';
            tensionLevel.value = 50;
            catchProgress.value = 0;
            timeRemaining.value = 30;
            fishingLineHeight.value = 100;
            shrimpPosition.value = 50;
            shrimpPulling.value = false;
            isHoldingSpace.value = false;

            // Hủy animation frame nếu có
            if (tomtichAnimationFrame) {
                cancelAnimationFrame(tomtichAnimationFrame);
                tomtichAnimationFrame = null;
            }

            SOUNDS.ocean.pause();
            SOUNDS.ocean.currentTime = 0;
            SOUNDS.reelIn.pause();
            SOUNDS.reelIn.currentTime = 0;
            SOUNDS.tension.pause();
            SOUNDS.tension.currentTime = 0;

            fetch(`https://${getParentResourceName()}/closeTomTich`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        };

        const startTomTichGame = () => {
            tomtichGameStarted.value = true;
            tomtichGameEnded.value = false;
            tensionLevel.value = 50;
            catchProgress.value = 0;
            timeRemaining.value = 30;
            fishingLineHeight.value = 100;
            shrimpPosition.value = 50; // Tôm bắt đầu ở 50% (giữa)
            shrimpPulling.value = false;
            isHoldingSpace.value = false;

            // Random sức kháng của tôm
            shrimpResistance.value = 0.4 + Math.random() * 0.4; // 0.4 - 0.8

            lastUpdateTime = Date.now();
            gameStartTime = Date.now();
            scheduleShrimpPull();
            updateTensionLoop();

            SOUNDS.ocean.play().catch(() => { });
        };

        const scheduleShrimpPull = () => {
            if (!tomtichGameStarted.value || tomtichGameEnded.value) return;

            const nextPullTime = PULL_INTERVAL_MIN + Math.random() * (PULL_INTERVAL_MAX - PULL_INTERVAL_MIN);

            setTimeout(() => {
                if (tomtichGameStarted.value && !tomtichGameEnded.value) {
                    triggerShrimpPull();
                    scheduleShrimpPull();
                }
            }, nextPullTime);
        };

        const triggerShrimpPull = () => {
            shrimpPulling.value = true;

            // Phát âm thanh tôm giật
            SOUNDS.shrimpPull.currentTime = 0;
            SOUNDS.shrimpPull.play().catch(() => { });

            // Tôm giật làm tăng lực căng đột ngột
            tensionLevel.value = Math.min(tensionLevel.value + 15 + Math.random() * 15, 95);

            setTimeout(() => {
                shrimpPulling.value = false;
            }, 800);
        };

        const updateTensionLoop = () => {
            if (!tomtichGameStarted.value || tomtichGameEnded.value) return;

            const now = Date.now();
            const deltaTime = (now - lastUpdateTime) / 1000; // seconds
            lastUpdateTime = now;

            // Cập nhật thời gian còn lại
            const elapsed = (now - gameStartTime) / 1000;
            timeRemaining.value = Math.max(0, 30 - elapsed);

            // Cập nhật lực căng
            if (isHoldingSpace.value) {
                // Giữ phím = kéo lên = tăng lực
                tensionLevel.value += 25 * deltaTime;

                // Phát âm thanh kéo dây khi giữ phím
                if (SOUNDS.reelIn.paused) {
                    SOUNDS.reelIn.play().catch(() => { });
                }
            } else {
                // Nhả phím = thả lỏng = giảm lực
                tensionLevel.value -= 20 * deltaTime;

                // Dừng âm thanh kéo dây khi nhả phím
                if (!SOUNDS.reelIn.paused) {
                    SOUNDS.reelIn.pause();
                    SOUNDS.reelIn.currentTime = 0;
                }
            }

            // Tôm kháng cự (tự động kéo xuống)
            tensionLevel.value -= shrimpResistance.value * 15 * deltaTime;

            // Giới hạn tension
            tensionLevel.value = Math.max(0, Math.min(100, tensionLevel.value));

            // Phát âm thanh cảnh báo khi lực căng nguy hiểm
            if (tensionLevel.value >= 85 || tensionLevel.value <= 15) {
                if (SOUNDS.tension.paused) {
                    SOUNDS.tension.play().catch(() => { });
                }
            } else {
                if (!SOUNDS.tension.paused) {
                    SOUNDS.tension.pause();
                    SOUNDS.tension.currentTime = 0;
                }
            }

            // Cập nhật vị trí tôm dựa trên lực căng (ĐẢO NGƯỢC)
            // Lực cao (100) = tôm kéo xuống mạnh = tôm ở dưới (80%)
            // Lực thấp (0) = dây lỏng = tôm ở trên (20%)
            shrimpPosition.value = 20 + (tensionLevel.value * 0.6); // 20% -> 80%

            // Cập nhật chiều dài dây câu theo vị trí tôm
            fishingLineHeight.value = shrimpPosition.value + 10;

            // Check vùng an toàn
            if (tensionLevel.value >= TENSION_SAFE_MIN && tensionLevel.value <= TENSION_SAFE_MAX) {
                // Trong vùng an toàn = tăng tiến độ
                catchProgress.value += 100 / (CATCH_DURATION / 1000) * deltaTime;
            } else {
                // Ngoài vùng an toàn = giảm tiến độ
                catchProgress.value -= 50 / (CATCH_DURATION / 1000) * deltaTime;
            }

            catchProgress.value = Math.max(0, Math.min(100, catchProgress.value));

            // Check điều kiện kết thúc
            if (tensionLevel.value <= 5) {
                // Lực quá thấp (thanh ở trên) = tôm thoát
                endTomTichGame(false, 'Tôm tích đã chui vào hang!');
                return;
            } else if (tensionLevel.value >= 95) {
                // Lực quá cao (thanh ở dưới) = đứt dây
                endTomTichGame(false, 'Dây câu đã đứt!');
                return;
            } else if (catchProgress.value >= 100) {
                // Hoàn thành = thắng
                endTomTichGame(true, 'Câu được Tôm Tích!');
                return;
            } else if (timeRemaining.value <= 0) {
                // Hết thời gian = tôm trốn vào hang
                endTomTichGame(false, 'Tôm tích đã trốn vào hang!');
                return;
            }

            tomtichAnimationFrame = requestAnimationFrame(updateTensionLoop);
        };

        const endTomTichGame = (success, message) => {
            tomtichGameEnded.value = true;
            tomtichResultSuccess.value = success;
            resultMessage.value = message;

            if (tomtichAnimationFrame) {
                cancelAnimationFrame(tomtichAnimationFrame);
            }

            SOUNDS.ocean.pause();
            SOUNDS.ocean.currentTime = 0;
            SOUNDS.reelIn.pause();
            SOUNDS.reelIn.currentTime = 0;
            SOUNDS.tension.pause();
            SOUNDS.tension.currentTime = 0;

            if (success) {
                SOUNDS.win.play().catch(() => { });
            } else {
                SOUNDS.lose.play().catch(() => { });
            }

            fetch(`https://${getParentResourceName()}/tomtichAttempt`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ success: success })
            });
        };

        const getParentResourceName = () => {
            return 'f17_cautomtich';
        };

        // ============================================
        // MESSAGE HANDLER
        // ============================================
        const handleMessage = (event) => {
            const data = event.data;

            switch (data.action) {
                case 'showTomTich':
                    // Reset state khi mở UI mới
                    tomtichGameStarted.value = false;
                    tomtichGameEnded.value = false;
                    tomtichResultSuccess.value = false;
                    resultMessage.value = '';
                    tensionLevel.value = 50;
                    catchProgress.value = 0;
                    fishingLineHeight.value = 0;
                    shrimpPulling.value = false;
                    isHoldingSpace.value = false;

                    // Hủy animation frame cũ nếu có
                    if (tomtichAnimationFrame) {
                        cancelAnimationFrame(tomtichAnimationFrame);
                        tomtichAnimationFrame = null;
                    }

                    tomtichVisible.value = true;
                    tomtichStatus.value = 'Sẵn sàng';
                    break;
                case 'hideTomTich':
                    // Reset state khi đóng từ server
                    tomtichGameStarted.value = false;
                    tomtichGameEnded.value = false;
                    tomtichResultSuccess.value = false;
                    resultMessage.value = '';
                    tensionLevel.value = 50;
                    catchProgress.value = 0;
                    fishingLineHeight.value = 0;
                    shrimpPulling.value = false;
                    isHoldingSpace.value = false;

                    if (tomtichAnimationFrame) {
                        cancelAnimationFrame(tomtichAnimationFrame);
                        tomtichAnimationFrame = null;
                    }

                    tomtichVisible.value = false;
                    break;
                case 'tomtichResult':
                    tomtichStatus.value = data.success ? 'Thành công!' : 'Thất bại!';
                    break;
            }
        };

        const handleKeydown = (e) => {
            if (e.key === 'Escape') {
                if (tomtichVisible.value) {
                    // Reset state khi nhấn ESC
                    if (tomtichAnimationFrame) {
                        cancelAnimationFrame(tomtichAnimationFrame);
                        tomtichAnimationFrame = null;
                    }
                    handleTomTichClose();
                }
            }
            if (e.code === 'Space' && tomtichGameStarted.value && !tomtichGameEnded.value) {
                e.preventDefault();
                isHoldingSpace.value = true;
            }
        };

        const handleKeyup = (e) => {
            if (e.code === 'Space') {
                isHoldingSpace.value = false;
            }
        };

        // ============================================
        // LIFECYCLE
        // ============================================
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
            tomtichStatus,
            tomtichGameStarted,
            tomtichGameEnded,
            tomtichResultSuccess,
            resultMessage,
            tensionLevel,
            catchProgress,
            timeRemaining,
            fishingLineHeight,
            shrimpPosition,
            shrimpPulling,
            startTomTichGame,
            handleTomTichClose
        };
    }
});

app.mount('#app');
