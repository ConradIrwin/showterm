[showterm.io](http://showterm.herokuapp.com/)
=============

It's showtime for your terminal!

Showterm lets your record a terminal session exactly as you experience it, right down to
the syntax highlighting.

Installation instructions (`gem install showterm`) and usage instructions (`showterm <program`) are available in the [showterm](https://showterm.herokuapp.com/b6803679cb1c9fbcf667cb7cfe8f605e3ce1fe03). :)

(yes, this is me using showterm inside showterm; it's like inception, but with more
syntax highlighting)

TODO
====

* Allow embedders to chose colourschemes (at least light vs. dark background).
* Fix problems with non-80 column terminals
* Fix problems with vim which sometimes goes out-of-bounds for term.js

Meta-fu
=======

As usual, bug-reports and pull requests are welcome; everything is MIT licensed (see
LICENSE.MIT).

Credit
======

This would not have been doable without the excellent terminal emulator I borrowed from Christopher Jeffrey's incredible [tty.js](https://github.com/chjj/tty.js).
