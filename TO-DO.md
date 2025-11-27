- Import chord-over-lyric - refine to work with other than UG official
- switch between ChordPro and CoL 
- Add chord viewer and click on chords
 - RUn through and delete unused/unreferenced code
 - View by Keys in Songs
- MIDI listener and config for functions (sroll/page up/down. Metronome/ascroll start/stop)
- Music director features - cue sending and syncing 
- DB in iCloud


##Future features
- Use audio detection to start auto-scroll. When it detects the chord progression of the song it starts
- Set up search for duration and time signature using Spotify API
- TOOLS
    -Tuner, metronome, MIDI sender

SETTINGS
 - Color for sidebar
 - Add option to search full text of song
 - Light/Dark mode
 - Metronome sounds

 PUNCHLIST

  - Go back and fix count-in display issue, not showing all 4 counts. countin_debug.md is in the prompts folder
  - Detection for tab in parser not working quite right
        -Ex. I Hold On - Dierks Bentley. It is detecting the first line as a title and making it a tag
        - I think its also adding the chordpro-style metadata tags. Stop doing that
  - Make tools
  - Fix Metronome delay
  - iCloud for db storage
- Different UI for phones - sidebar whole screen
- Not refreshing quickly on db changes
- No back button once in a Tag in Songs
- Capo reminder when loading song 
 - Tools: MIDI Sender and MIDI Viewer 

**MIDI Actions testing
 - When starting metronome, it missed an accent beat
 - When metronome is active and repeat count in is executed, it needs to wait for the "1" and then execute inline and in time with the existing metronome.
 - Evaluate/make a 'start metronome after count in' option for autoscroll
 - 


- App is not calling  the metadata search on convert button. I want the convert button to kick off the same process as the Get Song Info button if a song title is present
- Change restriction so that only a song title is required to attempt Get Song Info. Make the metadata search process only require a title as well
- Not opening in editor when switch back to NextChord
- Duration is importing just like all the other metadata, but it is not saving. The other metadata is saving properly
- When the capo is adjusted using the adjustment buttons in capo_button.dart, that change is not being persisted when I leave the song and come back. I want that capo setting to “stick” when adjusted with the capo button, just as if it were changed in the song editor. 
   - If a Setlist is active when those changes are made with the button, the changes need to save so that they are only active when that setlist is active. 
   - If those buttons are used to make adjustments when a setlist is NOT active, the changes need to persist to the song itself in the database. 
- Autoscroll and metronome remain active when changing to another song. These should be reset on song load
- Autoscroll not showing the duration that I’m seeing in the edit field. We also need to make autoscroll adjustments persistent. Revisit this later and fix both at the same time
- Put add song button on the main screen from any Songs view 
- How do I query the db from the command line? 
- I noticed duration for songs is currently stored in the database in a Notes field. Why is this not using the duration field of the database? 
