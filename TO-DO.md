- Import chord-over-lyric - refine to work with other than UG official
- switch between ChordPro and CoL 
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

  - Detection for tab in parser not working quite right
        -Ex. I Hold On - Dierks Bentley. It is detecting the first line as a title and making it a tag
        - I think its also adding the chordpro-style metadata tags. Stop doing that
  - Make tools
  - Fix Metronome delay
  - iCloud for db storage



I want to make a tool for sending MIDI commands to any connected devices. This will be a modal formatted like our other ones, lets name it midi_sender_modal. It will be called "MIDI Sender" under the sidebar Tools menu. 

I want this code to be modular and maintainable - it should be structured similarly to the guitar tuner service I just created, with clear separation of concerns and reusable components.

The MIDI sender should have a box for entering the command, and a test button. Lets also make a checkbox for "streaming" which, if enabled, will send the specified command out at an interval of 120 beats per minute. 




