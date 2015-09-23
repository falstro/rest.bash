NAME
====
rest.bash - a REST client inside the GNU Bourne-Again SHell

SYNOPSIS
========
rest.bash [options] [script]

DESCRIPTION
===========
rest.bash is a curl based REST client leveraging the GNU
Bourne-Again SHell for command input. This means you can use any and
all features Bash provides when interacting with your REST based
services, including functions, loops, and pipes as well as using
arbitrary commands and programs for input and output processing.

rest.bash does use a few features which are non-POSIX Bash
extensions (such as associative arrays), thus it might not be
trivial to port to other shells.

OPTIONS
=======
rest.bash does not currently intercept any options, they are all
passed along to Bash as is.

INVOCATION
==========
An interactive shell is started when no script-file parameter is
given. rest.bash will suppress the reading of the .bashrc file and
instead the ~/.rest.bashrc will be sourced if present. After that,
all files in ~/.rest.bashrc.d/ will be sourced, and is a useful
place to store custom scripts for common services. When executing
interactively, the PS1 prompt will show the current URL
(http://localhost/ by default) as well as the HTTP code from the
last call (if any).

Like normal Bash, a non-interactive shell executing a script will
not parse .rest.bashrc and .rest.bashrc.d scripts, if they are
needed, they must be sourced explicitly.

REST.BASH COMMANDS
==================
* header <header-name> [header-value]  
* authorization [header-value]  
* accept [header-value]  
* content-type [header-value]  
* cookie [header-value]  
    Set the HTTP header to the specified value. Omitting the
    value removes the header.

* basic-auth [user] [pass]  
    Set the Authentication header to use basic authentication.
    If user and/or password are omitted a prompt will be
    displayed, if no user is entered the authentication header
    is removed. Digest authentication is currently not
    supported.

* cq <url>  
    Change current URL. Accepts a few different formats:
    * protocol://[host[/path]]  
        Change protocol, host and path. If host or path
        is omitted they will remain the same as before.
    * //host[/path]  
        Change host and path, using the same protocol as
        before. If path is omitted, it will remain the
        same as before.
    * /absolute-path  
        Change path using an absolute path.
    * relative-path  
        Change path using a relative path. '.' and '..' are
        interpreted as the current path and one level up in
        the current path respectively. Both can be used as
        part of a path as well.
    * -  
        Switch to the last path used, similar to how 'cd -'
        switches to the previous directory. Useful for
        alternating back and forth between two paths.
* files  
    List the temporary files managed by rest.bash. Note that
    these are also available through environment variables
    which can be used directly when launching an editor. Some
    editors (e.g. VIm) imports environment variables as well,
    meaning they can even be used inside the editor once it's
    running.

* get [url]  
* post [url]  
* put [url]  
* delete [url]  
    Execute get, post, put, and delete requests using the
    current URL. If the optional URL element is specified it is
    interpreted relative to the current URL as 'cq' would have.

    If stdin is a TTY, the $PAYLOAD file will be read when using
    'post' and 'put'. If stdin is NOT a TTY, stdin will be used
    instead. Be wary of this if executing automated scripts
    using something which isn't connected to a TTY (e.g. cron) and
    redirect the stdin to $PAYLOAD on each call explicitly
    in case you want to use $PAYLOAD for input. Note that
    in a script there's no real good reason for actually
    using $PAYLOAD as you can simply pipe your payload
    directly.

    In the context of a boolean expression, a failed curl (e.g.
    host unreachable) or any HTTP response code of 400 or greater
    is considered false.

    'get' and 'delete' will not read $PAYLOAD.

* load [file]  
    Short hand command for loading a file into $PAYLOAD. If no
    file is given, stdin is read and can be useful for loading
    prepared payloads or templates.

* mode <mode>  
    Select I/O mode. Effectively configures headers and output
    formatting hooks for a specific file format. To define more
    modes, see CUSTOM MODES. By default the following modes are
    supported:
    * plain  
        Plain mode uses no output formatting and uses simply
        'grep' for selections using 'sel'.
    * json  
        JSON mode uses Python's json module for pretty
        printing and the tool 'joqe' for selections using
        'sel' if available.
    * xml  
        XML mode uses 'xmllint' for pretty printing and
        XPath selections using 'sel' if available.

* sel <query>  
    Select data from the previous output. This uses the $OUTPUT
    file and can be executed several times without sending new
    requests to the service. The query syntax is defined by The
    I/O mode, e.g. use XPath for XML.
    NOTE: 'sel' is an alias, and can't reliably be used in
       functions as aliases are resolved during function
       declaration.

* ssl-insecure [on]  
    Specify 'ssl-insecure on' or 'ssl-insecure yes' to tell curl
    to ignore SSL certificate errors. Useful when running tests
    using self signed certificates or similar. Specifying
    anything else (such as 'off' or 'no') will enable
    certificate validation (this is also the default).

CUSTOM MODES
============
To define custom modes you need to define a function using the name
of the mode you want to define prefixed with two a plus ('+'). You
should take care to define the headers you need, an appropriate
$output_filter, as well as alias 'sel' to the appropriate selection
function.

To clean up configuration done in the '+' function, define a '-'
function as well, which will be called when leaving the mode. The
'-' function will also be called on exit if the mode is still
active, in case you need to clean up any side effects such as
temporary files.

For example, the following could define an XML mode (the built-in
XML mode is slightly more elaborate):

    +xml() {
        accept text/xml
        content-type text/xml
        output_filter='=xml-filter'
        alias sel='=xml-select'
    }
    -xml() {
        =unset-mode
    }
    =xml-filter() {
        xmllint --format "$1"
    }
    =xml-select() {
        xmllint --xpath "$*" $OUTPUT
    }

To enable, use 'mode xml'. '=unset-mode' is a helper function
provided by rest.bash to unset common mode overrides, such as the
accept header, content-type header, output_filter and sel alias.

SEE ALSO
========
* bash(1)

VARIABLES
=========
These variables are not exported and are invisible to sub processes,
and are used to modify rest.bash's behavior.

* $output_filter  
    Executed with a temporary output file as parameter, should
    contain the name of a output filter function, such as a
    pretty printer.

* $_on_output  
    Hook which is evaluated once new data is available. The
    evaluated value is ignored.

* $_stdout  
    Hook for controlling stdout from network calls. Evaluate to
    false to suppress output. Note that if stdout is suppressed
    the network calls can't be used in pipes. A common value is
    to use 'test ! -t 1' to suppress output only if stdout is a
    TTY, i.e. the terminal.

ENVIRONMENT VARIABLES
=====================
These variables are exported through the environment, and are
visible to subprocess such as your editor.

* $OUTPUT  
    Temporary file containing the output produced by the last
    call. The file will be removed on exit.

* $PAYLOAD  
    Temporary file containing the payload to send. Having the
    payload in a separate file allows you to keep it open in an
    editor, without having to worry about the life cycle of that
    file. The file will be removed on exit.

* $HTTPHEADER  
    Temporary file containing the HTTP headers produced by the
    last call. The file will be removed on exit.

FILES
=====
* ~/.rest.bashrc  
    Personal initialization script

* ~/.rest.bashrc.d/  
    The directory containing personal custom scripts. All files
    (except .*) in this directory will be sourced on launch. See
    the cookbook directory in the source tree for examples.

BUGS
====
Probably several. One source of confusion is the practice of testing
whether stdin is bound to a terminal or not in order to detect whether
input was redirected. This works find when running manually, but if
ever run as a cron script, it'll cause weird behavior.

Currently the first HTTP status code received is evaluated, which in
case of a POST or PUT is often 100 (Continue) which is less than 400
and thus considered successful.

AUTHOR
======
Written by Fredrik Alstromer <falstro@excu.se>

COPYRIGHT
=========
rest.bash is Copyright (c) 2015 Fredrik Alstromer.

Distributed under the MIT license.

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Bash is Copyright (C) by the Free Software Foundation, Inc. and is
neither part of this package, nor is it covered by above license.

