# Pull in list of Harvard Sentences
$List1 = (iwr "https://raw.githubusercontent.com/jimmynwade/powershtuff/master/harvardsentences.txt")

$a = ($List1.RawContent -join "")
$b = ($a -split "
")[15..$($a.Length)]

# Make sure to add ffmpeg bin directory to PATH variable
# $env:Path += “;C:\Users\wade.199\Desktop\ffmpeg-20140307-git-64e4bd7-win64-static\bin”

Add-Type -AssemblyName System.Drawing
add-type -AssemblyName System.Speech
Add-Type -AssemblyName System.Web

# Create a new Random Number Generator
[System.Random]$rand = New-Object System.Random

# Create a blank bitmap object
$bmp = New-Object -TypeName System.Drawing.Bitmap -ArgumentList @(1440, 960)

# Build a media list for FFmpeg to create a large video when we're done
“# build list” | out-file -Encoding default "big.txt"

# Go!
(0..71) | % {
$groupnum = $_ +1; 
    # Build a media list for FFmpeg to create a video for this group
    “# build list” | out-file -Encoding default "$groupnum.txt"

    # For the next ten phrases
    (0..9) | % {$linenum = $_+1; $b[(($groupnum-1)*10)+$_]} | % {

    # Instantiate Text-To-Speech Synthesizer
    $sndout = New-Object System.Speech.Synthesis.SpeechSynthesizer

    # Open a .wav file
    $sndout.SetOutputToWaveFile("$($pwd.Path)\$groupnum.$linenum.wav")

    # Write the sentence to a .wav file
    $sndout.Speak("$_")

    # Ditch the Synth
    $sndout.Dispose()
    
    # Instantiate Speech-To-Text Engine
    $receng = New-Object System.Speech.Recognition.SpeechRecognitionEngine
    $receng.LoadGrammar((New-Object System.Speech.Recognition.DictationGrammar))

    # Open the .wav file we just made
    $receng.SetInputToWaveFile("$($pwd.Path)\$groupnum.$linenum.wav")
    $receng.InitialSilenceTimeout = [timespan]::FromSeconds(5)
    [System.Speech.Recognition.RecognitionResult] $result = $receng.Recognize()
    # Ditch the engine
    $receng.Dispose()

    # Here's where it gets gross:
    # Google Image Search the spoken text, return the top result.
    try {
    $leftresults = ((Invoke-RestMethod ("http://ajax.googleapis.com/ajax/services/search/images?v=1.0&restrict=cc_attribute&safe=active&q="+[System.Web.HttpUtility]::URLEncode($_))).responseData.results)[0].unescapedUrl
    }
    catch {
    $leftresults = ((Invoke-RestMethod ("http://ajax.googleapis.com/ajax/services/search/images?v=1.0&restrict=cc_attribute&safe=active&q="+[System.Web.HttpUtility]::URLEncode($_))).responseData.results)[0].tbUrl
    }
    finally {
    $left = (iwr $leftresults).RawContentStream
    }

    # Google Image Search the heard text, return the top result.
    try {
    $rightresults = ((Invoke-RestMethod ("http://ajax.googleapis.com/ajax/services/search/images?v=1.0&restrict=cc_attribute&safe=active&q="+[System.Web.HttpUtility]::URLEncode($result.text))).responseData.results)[0].unescapedUrl
    }
    catch {
    $rightresults = ((Invoke-RestMethod ("http://ajax.googleapis.com/ajax/services/search/images?v=1.0&restrict=cc_attribute&safe=active&q="+[System.Web.HttpUtility]::URLEncode($result.text))).responseData.results)[0].tbUrl
    }
    finally {
    $right = (iwr $rightresults).RawContentStream
    }
        
    # Create graphics object from our blank bitmap
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)

    # Pick a color!
    $color = [System.Drawing.Color]::FromArgb($rand.Next(191,255),$rand.Next(191,255),$rand.Next(191,255))
    
    # Fill the graphics object with that color
    $gfx.Clear($color)

    # Draw Google Image Search images
    $gfx.DrawImage([System.Drawing.Image]::FromStream($left),0,280,720,480)
    $gfx.DrawImage([System.Drawing.Image]::FromStream($right),720,280,720,480)
    

    # Get the contrasting color
    $contrastingcolor = [System.Drawing.Color]::FromArgb(255-$color.R,255-$color.B,255-$color.G)

    # Pick a font
    $font = New-Object System.Drawing.Font -ArgumentList @("Segoe UI",32)

    # Set the text color
    $brush = New-Object System.Drawing.SolidBrush -ArgumentList @($contrastingcolor)

    # Set the text drawing area
    $drawRect = New-Object System.Drawing.RectangleF -ArgumentList @(40,40,1400,920)

    # Draw the spoken text, heard text, heard IPA and RGB of the background color.
    $gfx.DrawString("    $groupnum.$($linenum)`	spoken:	$_
	heard`:	$($result.text)`
		$( $result.Words.pronunciation -join " ")











		R`:$($color.R) G`:$($color.G) B`:$($color.B)", $font, $brush, $drawRect)

    #$bmp.Save("$($pwd.Path)\$groupnum.$linenum.jpg", [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $bmp.Save("$($pwd.Path)\$groupnum.$linenum.tif", [System.Drawing.Imaging.ImageFormat]::Tiff)

    #ffmpeg -i "$($pwd.Path)\$groupnum.$linenum.jpg" -i "$($pwd.Path)\$groupnum.$linenum.wav" "$($pwd.Path)\$groupnum.$linenum.mp4"
    ffmpeg -t $($result.Audio.Duration.Seconds + 1) -i "$($pwd.Path)\$groupnum.$linenum.tif" -i "$($pwd.Path)\$groupnum.$linenum.wav" -c:v libx264 -r 30 "$($pwd.Path)\$groupnum.$linenum.mp4"
    “file '$($pwd.Path)\$groupnum.$linenum.mp4′” | out-file -Encoding default -Append "$groupnum.txt"

    “$groupnum,$linenum,`"$_`",`"$($result.text)`",$($color.R),$($color.G),$($color.B)” | out-file -Encoding default -Append "$groupnum-meta.txt"

}
# concatenate videos
ffmpeg -f concat -i "$groupnum.txt" -c copy "HS$groupnum.mp4"
“file '$($pwd.Path)\HS$groupnum.mp4′” | out-file -Encoding default -Append "big.txt"
Remove-Item *.*.mp4
}

ffmpeg -f concat -i "big.txt" -c copy "HS.mp4"
