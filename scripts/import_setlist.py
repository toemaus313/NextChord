#!/usr/bin/env python3
"""
Script to import a setlist from a text file into NextChord database.
"""

import sqlite3
import json
import uuid
import re
import os
import sys
from datetime import datetime
from pathlib import Path

def parse_setlist_file(file_path):
    """Parse the setlist file and extract songs with keys."""
    songs = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        # Parse format: "Title - Artist - Key"
        # Handle cases where artist might have dashes in the name
        parts = line.split(' - ')
        if len(parts) >= 3:
            title = parts[0].strip()
            # Artist might contain dashes, so join all middle parts
            artist = ' - '.join(parts[1:-1]).strip()
            key = parts[-1].strip()
            
            # Clean up the key (remove brackets if present)
            key = key.strip('[]')
            
            songs.append({
                'title': title,
                'artist': artist,
                'key': key
            })
        elif len(parts) == 2:
            # Format: "Title - Artist" (no key)
            title = parts[0].strip()
            artist = parts[1].strip()
            songs.append({
                'title': title,
                'artist': artist,
                'key': None
            })
    
    return songs

def find_database_path():
    """Find the NextChord database file."""
    home = os.path.expanduser('~')
    
    # Possible database locations
    possible_paths = [
        # macOS
        f"{home}/Library/Containers/us.antonovich.nextchord/Data/Documents/nextchord_db.sqlite",
        f"{home}/Documents/nextchord_db.sqlite",
        # Windows
        f"{home}\\Documents\\nextchord_db.sqlite",
        f"{home}\\AppData\\Local\\nextchord_db.sqlite",
        f"{home}\\AppData\\Roaming\\nextchord_db.sqlite",
        # Linux/Other
        f"{home}/nextchord_db.sqlite",
        f"{home}/Documents/nextchord_db.sqlite",
        # Current directory
        "nextchord_db.sqlite"
    ]
    
    for path in possible_paths:
        if os.path.exists(path):
            return path
    
    # If not found in standard locations, search in Documents
    documents_dir = os.path.join(home, "Documents")
    if os.path.exists(documents_dir):
        for root, dirs, files in os.walk(documents_dir):
            for file in files:
                if file.endswith('.sqlite'):
                    found_path = os.path.join(root, file)
                    print(f"Found database: {found_path}")
                    return found_path
    
    return None

def match_song_in_database(conn, title, artist, key):
    """Find a song in the database by title and artist."""
    cursor = conn.cursor()
    
    # Try exact match first
    cursor.execute(
        "SELECT id, title, artist, key FROM songs WHERE title = ? AND artist = ? AND is_deleted = 0",
        (title, artist)
    )
    result = cursor.fetchone()
    
    if result:
        return result
    
    # Try fuzzy match - ignore case and extra spaces
    cursor.execute(
        """SELECT id, title, artist, key FROM songs 
           WHERE LOWER(REPLACE(title, ' ', '')) = LOWER(REPLACE(?, ' ', '')) 
           AND LOWER(REPLACE(artist, ' ', '')) = LOWER(REPLACE(?, ' ', '')) 
           AND is_deleted = 0""",
        (title, artist)
    )
    result = cursor.fetchone()
    
    if result:
        return result
    
    # Try just title match
    cursor.execute(
        "SELECT id, title, artist, key FROM songs WHERE title = ? AND is_deleted = 0",
        (title,)
    )
    result = cursor.fetchone()
    
    return result

def create_setlist(conn, setlist_name, songs):
    """Create a new setlist in the database."""
    cursor = conn.cursor()
    
    # Get current timestamp
    now = int(datetime.now().timestamp() * 1000)
    
    # Create setlist items
    setlist_items = []
    songs_found = 0
    songs_missing = []
    
    for idx, song in enumerate(songs):
        matched = match_song_in_database(conn, song['title'], song['artist'], song['key'])
        
        if matched:
            song_id, db_title, db_artist, db_key = matched
            
            # Calculate transpose steps if key is different
            transpose_steps = 0
            if song['key'] and db_key:
                # Simple key difference calculation
                # This is a simplified version - proper music theory would be more complex
                key_order = ['C', 'C#', 'Db', 'D', 'D#', 'Eb', 'E', 'F', 'F#', 'Gb', 'G', 'G#', 'Ab', 'A', 'A#', 'Bb', 'B']
                try:
                    current_idx = key_order.index(db_key) if db_key in key_order else 0
                    target_idx = key_order.index(song['key']) if song['key'] in key_order else 0
                    transpose_steps = target_idx - current_idx
                except (ValueError, IndexError):
                    transpose_steps = 0
            
            setlist_items.append({
                'type': 'song',
                'id': str(uuid.uuid4()),
                'songId': song_id,
                'order': idx,
                'transposeSteps': transpose_steps,
                'capo': 0
            })
            songs_found += 1
            print(f"✓ Found: {song['title']} - {song['artist']}")
        else:
            songs_missing.append(song)
            print(f"✗ Missing: {song['title']} - {song['artist']}")
    
    if not setlist_items:
        print("\nNo songs found in database. Cannot create setlist.")
        return None
    
    # Create the setlist
    setlist_id = str(uuid.uuid4())
    items_json = json.dumps(setlist_items)
    
    cursor.execute("""
        INSERT INTO setlists (
            id, name, items, notes, image_path, setlist_specific_edits_enabled,
            created_at, updated_at, is_deleted
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        setlist_id,
        setlist_name,
        items_json,
        f"Imported on {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        None,
        1,  # setlist_specific_edits_enabled
        now,
        now,
        0   # is_deleted
    ))
    
    conn.commit()
    
    print(f"\nSetlist created successfully!")
    print(f"Name: {setlist_name}")
    print(f"Songs found: {songs_found}")
    print(f"Songs missing: {len(songs_missing)}")
    
    if songs_missing:
        print("\nMissing songs:")
        for song in songs_missing:
            print(f"  - {song['title']} - {song['artist']}")
    
    return setlist_id

def main():
    if len(sys.argv) != 2:
        print("Usage: python import_setlist.py <setlist_file>")
        print("Example: python import_setlist.py Setlist")
        sys.exit(1)
    
    setlist_file = sys.argv[1]
    
    if not os.path.exists(setlist_file):
        print(f"Error: File '{setlist_file}' not found.")
        sys.exit(1)
    
    # Parse the setlist
    print(f"Parsing setlist from: {setlist_file}")
    songs = parse_setlist_file(setlist_file)
    
    if not songs:
        print("No songs found in the file.")
        sys.exit(1)
    
    print(f"\nFound {len(songs)} songs in the setlist:")
    for song in songs[:5]:  # Show first 5
        print(f"  - {song['title']} - {song['artist']} - {song.get('key', 'N/A')}")
    if len(songs) > 5:
        print(f"  ... and {len(songs) - 5} more")
    
    # Find database
    db_path = find_database_path()
    if not db_path:
        print("\nError: NextChord database not found.")
        print("Please make sure NextChord has been run at least once.")
        sys.exit(1)
    
    print(f"\nUsing database: {db_path}")
    
    # Connect to database
    try:
        conn = sqlite3.connect(db_path)
        print("Database connected successfully.")
    except sqlite3.Error as e:
        print(f"Error connecting to database: {e}")
        sys.exit(1)
    
    # Create the setlist
    setlist_name = "BWB-2026"
    print(f"\nCreating setlist: {setlist_name}")
    
    try:
        result = create_setlist(conn, setlist_name, songs)
        if result:
            print(f"\n✓ Setlist '{setlist_name}' created with ID: {result}")
        else:
            print("\n✗ Failed to create setlist.")
    except Exception as e:
        print(f"\nError: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    main()
