- Import chord-over-lyric - refine to work with other than UG official
- switch between ChordPro and CoL 
- Autoscroll based on time functionality 
- Add metronome functionality
- Add chord viewer and click on chords
 - RUn through and delete unused/unreferenced code
 - View by Keys in Songs

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


  - Long press not bringing up menu in Setlist view
  - Long press and add to setlist
  - Edit button in Setlist page of sidebar is not aligned to the right side
  - Detection for tab in parser not working quite right
        -Ex. I Hold On - Dierks Bentley. It is detecting the first line as a title and making it a tag
        - I think its also adding the chordpro-style metadata tags. Stop doing that
  - Make tools
  - Fix Metronome delay


Now I want to add an option in the long press menu that is called up from the Songs lists in the sidebar. This option should allow the user to add the song to a setlist.

This option will access a new add_songs_to_setlist_modal that has the same basic design and color scheme as the midi_settings_modal. We will need a list of the set lists, with checkboxes so that users can add songs to multiple set lists if desired. 




