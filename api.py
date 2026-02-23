import os
import requests
import httpx
from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Response, Request, Depends
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from pymongo import MongoClient
from passlib.context import CryptContext
from jose import jwt
from dotenv import load_dotenv
from ytmusicapi import YTMusic
from yt_dlp import YoutubeDL
from bson import ObjectId
from cachetools import TTLCache

load_dotenv(dotenv_path="env.env")

app = FastAPI()
auth_scheme = HTTPBearer()

MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("DB_NAME")
SECRET_KEY = os.getenv("SECRET_KEY") or "supersecretkey123"
ALGORITHM = "HS256"
API_BASE_URL = "https://vibematcher-d9lt.onrender.com"

DEFAULT_AVATAR = "https://cdn-icons-png.flaticon.com/512/847/847969.png"
DEFAULT_HEADER = "https://images.unsplash.com/photo-1514525253440-b393452e8d26?q=80&w=2000&auto=format&fit=crop"

url_cache = TTLCache(maxsize=1000, ttl=3600)

PIPED_INSTANCES = [
    "https://pipedapi.kavin.rocks",
    "https://pipedapi.syncular.network",
    "https://api.piped.projectsegfau.lt",
    "https://pipedapi.smnz.de",
    "https://pipedapi.adminforge.de",
    "https://pipedapi.tokhmi.xyz"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = MongoClient(MONGO_URI)
db = client[DB_NAME]
users_col = db["users"]
playlists_col = db["playlists"]

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

class UserAuth(BaseModel):
    username: str
    password: str

class ProfileUpdate(BaseModel):
    username: str
    display_name: str
    bio: Optional[str] = ""
    avatar: Optional[str] = ""
    header: Optional[str] = ""

class PlaylistCreate(BaseModel):
    username: str
    name: str

class AddSongToPlaylist(BaseModel):
    playlist_id: str
    song: dict

class PlaylistUpdateSongs(BaseModel):
    playlist_id: str
    songs: list

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=60)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def get_password_hash(password):
    return pwd_context.hash(password)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

async def get_current_user(token: HTTPAuthorizationCredentials = Depends(auth_scheme)):
    try:
        payload = jwt.decode(token.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return username
    except Exception:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

@app.get('/favicon.ico', include_in_schema=False)
async def favicon():
    return Response(status_code=204)

@app.post("/register")
async def register(user: UserAuth):
    if users_col.find_one({"username": user.username}):
        raise HTTPException(status_code=400, detail="Username already taken")
    users_col.insert_one({
        "username": user.username, "password": get_password_hash(user.password), 
        "display_name": user.username, "bio": "Music Lover", "avatar": DEFAULT_AVATAR, "header": DEFAULT_HEADER 
    })
    return {"message": "User created"}

@app.post("/login")
async def login(user: UserAuth):
    db_user = users_col.find_one({"username": user.username})
    if not db_user or not verify_password(user.password, db_user["password"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {
        "access_token": create_access_token({"sub": user.username}), 
        "username": user.username, "display_name": db_user.get("display_name", user.username), 
        "bio": db_user.get("bio", ""), "avatar": db_user.get("avatar", DEFAULT_AVATAR), "header": db_user.get("header", DEFAULT_HEADER) 
    }

@app.post("/update_profile")
async def update_profile(data: ProfileUpdate, current_user: str = Depends(get_current_user)):
    if data.username != current_user:
        raise HTTPException(status_code=403, detail="Not authorized")
    users_col.update_one({"username": data.username}, {"$set": {"display_name": data.display_name, "bio": data.bio, "avatar": data.avatar, "header": data.header}})
    return {"message": "Updated"}

@app.get("/search_online")
def search_online(q: str):
    if not q: return []
    try:
        yt = YTMusic()
        results = yt.search(q, filter='songs')
        data = []
        for r in results[:20]: 
            try:
                video_id = r.get('videoId')
                if not video_id: continue
                thumbnails = r.get('thumbnails', [])
                cover_url = thumbnails[-1]['url'] if thumbnails else DEFAULT_AVATAR
                artists = r.get('artists', [])
                artist_name = ", ".join([a['name'] for a in artists]) if artists else "Unknown"

                data.append({
                    "title": r.get('title', 'Unknown Title'),
                    "artist": artist_name,
                    "filename": f"{API_BASE_URL}/stream_yt/{video_id}", 
                    "cover": cover_url,
                    "source": "online",
                    "videoId": video_id 
                })
            except Exception:
                continue
        return data
    except Exception:
        return []

@app.get("/recommendations")
def get_recommendations(video_id: Optional[str] = None, title: Optional[str] = None, artist: Optional[str] = ""):
    try:
        yt = YTMusic()
        target_id = video_id
        if not target_id or target_id == "undefined":
            if title:
                search_results = yt.search(f"{title} {artist}", filter='songs')
                if search_results:
                    target_id = search_results[0].get('videoId')
            
        if not target_id: return []

        watch_list = yt.get_watch_playlist(videoId=target_id, limit=10)
        tracks = watch_list.get('tracks', [])
        
        results = []
        for t in tracks:
            vid = t.get('videoId')
            if not vid or vid == target_id: continue
            
            results.append({
                "title": t.get('title', 'Unknown'),
                "artist": t['artists'][0]['name'] if t.get('artists') else "Unknown",
                "filename": f"{API_BASE_URL}/stream_yt/{vid}",
                "cover": t['thumbnail'][0]['url'] if t.get('thumbnail') else DEFAULT_AVATAR,
                "source": "recommendation",
                "videoId": vid
            })
        return results
    except Exception:
        return []

@app.get("/stream_yt/{video_id}")
async def stream_yt(video_id: str, request: Request):
    final_stream_url = None
    stream_headers = {}

    if video_id in url_cache:
        cached_data = url_cache[video_id]
        if isinstance(cached_data, tuple):
            final_stream_url, stream_headers = cached_data

    if not final_stream_url:
        try:
            ydl_opts = {'format': 'bestaudio/best', 'quiet': True, 'noplaylist': True, 'extractor_args': {'youtube': {'player_client': ['android', 'ios']}}}
            with YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(f"https://www.youtube.com/watch?v={video_id}", download=False)
                final_stream_url = info['url']
                stream_headers = info.get('http_headers', {})
                url_cache[video_id] = (final_stream_url, stream_headers)
        except Exception as e:
            print(f"yt-dlp blocked by YouTube. Attempting backups...")
            for base_url in PIPED_INSTANCES:
                try:
                    # Increased timeout to 10 seconds to allow slow free servers to respond
                    r = requests.get(f"{base_url}/streams/{video_id}", timeout=10)
                    if r.status_code == 200:
                        data = r.json()
                        for s in data.get('audioStreams', []):
                            if s.get('mimeType', '').startswith('audio/'):
                                final_stream_url = s['url']
                                url_cache[video_id] = (final_stream_url, {})
                                print(f"Successfully streamed using backup: {base_url}")
                                break
                    if final_stream_url: break
                except Exception as ex: 
                    print(f"Backup {base_url} failed or timed out.")
                    continue
            
            if not final_stream_url:
                raise HTTPException(status_code=404, detail="Could not stream from any source")

    client = httpx.AsyncClient()
    headers = {"Range": request.headers.get("range", "bytes=0-")}
    headers.update(stream_headers)
    
    req = client.build_request("GET", final_stream_url, headers=headers)
    r = await client.send(req, stream=True)

    if r.status_code >= 400:
        await r.aclose()
        await client.aclose()
        if video_id in url_cache: del url_cache[video_id]
        raise HTTPException(status_code=r.status_code)

    # Use a generator to yield chunks, then safely close the client
    async def stream_generator():
        try:
            async for chunk in r.aiter_bytes():
                yield chunk
        finally:
            await r.aclose()
            await client.aclose()

    return StreamingResponse(
        stream_generator(),
        status_code=r.status_code,
        headers={k: v for k, v in r.headers.items() if k.lower() in ["content-range", "content-length", "accept-ranges"]},
        media_type=r.headers.get("content-type", "audio/webm")
    )

@app.post("/playlists/create")
async def create_playlist(data: PlaylistCreate, current_user: str = Depends(get_current_user)):
    new_playlist = {"name": data.name, "username": current_user, "songs": [], "created_at": datetime.utcnow()}
    result = playlists_col.insert_one(new_playlist)
    return {"message": "Playlist created", "id": str(result.inserted_id)}

@app.get("/playlists/{username}")
async def get_playlists(username: str, current_user: str = Depends(get_current_user)):
    if username != current_user: raise HTTPException(status_code=403, detail="Unauthorized")
    playlists = list(playlists_col.find({"username": username}))
    for p in playlists: p["_id"] = str(p["_id"]) 
    return playlists

@app.post("/playlists/add_song")
async def add_song_to_playlist(data: AddSongToPlaylist, current_user: str = Depends(get_current_user)):
    playlist = playlists_col.find_one({"_id": ObjectId(data.playlist_id), "username": current_user})
    if not playlist: raise HTTPException(status_code=403, detail="Not your playlist")
    playlists_col.update_one({"_id": ObjectId(data.playlist_id)}, {"$push": {"songs": data.song}})
    return {"message": "Song added"}

@app.post("/playlists/update_songs")
async def update_playlist_songs(data: PlaylistUpdateSongs, current_user: str = Depends(get_current_user)):
    playlists_col.update_one({"_id": ObjectId(data.playlist_id), "username": current_user}, {"$set": {"songs": data.songs}})
    return {"message": "Playlist updated"}

@app.delete("/playlists/{playlist_id}")
async def delete_playlist(playlist_id: str, current_user: str = Depends(get_current_user)):
    playlists_col.delete_one({"_id": ObjectId(playlist_id), "username": current_user})
    return {"message": "Deleted"}

app.mount("/", StaticFiles(directory=".", html=True), name="static")