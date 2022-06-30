# Plain text with lines

An editor for plain text where you can also seamlessly insert line drawings.
Designed above all to be easy to modify and give you early warning if your
modifications break something.

http://akkartik.name/lines.html

## Invocation

Like all LÖVE apps, lines.love can be invoked either from a terminal or
by clicking on the application in a graphical desktop.

When invoked from a terminal, you can pass the love binary the path to either
the zipped lines.love or a directory containing lines.love unzipped.

```sh
$ path/to/love path/to/lines.love

$ path/to/love .  # from this repo directory
$ path/to/love path/to/lines/directory  # from anywhere
```

By default, lines.love reads/writes the file `lines.txt` in your default
user/home directory (`https://love2d.org/wiki/love.filesystem.getUserDirectory`).

When invoked from a terminal, you can pass in a different file to edit, either
to the zipped or unzipped versions:

```sh
$ path/to/love path/to/lines.love path/to/file/to/edit

$ path/to/love path/to/lines/directory /path/to/file/to/edit
```

On a graphical desktop you can also drag and drop a file icon on to the
lines.love window.

You can also configure the size of the window on the commandline. For example:

```sh
$ path/to/love path/to/lines.love -geometry 640x480+10+10 path/to/file/to/edit
```

The syntax of the geometry parameter is {width}x{height}+{x}+{y} which will
position the top-left corner of the window at co-ordinate (x,y). The geometry
parameter must come before the file to edit.

## Keyboard shortcuts

While editing text:
* `ctrl+f` to find patterns within a file
* `ctrl+c` to copy, `ctrl+x` to cut, `ctrl+v` to paste
* `ctrl+z` to undo, `ctrl+y` to redo
* `ctrl+=` to zoom in, `ctrl+-` to zoom out, `ctrl+0` to reset zoom
* `alt+right`/`alt+left` to jump to the next/previous word, respectively

For shortcuts while editing drawings, consult the online help. Either:
* hover on a drawing and hit `ctrl+h`, or
* click on a drawing to start a stroke and then press and hold `h` to see your
  options at any point during a stroke.

lines.love has been exclusively tested so far with a US keyboard layout. If
you use a different layout, please let me know if things worked, or if you
found anything amiss: http://akkartik.name/contact

## Known issues

* No support yet for Unicode graphemes spanning multiple codepoints.

* Undo/redo may be sluggish in large files. Large files may grow sluggish in
  other ways. lines.love works well in all circumstances with files under
  50KB.

* If you kill the process, say by force-quitting because things things get
  sluggish, you can lose data.

* The text cursor will always stay on the screen. This can have some strange
  implications:

    * A long series of drawings will get silently skipped when you hit
      page-down, until a line of text can be showed on screen.
    * If there's no line of text at the top of the file, you may not be able
      to scroll back up to the top with page-up.

  So far this app isn't really designed for drawing-heavy files. For now I'm
  targeting mostly-text files with a few drawings mixed in.

* No clipping yet for drawings. In particular, circles/squares/rectangles and
  point labels can overflow a drawing.

* Touchpads can drag the mouse pointer using a light touch or a heavy click.
  On Linux, drags using the light touch get interrupted when a key is pressed.
  You'll have to press down to drag.

* Can't scroll while selecting text with mouse.

* No scrollbars yet. That stuff is hard.

## Mirrors and Forks

Updates to lines.love can be downloaded from the following mirrors in addition
to the website above:
* https://github.com/akkartik/lines.love
* https://repo.or.cz/lines.love.git
* https://codeberg.org/akkartik/lines.love
* https://tildegit.org/akkartik/lines.love
* https://git.tilde.institute/akkartik/lines.love
* https://git.sr.ht/~akkartik/lines.love
* https://pagure.io/lines.love

Forks of lines.love are encouraged. If you show me your fork, I'll link to it
here.

* https://github.com/akkartik/lines-polygon-experiment -- an experiment that
  uses separate shortcuts for regular polygons. `ctrl+3` for triangles,
  `ctrl+4` for squares, etc.

## Feedback

[Most appreciated.](http://akkartik.name/contact)
