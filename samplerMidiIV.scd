

//VA code 060425 Sampler 
//Popup to select sounds
//waveform view
//Spectral view
//midi connection for M-Audio Keystation 49 MK3
(
s.waitForBoot({
    var rate = 1.0, cutoff = 1000, pitchShift = 1.0;
	  var synth, buffer, win, soundMenu, selectedSound, funcs, sndFileView, bus, f, p;
    var soundFiles, snd;

    // Create analysis Bus (2 channels)
    bus = Bus.audio(s, 2);  // Create a bus with 2 channels (stereo)

    // Create the SynthDef for the sampler
    SynthDef(\sampler, {
        arg buf, rate = 1, cutoff = 1000, amp = 0.5, out=0, tapOut=0, gate = 1;
        var env, sig;

		//envelope
		//env = EnvGen.kr(Env.adsr(0.01, 0.5, 0.4, 1.0), gate, doneAction:2);
		//env = EnvGen.kr(Env.perc(0.01, 1.0), doneAction:2);

        // Play the buffer (sample) with rate control
        sig = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * rate, doneAction:2);
        // Apply low-pass filter
        sig = LPF.ar(sig, cutoff);
        // Apply amplitude control
        sig = sig * amp;
        // Output to the main audio output (speakers)
        Out.ar(out, sig ! 2);
        // Output to the analysis bus (for scopes)
        Out.ar(bus.index, sig ! 2);  // Route to the analysis bus (2 channels)
    }).add;


    // List of sound files for selection (add your actual sound files here)
 soundFiles = [
        "a11wlk01.wav",
        "sound2.wav",  // Add your own sample names here
        "sound3.wav"
    ];
    // Functions to load different sounds
    funcs = [
        { Buffer.read(s, Platform.resourceDir ++ "/sounds/" ++ soundFiles[0]) },
        { Buffer.read(s, Platform.resourceDir ++ "/sounds/" ++ soundFiles[1]) },
        { Buffer.read(s, Platform.resourceDir ++ "/sounds/" ++ soundFiles[2]) }
    ];

    // Set the default sound file to the first one
    selectedSound = soundFiles[0];
    buffer = funcs[0].value;  // Load default sound

    // Create the GUI window
    win = Window("Sampler with Sound File View", Rect(100, 100, 400, 400)).front;

    // Create the sound selection pop-up menu
    soundMenu = PopUpMenu(win, Rect(10, 10, 380, 20));
    soundMenu.items = soundFiles;  // Add sound options to the menu

    // Set the default menu selection (index 0)
    soundMenu.value = 0;  // Default selection to the first sound

    // Define the action to take when a menu item is selected
    soundMenu.action = { |menu|
        selectedSound = soundFiles[menu.value];  // Update selected sound when user selects an option
        buffer = funcs[menu.value].value;  // Load the selected sound
        ("Selected sound: " ++ selectedSound).postln; // Optionally print selected sound name to the post window

        // Update the SoundFileView with the new sound
        f.close;  // Close the previous sound file
        p = Platform.resourceDir ++ "/sounds/" ++ selectedSound;
        f.openRead(p);  // Open the new sound file

        sndFileView.soundfile = f;  // Set the new soundfile to the SoundFileView
        sndFileView.read(0, f.numFrames);  // Load the new sound into the view
        sndFileView.refresh;  // Refresh the view to display the new waveform
    };

    // Create a new SoundFileView
    sndFileView = SoundFileView.new(win, Rect(10, 70, 380, 100)); // Create a new view for the waveform display

    // Create a new SoundFile object
    f = SoundFile.new;

    // Set the path of the selected sound
    p = Platform.resourceDir ++ "/sounds/" ++ selectedSound;

    // Open the selected sound file for reading
    f.openRead(p);

    // Set the sound file for the SoundFileView
    sndFileView.soundfile = f;

    // Read the audio data (this loads the waveform into the view)
    sndFileView.read(0, f.numFrames);

    // Create the StaticText to display selected sound file path
    StaticText(win, Rect(10, 40, 380, 20))
        .string_("Selected Sound: " ++ selectedSound)
        .align_(\left);  // Align text to the left

	 win.layout = VLayout(
        soundMenu,  // Add the sound selection menu
        StaticText().string_("Play MIDI Notes for pitch\nCC1 controls filter").align_(\center),
        Button().states_([["Play Sample"]]).action_({
            // Trigger the Synth when the button is pressed
            Synth(\sampler, [
                \buf, buffer,
                \rate, 1.0,
                \cutoff, 1000
            ]);
        }),
        sndFileView // Add the SoundFileView for waveform display
    );

//Spectograpm
~fre = FreqScopeView(win, Rect(20,20,360,50));
~fre.active_(true);
~alpha = Spectrogram.new(win, Rect(20,70,360,50), background:Color(0.05, 0.05, 0.05), color:Color.green, lowfreq:20, highfreq:7000);
~alpha.start;

		 // Refresh the views on the AppClock for smooth update

	 Routine({
        inf.do {
            sndFileView.refresh;  // Refresh the waveform view as well
            0.05.wait;  // Refresh every 50ms
        }
    }).play(AppClock);

    // MIDI Setup
    MIDIClient.init;
    MIDIIn.connectAll;

    // MIDI Note control for pitch (NoteOn)
    MIDIdef.noteOn(\playSample, { |vel, num, chan, src|
        pitchShift = num.midicps / 440;  // Convert MIDI note to pitch
        synth = Synth(\sampler, [\buf, buffer, \rate, pitchShift, \cutoff, cutoff, \tapOut, bus.index]);
    });

	 // MIDI Note control for pitch (NoteOff)
    MIDIdef.noteOff(\playSampleOff, { |vel, num, chan, src|
        // Stop the synth when note is released (NoteOff)
        synth.free;
        ("Note off: " ++ num).postln;  // Print the note number to confirm
    });
    // MIDI CC control for filter cutoff (CC1)
    MIDIdef.cc(\filterCutoff, { |val, num, chan, src|
        cutoff = val.linexp(0, 127, 200, 10000);  // Map CC to cutoff
        ("Cutoff: " ++ cutoff).postln;
        // Update cutoff in real-time by sending control value to the Synth
        synth.set(\cutoff, cutoff);  // Send real-time cutoff value to the running synth
    }, 1);

 // MIDI CC control for volume (CC7)
    MIDIdef.cc(\volume, { |val, num, chan, src|
        vol = val.linlin(0, 127, 0.001, 1.0);  // Map CC to volume
        ("Volume: " ++ vol).postln;
        // Update volume in real-time by sending control value to the Synth
        synth.set(\amp, vol);  // Send real-time volume value to the running synth
    }, 7);
});
)
