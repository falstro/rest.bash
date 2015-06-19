#!/bin/sed -f
# Simple sed script to generate the README.md from rest.bash.
/\# NAME/,/^$/{
  s/^\# \?//
  /^[A-Z]/{h;s/./=/g;x;G;}
  s/^ \{8\}//
  s/ $/    /
  s/ \{2\}/ /g
  b
}
d
