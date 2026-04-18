const API_URL = (window.location.protocol === 'file:' || (window.location.port && window.location.port !== '8000')) ? "http://127.0.0.1:8000" : "";
let currentUser = localStorage.getItem('user');
let token = localStorage.getItem('token');
let recentlyPlayed = JSON.parse(localStorage.getItem('recents')) || [];
let musicQueue = [];
let originalQueue = [];
let queueIndex = 0;
let isSeeking = false; 

// Control States
let isShuffle = false;
let repeatMode = 0; // 0: None, 1: All, 2: One

// Audio Visualizer
let audioCtx;
let analyser;
let source;

// Defaults
const DEFAULT_AVATAR = "https://cdn-icons-png.flaticon.com/512/847/847969.png"; 
const DEFAULT_HEADER = "https://images.unsplash.com/photo-1514525253440-b393452e8d26?q=80&w=2000&auto=format&fit=crop";
let newHeaderBase64 = null;
let newAvatarBase64 = null;
let currentThemeColor = localStorage.getItem('theme_color') || "#29cc70";
let currentPlaylistData = null;
let isEditingPlaylist = false;

// Elements
const audioPlayer = document.getElementById('audio-player');
// Important: JioSaavn CDN supports CORS, so we can keep crossorigin for visualizer
audioPlayer.crossOrigin = "anonymous";

const playIcon = document.getElementById('play-icon');
const seekSlider = document.getElementById('seek-slider');
const volSlider = document.getElementById('vol-slider');
const artElement = document.getElementById('current-art');
const waveCanvas = document.getElementById('wave-canvas');

// --- Auth Fetch Wrapper ---
async function authFetch(url, options = {}) {
    const headers = {
        'Authorization': `Bearer ${localStorage.getItem('token')}`,
        'Content-Type': 'application/json',
        ...options.headers
    };
    const response = await fetch(url, { ...options, headers });
    if (response.status === 401) {
        logout();
        throw new Error("Unauthorized");
    }
    return response;
}

window.onload = () => {
    // Theme Logic
    const themeToggle = document.getElementById('checkbox');
    if (themeToggle) {
        const savedTheme = localStorage.getItem('theme') || 'dark';
        document.body.setAttribute('data-theme', savedTheme);
        themeToggle.checked = (savedTheme === 'light');
        themeToggle.addEventListener('change', function(e) {
            const theme = e.target.checked ? 'light' : 'dark';
            document.body.setAttribute('data-theme', theme);
            localStorage.setItem('theme', theme);
        });
    }
    
    const savedColor = localStorage.getItem('theme_color');
    if (savedColor) document.documentElement.style.setProperty('--accent', savedColor);

    setupDropZone('drop-header', 'preview-header', (base64) => newHeaderBase64 = base64);
    setupDropZone('drop-avatar', 'preview-avatar', (base64) => newAvatarBase64 = base64);

    const savedVol = currentUser ? localStorage.getItem('volume_' + currentUser) : localStorage.getItem('volume');
    if (audioPlayer) {
        audioPlayer.volume = savedVol ? parseFloat(savedVol) : 1.0;
    }
    if (volSlider) {
        volSlider.value = audioPlayer.volume;
    }

    // Window Resize for Canvas Stability
    window.addEventListener('resize', () => {
        if (waveCanvas) {
            waveCanvas.width = waveCanvas.parentElement.offsetWidth;
            waveCanvas.height = waveCanvas.parentElement.offsetHeight;
        }
    });

    // Listeners
    if (audioPlayer) {
        audioPlayer.addEventListener('timeupdate', updateSeekbar);
        audioPlayer.addEventListener('loadedmetadata', () => {
            if (audioPlayer.duration && isFinite(audioPlayer.duration)) {
                if(seekSlider) seekSlider.max = audioPlayer.duration;
                const durElem = document.getElementById('total-dur');
                if(durElem) durElem.innerText = formatTime(audioPlayer.duration);
            }
        });

        audioPlayer.addEventListener('ended', handleSongEnd);
        
        audioPlayer.addEventListener('playing', () => {
            if(playIcon) playIcon.className = "fa-solid fa-pause";
            const playerBar = document.querySelector('.player-bar');
            if (playerBar) playerBar.classList.add('playing');
            
            const titleEl = document.getElementById('current-title');
            const currentSong = musicQueue[queueIndex];
            if(currentSong && titleEl) {
                titleEl.innerText = currentSong.title;
                document.getElementById('current-artist').innerText = currentSong.artist;
                checkIfLiked(currentSong);
                
                if (queueIndex >= musicQueue.length - 2) {
                    autoFillQueue(currentSong);
                }
            }
            initAudioContext();
            renderQueue();
        });

        audioPlayer.addEventListener('pause', () => {
            if(playIcon) playIcon.className = "fa-solid fa-play";
            const playerBar = document.querySelector('.player-bar');
            if (playerBar) playerBar.classList.remove('playing');
        });

        audioPlayer.onerror = (e) => {
            console.error("Audio Playback Error:", audioPlayer.error);
        };
    }

    if(seekSlider) {
        seekSlider.addEventListener('mousedown', () => { isSeeking = true; });
        seekSlider.addEventListener('touchstart', () => { isSeeking = true; });
        seekSlider.addEventListener('input', (e) => {
             isSeeking = true; 
             const currTimeElem = document.getElementById('curr-time');
             if(currTimeElem) currTimeElem.innerText = formatTime(e.target.value);
        });
        seekSlider.addEventListener('change', (e) => {
             audioPlayer.currentTime = e.target.value;
             setTimeout(() => { isSeeking = false; }, 50);
        });
        seekSlider.addEventListener('touchend', (e) => {
            audioPlayer.currentTime = e.target.value;
            setTimeout(() => { isSeeking = false; }, 50);
       });
    }

    if(volSlider) volSlider.addEventListener('input', () => {
        audioPlayer.volume = volSlider.value;
        if (currentUser) {
            localStorage.setItem('volume_' + currentUser, volSlider.value);
        } else {
            localStorage.setItem('volume', volSlider.value);
        }
    });

    if (token && currentUser) showApp();
    drawWaveform();
};

/* --- AUTOPLAY / INFINITE QUEUE LOGIC (JioSaavn) --- */
async function autoFillQueue(baseSong) {
    let url = `${API_URL}/recommendations?`;
    if (baseSong.videoId) {
        url += `video_id=${baseSong.videoId}`;
    } else {
        url += `title=${encodeURIComponent(baseSong.title)}&artist=${encodeURIComponent(baseSong.artist || "")}`;
    }

    try {
        const res = await fetch(url);
        const newSongs = await res.json();
        
        if (newSongs && newSongs.length > 0) {
            const uniqueSongs = newSongs.filter( newS => 
                !musicQueue.some( existingS => existingS.title === newS.title )
            );
            
            if (uniqueSongs.length > 0) {
                if (isShuffle) {
                    originalQueue.push(...uniqueSongs);
                    let remaining = musicQueue.slice(queueIndex + 1);
                    remaining.push(...uniqueSongs);
                    for (let i = remaining.length - 1; i > 0; i--) {
                        const j = Math.floor(Math.random() * (i + 1));
                        [remaining[i], remaining[j]] = [remaining[j], remaining[i]];
                    }
                    musicQueue = [...musicQueue.slice(0, queueIndex + 1), ...remaining];
                } else {
                    musicQueue.push(...uniqueSongs);
                }
                renderQueue();
            }
        }
    } catch (e) {
        console.error("Autofill failed", e);
    }
}

/* --- PLAYER LOGIC --- */
async function playDirect(song) {
    const playerBar = document.querySelector('.player-bar');
    if (playerBar) playerBar.classList.add('active');

    const titleEl = document.getElementById('current-title');
    const artistEl = document.getElementById('current-artist');

    if(titleEl) titleEl.innerText = song.title; 
    if(artistEl) artistEl.innerText = song.artist;
    if(playIcon) playIcon.className = "fa-solid fa-spinner fa-spin";

    // --- LEGACY CACHE MIGRATION ---
    // Auto-upgrade old stream_yt paths into JioSaavn paths seamlessly on play
    if (song.filename && song.filename.includes('stream_yt')) {
        try {
            const query = `${song.title} ${song.artist}`.trim();
            const res = await fetch(`${API_URL}/search_online?q=${encodeURIComponent(query)}`);
            const results = await res.json();
            if(results && results.length > 0) {
                // Mutate reference in memory globally
                song.filename = results[0].filename;
                song.cover = results[0].cover;
                song.videoId = results[0].videoId;
                song.source = "saavn";
                
                // Flush recents cache
                recentlyPlayed = recentlyPlayed.map(s => s.title === song.title ? song : s);
                localStorage.setItem('recents', JSON.stringify(recentlyPlayed));
                
                // If this song belongs to an active Custom Playlist, sync the fix to MongoDB Database silently
                if (currentPlaylistData && currentPlaylistData.songs) {
                    const idx = currentPlaylistData.songs.findIndex(s => s.title === song.title);
                    if (idx !== -1 && currentUser && token) {
                         authFetch(`${API_URL}/playlists/update_songs`, {
                             method: 'POST',
                             body: JSON.stringify({ playlist_id: currentPlaylistData._id, songs: currentPlaylistData.songs })
                         });
                    }
                }
            }
        } catch(e) { console.error("Legacy upgrade failed", e); }
    }

    audioPlayer.src = song.filename;
    audioPlayer.play().catch(e => {
        console.error("Play error", e);
        if(playIcon) playIcon.className = "fa-solid fa-play";
    });

    if(artElement) {
        if(song.cover) artElement.innerHTML = `<img src="${song.cover}">`;
        else artElement.innerHTML = `<i class="fa-solid fa-music"></i>`;
    }

    addToRecents(song);
    checkIfLiked(song);
}

let repeatedOnce = false;

function playSingle(song) {
    if (isShuffle) toggleShuffle(); 
    musicQueue = [song]; 
    queueIndex = 0;
    originalQueue = [song];
    playDirect(song);
    autoFillQueue(song);
}

/* --- CONTROL LOGIC --- */
function togglePlay() {
    if(!musicQueue.length) return;
    if(audioPlayer.paused) {
        audioPlayer.play();
        if(playIcon) playIcon.className = "fa-solid fa-pause";
    } else {
        audioPlayer.pause();
        if(playIcon) playIcon.className = "fa-solid fa-play";
    }
}

function toggleShuffle() {
    isShuffle = !isShuffle;
    const btn = document.getElementById('btn-shuffle');
    btn.classList.toggle('active');

    if (isShuffle) {
        originalQueue = [...musicQueue];
        const currentSong = musicQueue[queueIndex];
        let remaining = musicQueue.slice(queueIndex + 1);
        for (let i = remaining.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [remaining[i], remaining[j]] = [remaining[j], remaining[i]];
        }
        const past = musicQueue.slice(0, queueIndex);
        musicQueue = [...past, currentSong, ...remaining];
    } else {
        if(originalQueue.length > 0) {
            const currentSong = musicQueue[queueIndex];
            musicQueue = [...originalQueue];
            queueIndex = musicQueue.findIndex(s => s.title === currentSong.title);
            if(queueIndex === -1) queueIndex = 0;
        }
    }
    renderQueue();
}

function toggleRepeat() {
    repeatMode = (repeatMode + 1) % 3;
    const btn = document.getElementById('btn-repeat');
    const badge = document.getElementById('repeat-badge');
    const wrapper = document.getElementById('repeat-wrapper');
    if (repeatMode === 0) { 
        btn.className = "fa-solid fa-repeat";
        btn.style.color = "var(--text-secondary)";
        badge.style.display = "none";
        wrapper.title = "Repeat Off";
    } else if (repeatMode === 1) { 
        btn.className = "fa-solid fa-repeat active";
        btn.style.color = "var(--accent)";
        badge.style.display = "block";
        badge.innerText = "1";
        badge.style.color = "var(--accent)";
        wrapper.title = "Repeat 1 Time";
    } else { 
        btn.className = "fa-solid fa-repeat active";
        btn.style.color = "#ff7eb3";
        badge.style.display = "block";
        badge.innerText = "∞";
        badge.style.color = "#ff7eb3";
        wrapper.title = "Infinite Repeat";
    }
}

function handleSongEnd() {
    if (repeatMode === 2) { 
        audioPlayer.currentTime = 0;
        audioPlayer.play();
    } else if (repeatMode === 1) {
        if (!repeatedOnce) {
            repeatedOnce = true;
            audioPlayer.currentTime = 0;
            audioPlayer.play();
        } else {
            repeatedOnce = false;
            nextSong();
        }
    } else {
        repeatedOnce = false;
        nextSong();
    }
}

function nextSong() {
    repeatedOnce = false;
    if (queueIndex < musicQueue.length - 1) {
        queueIndex++;
        playDirect(musicQueue[queueIndex]);
    } else if (repeatMode === 1) { 
        queueIndex = 0;
        playDirect(musicQueue[0]);
    } 
}

function prevSong() {
    repeatedOnce = false;
    if (audioPlayer.currentTime > 3) {
        audioPlayer.currentTime = 0;
    } else if (queueIndex > 0) {
        queueIndex--;
        playDirect(musicQueue[queueIndex]);
    }
}

/* --- QUEUE UI --- */
function toggleQueue() {
    const sidebar = document.getElementById('queue-sidebar');
    sidebar.classList.toggle('open');
    if(sidebar.classList.contains('open')) renderQueue();
}

function renderQueue() {
    const container = document.getElementById('queue-list-container');
    container.innerHTML = "";
    
    const currentSong = musicQueue[queueIndex];
    if (currentSong) {
        container.appendChild(createQueueRow(currentSong, true, queueIndex));
    }

    const futureSongs = musicQueue.slice(queueIndex + 1, queueIndex + 20);
    
    if (futureSongs.length === 0) {
        const msg = document.createElement('div');
        msg.innerHTML = "<p style='color:var(--text-secondary); padding:10px; font-size:12px;'>Autoplaying similar music soon...</p>";
        container.appendChild(msg);
    } else {
        const title = document.createElement('div');
        title.innerHTML = "<h4 style='color:var(--text-secondary); font-size:11px; margin:15px 0 10px 0; font-weight:600; text-transform:uppercase; letter-spacing:1px;'>Up Next</h4>";
        container.appendChild(title);
        
        futureSongs.forEach((s, i) => {
            const globalIdx = queueIndex + 1 + i; 
            container.appendChild(createQueueRow(s, false, globalIdx));
        });
    }
}

function createQueueRow(song, isActive, index) {
    const div = document.createElement('div');
    div.className = isActive ? "song-row active-song" : "song-row";
    div.style.padding = "8px 10px";
    div.innerHTML = `
        <div class="track-art-sm" style="width:36px; height:36px; border-radius:4px;">
            <img src="${song.cover || 'https://via.placeholder.com/36'}">
        </div>
        <div style="flex:1; overflow:hidden;">
            <h4 style="font-size:12px; color:var(--text-primary); white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">
                ${isActive ? '<i class="fa-solid fa-volume-high" style="margin-right:4px; font-size:10px; color:var(--accent);"></i>' : ''}
                ${song.title}
            </h4>
            <p style="font-size:10px; color:var(--text-secondary); white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">
                ${song.artist}
            </p>
        </div>
        <i class="fa-solid fa-folder-plus add-queue-btn" style="padding:10px; color:var(--text-secondary); font-size:14px; cursor:pointer;" title="Add to Playlist"></i>
    `;
    div.onclick = (e) => {
        if (e.target.closest('.add-queue-btn')) {
            openAddToPlaylistModal(song);
            return;
        }
        if (!isActive) {
            queueIndex = index;
            playDirect(musicQueue[queueIndex]);
        }
    };
    return div;
}

/* --- VISUALIZER --- */
function initAudioContext() {
    if (!audioCtx) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        audioCtx = new AudioContext();
        analyser = audioCtx.createAnalyser();
        analyser.fftSize = 256; 
        try {
            source = audioCtx.createMediaElementSource(audioPlayer);
            source.connect(analyser);
            analyser.connect(audioCtx.destination);
        } catch(e) {
            console.log("CORS prevents visualizer:", e);
        }
    }
    if (audioCtx.state === 'suspended') audioCtx.resume();
}

function drawWaveform() {
    requestAnimationFrame(drawWaveform);
    const canvas = waveCanvas;
    if(!canvas) return;
    const ctx = canvas.getContext('2d');
    if (canvas.width !== canvas.offsetWidth || canvas.height !== canvas.offsetHeight) {
        canvas.width = canvas.offsetWidth;
        canvas.height = canvas.offsetHeight;
    }
    const WIDTH = canvas.width;
    const HEIGHT = canvas.height;
    ctx.clearRect(0, 0, WIDTH, HEIGHT);

    let bufferLength = 0;
    let dataArray = [];
    if (analyser) {
        bufferLength = analyser.frequencyBinCount;
        dataArray = new Uint8Array(bufferLength);
        analyser.getByteFrequencyData(dataArray);
    }

    let percent = 0;
    if (audioPlayer.duration && isFinite(audioPlayer.duration)) percent = audioPlayer.currentTime / audioPlayer.duration;
    if (isSeeking && seekSlider) percent = seekSlider.value / seekSlider.max;
    percent = Math.max(0, Math.min(1, percent));
    const currentX = WIDTH * percent;

    // Draw active progress line
    ctx.beginPath();
    ctx.lineWidth = 4;
    ctx.strokeStyle = getComputedStyle(document.body).getPropertyValue('--accent').trim() || "#29cc70";
    ctx.lineCap = 'round';
    ctx.moveTo(0, HEIGHT/2);
    ctx.lineTo(currentX, HEIGHT/2);
    ctx.stroke();

    // Draw frequency bars
    if (analyser && !audioPlayer.paused) {
        const barWidth = 4;
        let x = 0;
        ctx.fillStyle = "rgba(255, 255, 255, 0.1)";
        for(let i = 0; i < bufferLength; i++) {
            const barHeight = (dataArray[i] / 255) * (HEIGHT * 0.8);
            ctx.fillRect(x, (HEIGHT - barHeight)/2, barWidth - 1, barHeight);
            x += barWidth;
            if(x > WIDTH) break;
        }
    } else {
        ctx.beginPath();
        ctx.strokeStyle = "rgba(255, 255, 255, 0.1)";
        ctx.lineWidth = 4;
        ctx.moveTo(currentX, HEIGHT/2);
        ctx.lineTo(WIDTH, HEIGHT/2);
        ctx.stroke();
    }
}

/* --- PLAYLIST & LIKE LOGIC --- */
async function toggleLikeCurrent() {
    if (!musicQueue[queueIndex]) return;
    const song = musicQueue[queueIndex];
    const btn = document.getElementById('player-like-btn');
    
    try {
        const res = await authFetch(`${API_URL}/playlists/${currentUser}`);
        const playlists = await res.json();
        let likedPlaylist = playlists.find(p => p.name === "Liked Songs");
        if (!likedPlaylist) {
            const createRes = await authFetch(`${API_URL}/playlists/create`, {
                method: 'POST',
                body: JSON.stringify({username: currentUser, name: "Liked Songs"})
            });
            const createData = await createRes.json();
            likedPlaylist = { _id: createData.id, songs: [] };
        }
        const isLiked = likedPlaylist.songs && likedPlaylist.songs.some(s => s.title === song.title);
        if (isLiked) {
            const newSongs = likedPlaylist.songs.filter(s => s.title !== song.title);
            await authFetch(`${API_URL}/playlists/update_songs`, {
                method: 'POST',
                body: JSON.stringify({ playlist_id: likedPlaylist._id, songs: newSongs })
            });
            btn.classList.remove('liked');
        } else {
            await authFetch(`${API_URL}/playlists/add_song`, {
                method: 'POST',
                body: JSON.stringify({ playlist_id: likedPlaylist._id, song: song })
            });
            btn.classList.add('liked');
        }
    } catch (e) { console.error(e); }
}

async function checkIfLiked(song) {
    const btn = document.getElementById('player-like-btn');
    btn.classList.remove('liked');
    if(!song) return;
    try {
        const res = await authFetch(`${API_URL}/playlists/${currentUser}`);
        const playlists = await res.json();
        const likedPlaylist = playlists.find(p => p.name === "Liked Songs");
        if (likedPlaylist && likedPlaylist.songs.some(s => s.title === song.title)) {
            btn.classList.add('liked');
        }
    } catch(e) {}
}

async function showLikedSongs() {
    try {
        const res = await authFetch(`${API_URL}/playlists/${currentUser}`);
        const playlists = await res.json();
        const liked = playlists.find(p => p.name === "Liked Songs");
        if (liked) openPlaylistView(liked);
        else alert("No liked songs yet.");
    } catch (e) { alert("Error"); }
}

function openPlaylistView(playlist) {
    currentPlaylistData = playlist;
    isEditingPlaylist = false;
    updateEditButtonUI();
    hideAllViews();
    document.getElementById('playlist-details-view').classList.remove('hidden');
    document.getElementById('pd-title').innerText = playlist.name;
    const coverImg = (playlist.songs && playlist.songs.length > 0 && playlist.songs[0].cover) ? playlist.songs[0].cover : "https://via.placeholder.com/200";
    document.querySelector('#pd-cover img').src = coverImg;
    renderPlaylistSongs();
    const btn = document.getElementById('pd-play-btn');
    btn.onclick = () => playPlaylist(playlist);
}

function playPlaylist(playlist) {
    if(!playlist.songs || playlist.songs.length === 0) return alert("Empty Playlist");
    if (isShuffle) toggleShuffle();
    musicQueue = [...playlist.songs];
    originalQueue = [...playlist.songs];
    queueIndex = 0;
    playDirect(musicQueue[0]);
}

function renderPlaylistSongs() {
    const list = document.getElementById('pd-songs-container');
    list.innerHTML = "";
    document.getElementById('pd-count').innerText = `${currentPlaylistData.songs.length} Songs`;
    currentPlaylistData.songs.forEach((s, i) => {
        const div = document.createElement('div');
        div.className = "song-row";
        if (isEditingPlaylist) {
            div.draggable = true;
            div.classList.add('draggable-item');
            div.dataset.index = i;
            div.addEventListener('dragstart', handleDragStart);
            div.addEventListener('dragover', handleDragOver);
            div.addEventListener('drop', handleDrop);
            
            div.innerHTML = `
                <div class="drag-handle"><i class="fa-solid fa-bars" style="color:var(--text-secondary);"></i></div>
                <div style="flex:1"><h4>${s.title}</h4><p style="font-size:12px; color:var(--text-secondary)">${s.artist}</p></div>
                <div class="remove-song-btn" onclick="deleteSongFromPlaylist(${i})" style="color:#ff2d55; cursor:pointer; padding:10px;"><i class="fa-solid fa-trash"></i></div>
            `;
        } else {
            div.innerHTML = `
                <div style="width:30px; color:var(--text-secondary); font-size:14px;">${i+1}</div>
                <div style="flex:1"><h4>${s.title}</h4><p style="font-size:12px; color:var(--text-secondary)">${s.artist}</p></div>
            `;
            div.onclick = () => {
                musicQueue = [...currentPlaylistData.songs];
                originalQueue = [...musicQueue];
                queueIndex = i;
                playDirect(s);
            };
        }
        list.appendChild(div);
    });
    if(isEditingPlaylist) {
        const addBtn = document.createElement('div');
        addBtn.className = "song-row";
        addBtn.innerHTML = `<i class="fa-solid fa-plus" style="width:30px; text-align:left;"></i> <h4 style="flex:1;">Add Music to Playlist</h4>`;
        addBtn.style.color = "var(--text-secondary)";
        addBtn.onclick = () => openModal('add-song-modal');
        list.appendChild(addBtn);
    }
}

let dragStartIndex;
function handleDragStart(e) { dragStartIndex = +this.dataset.index; this.style.opacity = '0.5'; }
function handleDragOver(e) { e.preventDefault(); }
function handleDrop(e) {
    e.preventDefault();
    const dragEndIndex = +this.dataset.index;
    const itemMoved = currentPlaylistData.songs[dragStartIndex];
    currentPlaylistData.songs.splice(dragStartIndex, 1);
    currentPlaylistData.songs.splice(dragEndIndex, 0, itemMoved);
    this.style.opacity = '1';
    savePlaylistChanges();
    renderPlaylistSongs();
}

function updateEditButtonUI() {
    const btn = document.getElementById('pd-edit-btn');
    if (isEditingPlaylist) {
        btn.innerHTML = `<i class="fa-solid fa-check"></i> Done`;
        btn.style.background = "var(--accent)";
        btn.style.color = "#fff";
        btn.style.borderColor = "var(--accent)";
    } else {
        btn.innerHTML = `<i class="fa-solid fa-pen"></i> Edit`;
        btn.style.background = "transparent";
        btn.style.color = "var(--text-primary)";
        btn.style.borderColor = "var(--glass-border)";
    }
}

function toggleEditMode() {
    isEditingPlaylist = !isEditingPlaylist;
    updateEditButtonUI();
    renderPlaylistSongs();
}

async function deleteSongFromPlaylist(index) {
    if(!confirm("Remove song?")) return;
    currentPlaylistData.songs.splice(index, 1);
    await savePlaylistChanges();
    renderPlaylistSongs();
}

async function savePlaylistChanges() {
    await authFetch(`${API_URL}/playlists/update_songs`, {
        method: 'POST',
        body: JSON.stringify({ playlist_id: currentPlaylistData._id, songs: currentPlaylistData.songs })
    });
}

// Add Song Modal
let modalSearchTimeout = null;
async function handleModalSearch(e) {
    clearTimeout(modalSearchTimeout);
    modalSearchTimeout = setTimeout(async () => {
        const query = e.target.value;
        if (!query.trim()) return;
        const container = document.getElementById('add-song-results');
        container.innerHTML = "<div style='padding:20px; color:var(--text-secondary); text-align:center;'><i class='fa-solid fa-spinner fa-spin fa-2x'></i></div>";
        try {
            const res = await fetch(`${API_URL}/search_online?q=${encodeURIComponent(query)}`);
            const songs = await res.json();
            container.innerHTML = "";
            songs.forEach(s => {
                const div = document.createElement('div');
                div.className = "song-row";
                div.innerHTML = `<div class="track-art-sm" style="width:40px; height:40px;"><img src="${s.cover}"></div><div style="flex:1"><h4>${s.title}</h4><p style="font-size:12px; color:var(--text-secondary)">${s.artist}</p></div><i class="fa-solid fa-plus" style="padding:10px; cursor:pointer; color:var(--accent);"></i>`;
                div.onclick = () => addSongToCurrent(s);
                container.appendChild(div);
            });
        } catch (err) { container.innerHTML = "<p style='padding:20px; color:red'>Error searching.</p>"; }
    }, 500);
}

async function addSongToCurrent(song) {
    currentPlaylistData.songs.push(song);
    await savePlaylistChanges();
    closeModal('add-song-modal');
    renderPlaylistSongs();
}

/* --- GENERAL UI & HELPERS --- */
function updateSeekbar() {
    if (isSeeking) return; 
    if(seekSlider && isFinite(audioPlayer.currentTime)) {
        seekSlider.value = audioPlayer.currentTime;
        const currTimeElem = document.getElementById('curr-time');
        if(currTimeElem) currTimeElem.innerText = formatTime(audioPlayer.currentTime);
    }
}

function formatTime(s) {
    if(isNaN(s) || !isFinite(s)) return "0:00";
    const min = Math.floor(s / 60);
    const sec = Math.floor(s % 60);
    return `${min}:${sec < 10 ? '0'+sec : sec}`;
}

function hideAllViews() {
    ['home-view', 'search-view', 'profile-view', 'about-view', 'playlist-details-view'].forEach(id => {
        const el = document.getElementById(id);
        if(el) el.classList.add('hidden');
    });
    const header = document.getElementById('main-header');
    if(header) header.classList.remove('hidden');
    document.querySelectorAll('.menu-item').forEach(i => i.classList.remove('active'));
}

async function showHome() {
    hideAllViews();
    document.getElementById('btn-home').classList.add('active');
    document.getElementById('home-view').classList.remove('hidden');
    
    const hours = new Date().getHours();
    let greet = "Good ";
    if (hours < 12) greet += "Morning";
    else if (hours < 18) greet += "Afternoon";
    else greet += "Evening";
    const name = localStorage.getItem('display_name') || currentUser || "Viber";
    document.getElementById('greeting-text').innerText = window.innerWidth < 480 ? greet : `${greet}, ${name}`;

    const recentsDiv = document.getElementById('home-recents');
    if(recentsDiv) {
        recentsDiv.innerHTML = "";
        recentlyPlayed.slice(0, 10).forEach(item => recentsDiv.appendChild(createCard(item)));
    }
    const trendingDiv = document.getElementById('home-trending');
    if(trendingDiv && trendingDiv.innerHTML === "") { 
        trendingDiv.innerHTML = "<p style='color:var(--text-secondary); width:100%;'>Loading Trends...</p>";
        try {
            const res = await fetch(`${API_URL}/search_online?q=english+top+hits`);
            const songs = await res.json();
            trendingDiv.innerHTML = "";
            songs.forEach(s => trendingDiv.appendChild(createCard(s)));
        } catch(e) { trendingDiv.innerHTML = "<p>Failed to load.</p>"; }
    }
}

function showProfileView() {
    hideAllViews();
    document.getElementById('btn-profile').classList.add('active');
    document.getElementById('profile-view').classList.remove('hidden');
    document.getElementById('main-header').classList.add('hidden');
    
    document.getElementById('p-display-name').innerText = localStorage.getItem('display_name') || currentUser;
    document.getElementById('p-location').innerText = localStorage.getItem('bio') || "Music Lover";
    
    const av = localStorage.getItem('avatar') || DEFAULT_AVATAR;
    document.getElementById('p-avatar-container').innerHTML = `<img src="${av}">`;
    const hd = localStorage.getItem('header') || DEFAULT_HEADER;
    document.getElementById('p-header-img').src = hd;
    
    let playlists = [];
    try { playlists = JSON.parse(localStorage.getItem('playlists') || "[]"); } catch(e){}
    document.getElementById('stat-playlists').innerText = playlists.length;
    document.getElementById('stat-history').innerText = recentlyPlayed.length;
    
    switchProfileTab('playlists');
}

function selectThemeColor(el, color) {
    document.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('active'));
    el.classList.add('active');
    currentThemeColor = color;
    document.documentElement.style.setProperty('--accent', color);
}

async function saveProfile() {
    const name = document.getElementById('edit-name').value;
    const bio = document.getElementById('edit-bio').value;
    const avatar = newAvatarBase64 || localStorage.getItem('avatar') || DEFAULT_AVATAR;
    const header = newHeaderBase64 || localStorage.getItem('header') || DEFAULT_HEADER;
    
    try {
        const res = await authFetch(`${API_URL}/update_profile`, {
            method: 'POST',
            body: JSON.stringify({
                username: currentUser,
                display_name: name || currentUser,
                bio: bio,
                avatar: avatar,
                header: header,
                theme_color: currentThemeColor
            })
        });
        if(res.ok) {
            localStorage.setItem('display_name', name || currentUser);
            localStorage.setItem('bio', bio);
            localStorage.setItem('avatar', avatar);
            localStorage.setItem('header', header);
            localStorage.setItem('theme_color', currentThemeColor);
            
            closeModal('profile-modal');
            showProfileView();
        }
    } catch(e) {
        console.error("Profile save failed", e);
    }
}

function showAbout() {
    hideAllViews();
    document.getElementById('btn-about').classList.add('active');
    document.getElementById('about-view').classList.remove('hidden');
    document.getElementById('main-header').classList.add('hidden');
}

function switchProfileTab(tab) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.getElementById(`tab-${tab}`).classList.add('active');
    document.getElementById('view-playlists').classList.add('hidden');
    document.getElementById('view-recents').classList.add('hidden');
    document.getElementById(`view-${tab}`).classList.remove('hidden');
    if(tab === 'playlists') renderPlaylists(); 
    if(tab === 'recents') renderRecentsList();
}

function createCard(item) {
    const div = document.createElement('div');
    div.className = "music-card";
    const img = item.cover || (item.songs && item.songs[0]?.cover) || "https://via.placeholder.com/250";
    div.innerHTML = `
        <div class="card-img-box"><img src="${img}"></div>
        <div class="card-title">${item.title || item.name}</div>
        <div class="card-subtitle">${item.artist || item.songs?.length + ' Tracks'}</div>
        ${item.type === 'playlist' ? `<div class="delete-card-btn" onclick="deletePlaylist(event, '${item._id}')"><i class="fa-solid fa-trash"></i></div>` : ''}
    `;
    div.onclick = (e) => {
        if(e.target.closest('.delete-card-btn')) return;
        item.type === 'playlist' ? openPlaylistView(item) : playSingle(item);
    };
    return div;
}

function createListRow(song, onClick) {
    const div = document.createElement('div');
    div.className = "song-row";
    div.innerHTML = `
        <div class="track-art-sm" style="width:45px; height:45px;"><img src="${song.cover}"></div>
        <div style="flex:1"><h4>${song.title}</h4><p style="font-size:12px; color:var(--text-secondary)">${song.artist}</p></div>
        <i class="fa-solid fa-ellipsis-vertical" style="padding:10px; color:var(--text-secondary);"></i>
    `;
    div.onclick = onClick;
    div.querySelector('i').onclick = (e) => { e.stopPropagation(); openAddToPlaylistModal(song); };
    return div;
}

function addToRecents(item) {
    recentlyPlayed = recentlyPlayed.filter(s => s.title !== item.title);
    recentlyPlayed.unshift(item);
    if(recentlyPlayed.length > 20) recentlyPlayed.pop();
    localStorage.setItem('recents', JSON.stringify(recentlyPlayed));
    if(!document.getElementById('home-view').classList.contains('hidden')) showHome();
}

/* --- AUTH SECURE UI --- */
let currentAuthMode = 'login';

function switchAuthTab(mode) {
    currentAuthMode = mode;
    clearAuthError();
    const loginBtn = document.getElementById('tab-login-btn');
    const signupBtn = document.getElementById('tab-signup-btn');
    const submitBtn = document.getElementById('auth-submit-btn');
    const confirmPw = document.getElementById('confirm-pw-container');
    
    document.getElementById('password').value = "";
    document.getElementById('confirm-password').value = "";
    
    if (mode === 'login') {
        loginBtn.style.background = 'var(--glass-border)';
        loginBtn.style.color = 'var(--text-primary)';
        loginBtn.style.boxShadow = '0 5px 15px rgba(0,0,0,0.2)';
        signupBtn.style.background = 'transparent';
        signupBtn.style.color = 'var(--text-secondary)';
        signupBtn.style.boxShadow = 'none';
        submitBtn.innerText = 'Enter the Vibe';
        
        confirmPw.style.maxHeight = '0';
        confirmPw.style.opacity = '0';
        confirmPw.style.marginBottom = '0';
    } else {
        signupBtn.style.background = 'var(--glass-border)';
        signupBtn.style.color = 'var(--text-primary)';
        signupBtn.style.boxShadow = '0 5px 15px rgba(0,0,0,0.2)';
        loginBtn.style.background = 'transparent';
        loginBtn.style.color = 'var(--text-secondary)';
        loginBtn.style.boxShadow = 'none';
        submitBtn.innerText = 'Create Account';
        
        confirmPw.style.maxHeight = '80px';
        confirmPw.style.opacity = '1';
        confirmPw.style.marginBottom = '25px';
    }
}

function clearAuthError() {
    const err = document.getElementById('auth-error-msg');
    err.style.display = 'none';
    err.style.color = '#ff4b4b'; // reset defaults
    err.style.background = 'rgba(255,50,50,0.1)';
    err.style.borderColor = 'rgba(255,50,50,0.3)';
    
    document.getElementById('username').style.borderColor = 'var(--glass-border)';
    document.getElementById('password').style.borderColor = 'var(--glass-border)';
    document.getElementById('confirm-password').style.borderColor = 'var(--glass-border)';
}

function showAuthError(msg) {
    const err = document.getElementById('auth-error-msg');
    err.innerText = msg;
    err.style.display = 'block';
    const u = document.getElementById('username');
    const p = document.getElementById('password');
    if (!u.value.trim() || u.value.trim().length < 3) u.style.borderColor = '#ff4b4b';
    if (!p.value || p.value.length < 6) p.style.borderColor = '#ff4b4b';
}

function togglePasswordVisibility() {
    const pw = document.getElementById('password');
    const icon = document.getElementById('toggle-pw-btn');
    if (pw.type === 'password') {
        pw.type = 'text';
        icon.className = 'fa-solid fa-eye-slash';
        icon.style.color = 'var(--accent)';
    } else {
        pw.type = 'password';
        icon.className = 'fa-solid fa-eye';
        icon.style.color = 'var(--text-secondary)';
    }
}

async function handleAuthSubmit() {
    const u = document.getElementById('username').value.trim();
    const p = document.getElementById('password').value;
    const cp = document.getElementById('confirm-password').value;
    
    if (!u) return showAuthError("Username is required.");
    if (u.length < 3) return showAuthError("Username must be at least 3 characters.");
    if (!p) return showAuthError("Password is required.");
    
    if (currentAuthMode === 'signup') {
        if (p.length < 6) return showAuthError("Password must be at least 6 characters.");
        if (p !== cp) {
            document.getElementById('confirm-password').style.borderColor = '#ff4b4b';
            return showAuthError("Passwords do not match.");
        }
    }
    
    document.getElementById('auth-submit-btn').style.display = 'none';
    document.getElementById('auth-loading').style.display = 'block';
    clearAuthError();
    
    if (currentAuthMode === 'login') {
        try {
            const res = await fetch(`${API_URL}/login`, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({username: u, password: p})});
            const data = await res.json();
            if(res.ok) {
                token = data.access_token; currentUser = data.username;
                localStorage.setItem('token', token); localStorage.setItem('user', currentUser);
                localStorage.setItem('display_name', data.display_name); 
                localStorage.setItem('avatar', data.avatar || DEFAULT_AVATAR);
                localStorage.setItem('header', data.header || DEFAULT_HEADER);
                if (data.theme_color) {
                    localStorage.setItem('theme_color', data.theme_color);
                    document.documentElement.style.setProperty('--accent', data.theme_color);
                    currentThemeColor = data.theme_color;
                }
                document.getElementById('password').value = "";
                
                const userVol = localStorage.getItem('volume_' + currentUser);
                if (userVol && audioPlayer) {
                    audioPlayer.volume = parseFloat(userVol);
                    if (volSlider) volSlider.value = userVol;
                }
                
                showApp();
            } else showAuthError("Login Failed: Incorrect username or password.");
        } catch(e) { showAuthError("Network Error. Please try again later."); }
    } else {
        try {
            const res = await fetch(`${API_URL}/register`, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({username: u, password: p})});
            if(res.ok) {
                document.getElementById('password').value = "";
                switchAuthTab('login');
                const err = document.getElementById('auth-error-msg');
                err.innerText = "Account created safely! Please login.";
                err.style.color = "var(--accent)";
                err.style.background = "rgba(41,204,112,0.1)";
                err.style.borderColor = "var(--accent)";
                err.style.display = "block";
            }
            else {
                const d = await res.json();
                showAuthError(d.detail);
            }
        } catch(e) { showAuthError("Network Error. Please try again later."); }
    }
    document.getElementById('auth-submit-btn').style.display = 'block';
    document.getElementById('auth-loading').style.display = 'none';
}

function logout() { localStorage.clear(); location.reload(); }

function showApp() { 
    document.getElementById('auth-screen').classList.remove('active'); 
    document.getElementById('app-screen').classList.remove('hidden'); 
    showHome(); 
}

function openModal(id) { document.getElementById(id).classList.add('active'); }
function closeModal(id) { document.getElementById(id).classList.remove('active'); }

let songToAdd = null;
function addCurrentToPlaylist() {
    if (musicQueue && musicQueue[queueIndex]) {
        openAddToPlaylistModal(musicQueue[queueIndex]);
    }
}
function openAddToPlaylistModal(song) { songToAdd = song; openModal('select-playlist-modal'); loadPlaylistsForSelection(); }

async function loadPlaylistsForSelection() {
    const list = document.getElementById('playlist-selection-list');
    const res = await authFetch(`${API_URL}/playlists/${currentUser}`);
    const playlists = await res.json();
    list.innerHTML = "";
    playlists.forEach(p => {
        const div = document.createElement('div'); div.className = "song-row"; 
        div.innerHTML = `<i class="fa-solid fa-list" style="color:var(--text-secondary);"></i> <h4>${p.name}</h4>`;
        div.onclick = async () => {
            await authFetch(`${API_URL}/playlists/add_song`, { method: 'POST', body: JSON.stringify({playlist_id: p._id, song: songToAdd})});
            closeModal('select-playlist-modal');
        };
        list.appendChild(div);
    });
}

async function createPlaylist() {
    const name = document.getElementById('new-playlist-name').value;
    if (!name.trim()) return alert("Please enter a playlist name");
    await authFetch(`${API_URL}/playlists/create`, { method: 'POST', body: JSON.stringify({username: currentUser, name: name})});
    closeModal('create-playlist-modal'); 
    document.getElementById('new-playlist-name').value = "";
    renderPlaylists();
}

async function deletePlaylist(event, playlistId) {
    event.stopPropagation();
    if(!confirm("Are you sure you want to delete this playlist?")) return;
    try {
        const res = await authFetch(`${API_URL}/playlists/${playlistId}`, { method: 'DELETE' });
        if (res.ok) {
            const btn = event.target.closest('.music-card');
            if(btn) btn.remove();
        }
    } catch (e) { alert("Server error."); }
}

async function saveProfile() {
    const n = document.getElementById('edit-name').value;
    const b = document.getElementById('edit-bio').value;
    const av = newAvatarBase64 || localStorage.getItem('avatar') || DEFAULT_AVATAR;
    const hd = newHeaderBase64 || localStorage.getItem('header') || DEFAULT_HEADER;
    await authFetch(`${API_URL}/update_profile`, { method: 'POST', body: JSON.stringify({username: currentUser, display_name: n, bio: b, avatar: av, header: hd})});
    localStorage.setItem('display_name', n); localStorage.setItem('bio', b); localStorage.setItem('avatar', av); localStorage.setItem('header', hd);
    closeModal('profile-modal'); showProfileView();
}

async function renderPlaylists() {
    const list = document.getElementById('playlist-list');
    if(!list) return;
    list.innerHTML = "<p style='color:var(--text-secondary); width:100%;'>Loading...</p>";
    try {
        const res = await authFetch(`${API_URL}/playlists/${currentUser}`);
        const playlists = await res.json();
        list.innerHTML = "";
        if (playlists.length === 0) { list.innerHTML = "<p style='padding:20px; color:var(--text-secondary); width:100%;'>No playlists yet.</p>"; return; }
        playlists.forEach(p => {
            p.type = 'playlist';
            list.appendChild(createCard(p));
        });
    } catch(e) { list.innerHTML = "<p>Error loading playlists.</p>"; }
}

function renderRecentsList() {
    const list = document.getElementById('profile-recents-list');
    if(!list) return;
    list.innerHTML = "";
    recentlyPlayed.forEach(s => list.appendChild(createListRow(s, () => playSingle(s))));
}

let mainSearchTimeout = null;
async function handleSearch(e) {
    const query = e.target.value;
    if (!query.trim()) return;
    const searchBar = document.querySelector('#main-header .search-bar');
    if (searchBar) searchBar.classList.add('active');
    hideAllViews();
    document.getElementById('search-view').classList.remove('hidden');
    
    clearTimeout(mainSearchTimeout);
    mainSearchTimeout = setTimeout(async () => {
        const container = document.getElementById('song-list-container');
        container.innerHTML = `<div style="text-align:center; padding:40px; color:var(--accent);"><i class="fa-solid fa-spinner fa-spin fa-2x"></i></div>`;
        try {
            const res = await fetch(`${API_URL}/search_online?q=${encodeURIComponent(query)}`);
            const songs = await res.json();
            container.innerHTML = "";
            if (!songs || songs.length === 0) { container.innerHTML = "<p style='text-align:center; padding:20px; color:var(--text-secondary);'>No results found.</p>"; return; }
            songs.forEach(s => {
                const row = createListRow(s, () => playSingle(s));
                container.appendChild(row);
            });
        } catch(e) { container.innerHTML = "<p style='text-align:center; padding:20px; color:#ff4b4b;'>Search failed. Please try again.</p>"; }
    }, 500);
}

function triggerSearch(e) { 
    if (e.target.tagName === 'INPUT') return;
    const bar = e.currentTarget; 
    bar.classList.toggle('active'); 
    const input = bar.querySelector('input');
    if(input && bar.classList.contains('active')) input.focus(); 
}

function setupDropZone(zoneId, previewId, callback) {
    const zone = document.getElementById(zoneId); if (!zone) return;
    const input = zone.querySelector('.drop-zone__input');
    const preview = document.getElementById(previewId);
    zone.addEventListener('click', () => input.click());
    input.addEventListener('change', () => { if(input.files.length) { updateThumbnail(zone, input.files[0], preview); readFile(input.files[0], callback); }});
    zone.addEventListener('dragover', (e) => { e.preventDefault(); zone.style.borderColor = 'var(--accent)'; });
    ['dragleave', 'dragend'].forEach(type => zone.addEventListener(type, () => zone.style.borderColor = 'var(--glass-border)'));
    zone.addEventListener('drop', (e) => { e.preventDefault(); if(e.dataTransfer.files.length) { input.files = e.dataTransfer.files; updateThumbnail(zone, e.dataTransfer.files[0], preview); readFile(e.dataTransfer.files[0], callback); } zone.style.borderColor = 'var(--glass-border)'; });
}

function updateThumbnail(zone, file, preview) {
    preview.style.display = 'block'; preview.style.backgroundImage = `url('${URL.createObjectURL(file)}')`;
    const prompt = zone.querySelector('.drop-zone__prompt'); if(prompt) prompt.style.display = 'none';
}

function readFile(file, callback) { const reader = new FileReader(); reader.onload = (e) => callback(e.target.result); reader.readAsDataURL(file); }