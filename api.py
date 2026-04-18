import os
import requests
import base64
import html
from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Response, Request, Depends
from fastapi.responses import StreamingResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from pymongo import MongoClient
from passlib.context import CryptContext
from jose import jwt
from dotenv import load_dotenv
from bson import ObjectId
from cachetools import TTLCache
from pyDes import des, ECB, PAD_PKCS5

load_dotenv(dotenv_path=".env")

app = FastAPI()
auth_scheme = HTTPBearer()

MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("DB_NAME")
SECRET_KEY = os.getenv("SECRET_KEY") or "supersecretkey123"
ALGORITHM = "HS256"
API_BASE_URL = os.getenv("RENDER_EXTERNAL_URL") or "http://127.0.0.1:8000"

DEFAULT_AVATAR = "https://cdn-icons-png.flaticon.com/512/847/847969.png"
DEFAULT_HEADER = "https://images.unsplash.com/photo-1514525253440-b393452e8d26?q=80&w=2000&auto=format&fit=crop"

url_cache = TTLCache(maxsize=1000, ttl=3600)

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
    theme_color: Optional[str] = "#29cc70"

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


# JIOSAAVN HELPER FUNCTIONS
def decrypt_url(url):
    try:
        des_cipher = des(b"38346591", ECB, padmode=PAD_PKCS5)
        enc_url = base64.b64decode(url.strip())
        dec_url = des_cipher.decrypt(enc_url, padmode=PAD_PKCS5).decode('utf-8')
        return dec_url
    except Exception:
        return ""

def get_saavn_headers():
    return {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }

def process_saavn_song(r):
    try:
        title = r.get('title') or r.get('song') or 'Unknown Title'
        title = html.unescape(title)
        more_info = r.get('more_info', {})
        
        artist = r.get('primary_artists') or r.get('singers') or "Unknown Artist"
        if artist == "Unknown Artist":
            if 'singers' in more_info and more_info['singers']:
                artist = more_info['singers']
            elif 'primary_artists' in more_info and more_info['primary_artists']:
                artist = more_info['primary_artists']
        artist = html.unescape(artist)
            
        cover = r.get('image', DEFAULT_AVATAR).replace('150x150', '500x500')
        videoId = r.get('id')
        
        return {
            "title": title,
            "artist": artist,
            "filename": f"/stream/{videoId}", 
            "cover": cover,
            "source": "saavn",
            "videoId": videoId 
        }
    except Exception:
        return None

@app.get('/favicon.ico', include_in_schema=False)
async def favicon():
    return Response(status_code=204)

@app.post("/register")
async def register(user: UserAuth):
    if users_col.find_one({"username": user.username}):
        raise HTTPException(status_code=400, detail="Username already taken")
    users_col.insert_one({
        "username": user.username, "password": get_password_hash(user.password), 
        "display_name": user.username, "bio": "Music Lover", "avatar": DEFAULT_AVATAR, "header": DEFAULT_HEADER, "theme_color": "#29cc70"
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
        "bio": db_user.get("bio", ""), "avatar": db_user.get("avatar", DEFAULT_AVATAR), "header": db_user.get("header", DEFAULT_HEADER), "theme_color": db_user.get("theme_color", "#29cc70")
    }

@app.post("/update_profile")
async def update_profile(data: ProfileUpdate, current_user: str = Depends(get_current_user)):
    if data.username != current_user:
        raise HTTPException(status_code=403, detail="Not authorized")
    users_col.update_one({"username": data.username}, {"$set": {"display_name": data.display_name, "bio": data.bio, "avatar": data.avatar, "header": data.header, "theme_color": data.theme_color}})
    return {"message": "Updated"}

@app.get("/search_online")
def search_online(q: str):
    if not q: return []
    try:
        url = f"https://www.jiosaavn.com/api.php?__call=search.getResults&q={q}&n=20&p=1&_format=json&_marker=0&ctx=android"
        res = requests.get(url, headers=get_saavn_headers())
        data = res.json()
        
        results = []
        if 'results' in data:
            for r in data['results']:
                song_obj = process_saavn_song(r)
                if song_obj:
                    results.append(song_obj)
        return results
    except Exception as e:
        print(f"Search API Error: {e}")
        return []

@app.get("/recommendations")
def get_recommendations(video_id: Optional[str] = None, title: Optional[str] = None, artist: Optional[str] = ""):
    try:
        target_id = video_id
        if not target_id or target_id == "undefined":
            # Search to get ID
            if title:
                s_url = f"https://www.jiosaavn.com/api.php?__call=search.getResults&q={title} {artist}&n=1&p=1&_format=json&_marker=0&ctx=android"
                s_res = requests.get(s_url, headers=get_saavn_headers()).json()
                if 'results' in s_res and len(s_res['results']) > 0:
                    target_id = s_res['results'][0].get('id')
            
        if not target_id: return []

        url = f"https://www.jiosaavn.com/api.php?__call=reco.getreco&pid={target_id}&_format=json&_marker=0&ctx=android"
        res = requests.get(url, headers=get_saavn_headers())
        data = res.json()
        
        results = []
        if isinstance(data, dict):
            if target_id in data:
                data = data[target_id]
            elif len(data.keys()) > 0:
                data = data[list(data.keys())[0]]

        if isinstance(data, list):
            for r in data:
                song_obj = process_saavn_song(r)
                if song_obj:
                    results.append(song_obj)
        return results
    except Exception:
        return []

@app.get("/stream/{video_id}")
async def stream_audio(video_id: str):
    if video_id in url_cache:
        return RedirectResponse(url=url_cache[video_id])

    try:
        song_url = f"https://www.jiosaavn.com/api.php?__call=song.getDetails&pids={video_id}&_format=json&_marker=0&ctx=android"
        res = requests.get(song_url, headers=get_saavn_headers())
        data = res.json()
        
        if video_id in data:
            song_info = data[video_id]
            enc_url = song_info.get('encrypted_media_url', '')
            if enc_url:
                dec_url = decrypt_url(enc_url)
                # Ensure high quality
                if "_96.mp4" in dec_url:
                    dec_url = dec_url.replace("_96.mp4", "_320.mp4")
                if "_160.mp4" in dec_url:
                    dec_url = dec_url.replace("_160.mp4", "_320.mp4")
                
                url_cache[video_id] = dec_url
                return RedirectResponse(url=dec_url)
                
        raise HTTPException(status_code=404, detail="Stream URL not found")
    except Exception as e:
        print(f"Streaming Error: {e}")
        raise HTTPException(status_code=500, detail="Internal Error")

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

app.mount("/", StaticFiles(directory="public", html=True), name="static")