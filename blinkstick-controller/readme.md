
# Blinkstick-Controller

this is a small rust binary which reads hardware and files under `/tmp/blink*` to set the blinkstick lights
on the server `azure-sidekick`.

Writing the program in Rust and having it be a daemon means I can poll hardware much more
frequently without chewing through a lot of CPU time.

We have 7 LEDs; they are programmed to do the following:

1. Blinks a dim green when a remote user is logged in; the more users log in, the faster the blink.
2. Dim blue when a GPU is connected
3. renders the color in the file `/tmp/blink3` or blank if file does not exist or if the file's mtime becomes > 5 minutes old
4. renders the color in the file `/tmp/blink4` or blank if file does not exist or if the file's mtime becomes > 5 minutes old
5. renders the color in the file `/tmp/blink5` or blank if file does not exist or if the file's mtime becomes > 5 minutes old
6. renders the color in the file `/tmp/blink6` or blank if file does not exist or if the file's mtime becomes > 5 minutes old
7. renders the color in the file `/tmp/blink7` or blank if file does not exist or if the file's mtime becomes > 5 minutes old

`/tmp/blinkN` may be used by other scripts and programs to indicate activity. No blinking is planned to be supported.


