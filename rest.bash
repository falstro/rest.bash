#!/bin/bash
# vim:sw=2 sts=2 et:
if [ -z "$PS1" ]; then
  if [ -z "$1" ]; then
    exec /bin/bash --init-file "$0"
  else
    _SCRIPT="$1"
    shift
  fi
fi

# NAME
#         rest.bash - a REST client inside the GNU Bourne-Again SHell
#
# SYNOPSIS
#         rest.bash [options] [script]
#
# DESCRIPTION
#         rest.bash is a curl based REST client leveraging the GNU
#         Bourne-Again SHell for command input. This means you can use any and
#         all features Bash provides when interacting with your REST based
#         services, including functions, loops, and pipes as well as using
#         arbitrary commands and programs for input and output processing.
#
#         rest.bash does use a few features which are non-POSIX Bash
#         extensions (such as associative arrays), thus it might not be
#         trivial to port to other shells.
#
# OPTIONS
#         rest.bash does not currently intercept any options, they are all
#         passed along to Bash as is.
#
# INVOCATION
#         An interactive shell is started when no script-file parameter is
#         given. rest.bash will suppress the reading of the .bashrc file and
#         instead the ~/.rest.bashrc will be sourced if present. After that,
#         all files in ~/.rest.bashrc.d/ will be sourced, and is a useful
#         place to store custom scripts for common services. When executing
#         interactively, the PS1 prompt will show the current URL
#         (http://localhost/ by default) as well as the HTTP code from the
#         last call (if any).
#
#         Like normal Bash, a non-interactive shell executing a script will
#         not parse .rest.bashrc and .rest.bashrc.d scripts, if they are
#         needed, they must be sourced explicitly.
#
# REST.BASH COMMANDS
#         * header <header-name> [header-value] 
#         * authorization [header-value] 
#         * accept [header-value] 
#         * content-type [header-value] 
#         * cookie [header-value] 
#                 Set the HTTP header to the specified value. Omitting the
#                 value prints the currently set value, if any.
#
#         * header -d <header-name>
#                 Remove the header if set.
#
#         * basic-auth [user] [pass] 
#                 Set the Authentication header to use basic authentication.
#                 If user and/or password are omitted a prompt will be
#                 displayed, if no user is entered the authentication header
#                 is removed. Digest authentication is currently not
#                 supported.
#
#         * cq <url> 
#                 Change current URL. Accepts a few different formats:
#                 * protocol://[host[/path]] 
#                         Change protocol, host and path. If host or path
#                         is omitted they will remain the same as before.
#                 * //host[/path] 
#                         Change host and path, using the same protocol as
#                         before. If path is omitted, it will remain the
#                         same as before.
#                 * /absolute-path 
#                         Change path using an absolute path.
#                 * relative-path 
#                         Change path using a relative path. '.' and '..' are
#                         interpreted as the current path and one level up in
#                         the current path respectively. Both can be used as
#                         part of a path as well.
#                 * - 
#                         Switch to the last path used, similar to how 'cd -'
#                         switches to the previous directory. Useful for
#                         alternating back and forth between two paths.
#         * files 
#                 List the temporary files managed by rest.bash. Note that
#                 these are also available through environment variables
#                 which can be used directly when launching an editor. Some
#                 editors (e.g. VIm) imports environment variables as well,
#                 meaning they can even be used inside the editor once it's
#                 running.
#
#         * get [-dn] [url] 
#         * post [-dn] [url] 
#         * put [-dn] [url] 
#         * options [-dn] [url]
#         * delete [-dn] [url] 
#                 Execute get, post, put, and delete requests using the
#                 current URL. If the optional URL element is specified it is
#                 interpreted relative to the current URL as 'cq' would have.
#
#                 If stdin is a TTY, the $PAYLOAD file will be read when using
#                 'post' and 'put'. If stdin is NOT a TTY, stdin will be used
#                 instead. Be wary of this if executing automated scripts
#                 using something which isn't connected to a TTY (e.g. cron) and
#                 redirect the stdin to $PAYLOAD on each call explicitly
#                 in case you want to use $PAYLOAD for input. Note that
#                 in a script there's no real good reason for actually
#                 using $PAYLOAD as you can simply pipe your payload
#                 directly.
#
#                 In the context of a boolean expression, a failed curl (e.g.
#                 host unreachable) or any HTTP response code of 400 or greater
#                 is considered false.
#
#                 * -d 
#                       Read payload data from $PAYLOAD
#                 * -n 
#                       Do not read any payload.
#
#                 'get', 'options', and 'delete' will not read $PAYLOAD unless
#                 '-d' is set, whereas 'post' and put *will* read $PAYLOAD
#                 unless '-n' is set. If both '-d' and '-n' are specified
#                 and/or multiple times, the last occurence will take
#                 precedence.
#
#         * load [file] 
#                 Short hand command for loading a file into $PAYLOAD. If no
#                 file is given, stdin is read and can be useful for loading
#                 prepared payloads or templates.
#
#         * mode <mode> 
#                 Select I/O mode. Effectively configures headers and output
#                 formatting hooks for a specific file format. To define more
#                 modes, see CUSTOM MODES. By default the following modes are
#                 supported:
#                 * plain 
#                         Plain mode uses no output formatting and uses simply
#                         'grep' for selections using 'sel'.
#                 * json 
#                         JSON mode uses 'joqe' if available for pretty
#                         printing, input filtering, and selections using 'sel',
#                         if available. If not, Python's json module is used for
#                         pretty printing.
#                 * xml 
#                         XML mode uses 'xmllint' for pretty printing and
#                         XPath selections using 'sel' if available.
#
#         * sel <query> 
#                 Select data from the previous output. This uses the $OUTPUT
#                 file and can be executed several times without sending new
#                 requests to the service. The query syntax is defined by the
#                 I/O mode, e.g. use XPath for XML.
#                 NOTE: 'sel' is an alias, and can't reliably be used in
#                       functions as aliases are resolved during function
#                       declaration.
#
#         * suffix [suffix] 
#                 Add an implicit suffix to all URLs. Some APIs use a
#                 'file extension' to specify content type, like
#                 '.json', (rather than the Accept header), in which
#                 case this comes in handy. The suffix is inserted
#                 before the '?' if present, otherwise it's appended.
#
#         * ssl-insecure [on] 
#                 Specify 'ssl-insecure on' or 'ssl-insecure yes' to tell curl
#                 to ignore SSL certificate errors. Useful when running tests
#                 using self signed certificates or similar. Specifying
#                 anything else (such as 'off' or 'no') will enable
#                 certificate validation (this is also the default).
#
#         * cookie-jar [on/file-name/off] 
#                 Enable or disable the use of a cookie jar. Specifying a
#                 file-name will enable cookie-jar with that file, specifying
#                 "on" will use a temporary file. If not parameter is given,
#                 the current state is returned.
#
#         * user-agent [-d] [user-agent] 
#                 Set the user-agent string, or use -d to revert to default. If
#                 no parameter is given, the current state is returned.
#
#         * reload-cookbook 
#                 Reload the custom scripts from rest.bashrc and rest.bashrc.d,
#                 useful if you're editing these as you go.
#
# RESPONSE HISTORY
#
#         * back [n] 
#                 Go back to a previous response. $OUTPUT will be replaced.
#
#         * forward [n] 
#                 Go forward again to a later response. $OUTPUT will be
#                 replaced.
#
# CUSTOM MODES
#         To define custom modes you need to define a function using the name
#         of the mode you want to define prefixed with two a plus ('+'). You
#         should take care to define the headers you need, an appropriate
#         $output_filter, as well as alias 'sel' to the appropriate selection
#         function.
#
#         To clean up configuration done in the '+' function, define a '-'
#         function as well, which will be called when leaving the mode. The
#         '-' function will also be called on exit if the mode is still
#         active, in case you need to clean up any side effects such as
#         temporary files.
#
#         For example, the following could define an XML mode (the built-in
#         XML mode is slightly more elaborate):
#
#                 +xml() {
#                         accept text/xml
#                         content-type text/xml
#                         output_filter='=xml-filter'
#                         alias sel='=xml-select'
#                 }
#                 -xml() {
#                         echo "clean-up any temporary files, etc"
#                 }
#                 =xml-filter() {
#                         xmllint --format "$1"
#                 }
#                 =xml-select() {
#                         xmllint --xpath "$*" $OUTPUT
#                 }
#
#         To enable, use 'mode xml'. '=unset-mode' is a helper function
#         provided to unset common mode overrides, such as the accept header,
#         content-type header, output_filter and sel alias. It will always be
#         called when leaving any mode.
#
# SEE ALSO
#         * bash(1)
#
# VARIABLES
#         These variables are not exported and are invisible to sub processes,
#         and are used to modify rest.bash's behavior.
#
#         * $output_filter 
#                 Executed with a temporary output file as parameter, should
#                 contain the name of a output filter function, such as a
#                 pretty printer.
#
#         * $input_filter 
#                 Executed with a the input file and the previous output file as
#                 parameter, should contain the name of a input filter
#                 function, such as a normalizer or a tool that maps data from
#                 the previous output into the input.
#
#         * $_on_output 
#                 Hook which is evaluated once new data is available. The
#                 evaluated value is ignored.
#
#         * $_stdout 
#                 Hook for controlling stdout from network calls. Evaluate to
#                 false to suppress output. Note that if stdout is suppressed
#                 the network calls can't be used in pipes. A common value is
#                 to use 'test ! -t 1' to suppress output only if stdout is a
#                 TTY, i.e.  the terminal.
#
# ENVIRONMENT VARIABLES
#         These variables are exported through the environment, and are
#         visible to subprocess such as your editor.
#
#         * $OUTPUT 
#                 Temporary file containing the output produced by the last
#                 call. The file will be removed on exit.
#
#         * $PAYLOAD 
#                 Temporary file containing the payload to send. Having the
#                 payload in a separate file allows you to keep it open in an
#                 editor, without having to worry about the life cycle of that
#                 file. The file will be removed on exit.
#
#         * $HTTPHEADER 
#                 Temporary file containing the HTTP headers produced by the
#                 last call. The file will be removed on exit.
#
# FILES
#         * ~/.rest.bashrc 
#                 Personal initialization script
#
#         * ~/.rest.bashrc.d/ 
#                 The directory containing personal custom scripts. All files
#                 (except .*) in this directory will be sourced on launch. See
#                 the cookbook directory in the source tree for examples. Use
#                 the reload-cookbook command to reload these. Useful if you're
#                 editing as you go.
#
# BUGS
#         Probably several. One source of confusion is the practice of testing
#         whether stdin is bound to a terminal or not in order to detect whether
#         input was redirected. This works find when running manually, but if
#         ever run as a cron script, it'll cause weird behavior.
#
#         Currently the first HTTP status code received is evaluated, which in
#         case of a POST or PUT is often 100 (Continue) which is less than 400
#         and thus considered successful.
#
# AUTHOR
#         Written by Fredrik Alstromer <falstro@excu.se>
#
# COPYRIGHT
#         rest.bash is Copyright (c) 2015-2017 Fredrik Alstromer.
#
#         Distributed under the MIT license.
#
#         Permission is hereby granted, free of charge, to any person
#         obtaining a copy of this software and associated documentation files
#         (the "Software"), to deal in the Software without restriction,
#         including without limitation the rights to use, copy, modify, merge,
#         publish, distribute, sublicense, and/or sell copies of the Software,
#         and to permit persons to whom the Software is furnished to do so,
#         subject to the following conditions:
#
#         The above copyright notice and this permission notice shall be
#         included in all copies or substantial portions of the Software.
#
#         THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#         EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#         MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#         NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
#         BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
#         ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#         CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#         SOFTWARE.
#
#         Bash is Copyright (C) by the Free Software Foundation, Inc. and is
#         neither part of this package, nor is it covered by above license.

default-settings() {
  mode          json
  ssl-insecure  no
  cookie-jar    on
}

#NB: IFS is '|' when calling $CURL.
CURL=/usr/bin/curl
CUT=/usr/bin/cut
GREP=/bin/grep
MKTEMP=/bin/mktemp
RM=/bin/rm
SED=/bin/sed
TEE=/usr/bin/tee
TAIL=/usr/bin/tail
HEAD=/usr/bin/head
GZIP=/bin/gzip
TRUNCATE=/usr/bin/truncate

VERSION=0.9

HISTFILE=~/.rest.bash_history

if [ -n "$PS1" ]; then
  tPS1='$(resultcode) $(=history-ps1) [$(url)]'
  PS1="$tPS1"'\$ '
  color_prompt=false
  case "$TERM" in
    *color*)
      color_prompt=true
      ;;
  esac
  if $color_prompt; then
    PS1='\[$(resultcode-color)\]$(resultcode)\[\e[00m\]$(=history-ps1) [$(url)] '
  fi
  case "$TERM" in
    xterm*|rxvt*)
      PS1='\[\e]0;'"$tPS1"'\a\]'"$PS1"
      ;;
  esac
fi

# hook for reacting on new output
_on_output=true

# hook for controlling input/output
input_filter=
output_filter=

# hook for controlling stdout; evaluate to false to suppress.
_stdout=true

URL_PROTO="http"
URL_HOST="localhost"
URL_PATH=""
URL_SUFFIX=""
url() { echo "$URL_PROTO://$URL_HOST${URL_PATH:-/}"; }
URL_PREV="$(url)"

CLEANUP=""
temp-file() {
  for v in "$@"; do
    eval "$v"='$($MKTEMP -t rest-"$v".XXXXXX)'
    CLEANUP="$CLEANUP ${!v}"
  done
}
trap '$RM $CLEANUP; mode none' EXIT

temp-file PAYLOAD TMPAYLOAD TMINPUT OUTPUT TMOUTPUT COOKIEJAR HTTPHEADER
temp-file HISTORY

export OUTPUT PAYLOAD HTTPHEADER

files() {
  echo Payload: $PAYLOAD
  echo Output: $OUTPUT
  echo HTTP Status: $HTTPHEADER
}
resultcode() {
  local line=`$SED -ne 's/[\r\n]*$//' -e1p -eq $HTTPHEADER`
  case $line in
    HTTP/2.0\ *|HTTP/2\ *) cut -f2 -d ' '<<<$line; ;;
    HTTP/1.*|HTTP/0.9\ *) cut -f2 -d ' '<<<$line; ;;
    *) echo ---; ;;
  esac
}
resultcode-color() {
  v=$(resultcode)
  case $v in
    4*|5*) echo -e '\e[31m'; ;;
    2??) echo -e '\e[32m'; ;;
    *) echo -e '\e[33m'; ;;
  esac
}

=truth() {
  case "$1" in
    [Tt]rue|TRUE|[Oo][Nn]|[Yy]es|YES)
      return 0
      ;;
    [Ff]alse|FALSE|[Oo]ff|OFF|[Nn][Oo])
      return 1
      ;;
  esac
  return 2
}

declare -A CURL_OPTS

=curl-opts() {
  echo -n "-s|-A|rest.bash/$VERSION|-D|$HTTPHEADER"
  for key in "${!CURL_OPTS[@]}"; do
    echo -n "${CURL_OPTS[$key]}"
  done
}

# HTTP request header functions, call without value to clear.

header() {
  local OPTIND opt d=false H=false header
  while getopts "dH:" opt; do
    case "$opt" in
      d) d=true; ;;
      H) H=true; header="$OPTARG"; ;;
      ?) return; ;;
    esac
  done
  shift $((OPTIND-1))
  if ! $H && [ -n "${1+x}" ]; then
    H=true
    header="$1"
    shift
  fi
  if $H; then
    local key="head:$header"
    if [ -n "${1+x}" ]; then
      if $d; then
        echo "Can't set and delete at the same time." >&2
      else
        unset CURL_OPTS[$key]
        CURL_OPTS[$key]="|-H|$header: $*"
      fi
    elif $d; then
      unset CURL_OPTS[$key]
    else
      echo "$header: ${CURL_OPTS[$key]#*: }"
    fi
  else
    for key in "${!CURL_OPTS[@]}"; do
      if [ "${key%%:*}" = "head" ]; then
        sed -e 's/.*|//' <<<"${CURL_OPTS[$key]}"
      fi
    done
  fi
}

accept() {
  header -H Accept "$@"
}

authorization() {
  header -H Authorization "$@"
}

content-type() {
  header -H Content-Type "$@"
}

cookie() {
  header -H Cookie "$@"
}

basic-auth() {
  local user="$1"
  local pass="$2"
  [ -z "$user" ] && read -r -p "Username: " user
  if [ -n "$user" ]; then
    if [ -z "$pass" ]; then
      read -rs -p "Password: " pass
      echo
    fi
    # don't use --user param to curl, password may contain '|'.
    authorization Basic $(echo -n $user:$pass|base64 -w0)
  fi
}

## Set ssl-insecure on to allow self-signed and incorrect certificates.
ssl-insecure() {
  if [ -z "$1" ]; then
    local state
    [ "${CURL_OPTS[SSL_INSECURE]:+x}" == x ] && state=on || state=off
    echo ssl-insecure: "$state"
  elif =truth "$1"; then
    CURL_OPTS[SSL_INSECURE]='|-k'
  elif [ $? -eq 1 ]; then
    unset CURL_OPTS[SSL_INSECURE]
  else
    echo "Usage: ssl-insecure [on|off]"
  fi
}

cookie-jar() {
  local dfault="|-b|$COOKIEJAR|-c|$COOKIEJAR"
  if [ -z "$1" ]; then
    local val="${CURL_OPTS[COOKIEJAR]#*|-c|}"
    if [ -z "${CURL_OPTS[COOKIEJAR]}" ]; then
      echo cookie-jar: off
    elif [ "$val" == "$COOKIEJAR" ]; then
      echo cookie-jar: on
    else
      echo cookie-jar: "$val"
    fi
  elif =truth "$1"; then
    CURL_OPTS[COOKIEJAR]="|-b|$COOKIEJAR|-c|$COOKIEJAR"
  elif [ $? -eq 1 ]; then
    unset CURL_OPTS[COOKIEJAR]
  else
    CURL_OPTS[COOKIEJAR]="|-b|$1|-c|$1"
  fi
}

user-agent() {
  local OPTIND opt d=false
  while getopts d opt; do
    case "$opt" in
      d) d=true; ;;
      ?) return; ;;
    esac
  done
  shift $((OPTIND-1))
  if $d; then
    unset CURL_OPTS[USER_AGENT]
  elif [ -n "$1" ]; then
    CURL_OPTS[USER_AGENT]="|-A|$1"
  elif [ -n "${CURL_OPTS[USER_AGENT]}" ]; then
    echo user-agent: "${CURL_OPTS[USER_AGENT]#|-A|}"
  else
    echo user-agent: "default"
  fi
}

# I/O mode switching functions

MODE=none

mode() {
  if [ "`type -t -- "+$1"`" == function ]; then
    if [ "`type -t -- "-$MODE"`" == function ]; then
      "-$MODE"
    fi
    =unset-mode
    "+$1" && MODE="$1"
  else
    echo "mode: '$1' unknown" >&2
  fi
}

## none mode
+none() {
  true
}

## helper function for unsetting common mode overrides
=unset-mode() {
  accept '*/*'
  content-type -d
  output_filter=
  input_filter=
  alias sel=false
}

## plain mode

=plain-filter() {
  # only make sure there's a new-line at the end of the output.
  $SED -e '$s/[\r\n]*$/\n/' "$1"
}

=plain-select() {
  $GREP "$*" $OUTPUT
}

+plain() {
  content-type text/plain
  accept text/plain,*/*

  output_filter='=plain-filter'
  alias sel='=plain-select'
}

-plain() {
  true
}

## JSON mode

JSONPP="/usr/bin/python -m json.tool"
JOQE="`which joqe`"

=json-filter() {
  $JSONPP "$1" || =plain-filter "$1"
}

=joqe-filter() {
  $JOQE -FFqr . "$1" || =plain-filter "$1"
}
=joqe-input() {
  if [ -z "$2" -o "$(stat -c %s $2)" == 0 ]; then
    $JOQE -q . "$1"
  else
    $JOQE -qf "$1" "$2" || $JOQE -q . "$1"
  fi
}
=joqe-select() {
  $JOQE -FFr "$*" "$OUTPUT"
}

+json() {
  accept 'application/json,*/*;q=0.9'
  content-type application/json


  if [ -x "$JOQE" ]; then
    alias sel='=joqe-select'
    output_filter='=joqe-filter'
    input_filter='=joqe-input'
  else
    alias sel='=plain-select'
    echo "joqe unavailable." >&2
    if $JSONPP >/dev/null 2>&1 <<<"{}"
    then
      output_filter='=json-filter'
    else
      output_filter='=plain-filter'
      echo "python json.tool unavailable, pretty printing disabled." >&2
    fi
  fi
}

-json() {
  true
}

## XML mode

XMLLINT="/usr/bin/xmllint"
XMLPP="$XMLLINT --format"

=xml-filter() {
  $XMLPP "$1" || =plain-filter "$1"
}

=xml-select() {
  $XMLLINT --xpath "$*" $OUTPUT && echo
}

+xml() {
  accept text/xml
  content-type text/xml

  if [ ! -x "$XMLLINT" ]; then
    echo "xmllint unavailable, no pretty printing or xpath support." >&2
  else
    output_filter='=xml-filter'
    alias sel='=xml-select'
  fi
}
-xml() {
  true
}

cq() {
  local url="$1"
  local n="$URL_PATH"
  local nproto="$URL_PROTO"
  local nhost="$URL_HOST"

  [ "$url" == '-' ] && url="$URL_PREV"

  if [[ $url == *://* ]]; then
    nproto="${url%%://*}"
    url="${url#$nproto://}"
    nhost="${url%%/*}"
    url="${url#$nhost}"
  elif [[ $url == //* ]]; then
    url="${url#//}"
    nhost="${url%%/*}"
    url="${url#$nhost}"
  fi
  if [[ $url == /* ]]; then
    n=""
    url="${url#/}"
  fi
  if [[ $url == \?* ]]; then
    n="$n$url"
    url=""
  fi

  IFS="/"
  set -f # path elements are no globs.
  for e in $url; do
    case "$e" in
      ..) n="${n%/*}"; ;;
      .|'') ;;
      *)
        n="$n/$e"
    esac
  done
  set +f
  unset IFS

  if [[ $url == */ ]]; then
    n="$n/"
  fi

  URL_PREV="$(url)"

  URL_HOST="$nhost"
  URL_PROTO="$nproto"
  URL_PATH="$n"
}

suffix() {
  URL_SUFFIX="$1"
}

curl() {
  (
    IFS="|"
    url=$(url)
    if [ -n "$URL_SUFFIX" ]; then
      if [[ $url == *\?* ]]; then
        url="${url/\?/$URL_SUFFIX?}"
      else
        url="$url$URL_SUFFIX"
      fi
    fi
    $CURL $(=curl-opts) "$@" -o $TMOUTPUT "$url"
  )
  code=$?

  [ -n "$output_filter" ] &&
    $output_filter "$TMOUTPUT" > "$OUTPUT" ||
    cp "$TMOUTPUT" "$OUTPUT"

  $_on_output
  $_stdout && cat $OUTPUT

  if [[ $code -gt 0 ]]; then
    return $code
  elif [[ $(resultcode) -ge 400 ]]; then
    return 22
  fi
  return 0
}

declare -a HISTACK=(0)
HIPOS=1
=history-ps1() {
  local x=${#HISTACK[*]}
  if [ $HIPOS != $x ]; then
    echo " $((HIPOS-1))/$((x-1))"
  fi
}

=history-append() {
  $GZIP -nc $OUTPUT >> $HISTORY
  HISTACK+=($(stat -c %s $HISTORY))
  HIPOS=${#HISTACK[*]}
}

=history-fetch() {
  local off size where
  where=${1:--1}
  off=$((HISTACK[where-1]))
  size=$((HISTACK[where]-off))
  # tail is evidently 1-based
  $TAIL -c +$((off+1)) $HISTORY | $HEAD -c $size | $GZIP -dc
}

=history-pop() {
  local c
  for c in $(seq ${1:-1}); do
    unset HISTACK[-1]
  done

  $TRUNCATE -s ${HISTACK[-1]} $HISTORY

  if [[ $HIPOS -gt ${#HISTACK[*]} ]]; then
    HIPOS=${#HISTACK[*]}
  fi
}

=history-goto() {
  local next=$1
  if [[ $next -gt ${#HISTACK[*]} ]]; then
    echo "No later output"
    return
  elif [[ $next -lt 2 ]]; then
    echo "No previous output"
    return
  fi
  HIPOS=$next
  =history-fetch $((HIPOS - 1)) > $OUTPUT
  $_on_output
  $_stdout && cat $OUTPUT
}

back() {
  local adj=${1:-1}
  =history-goto $((HIPOS - adj))
}

forward() {
  local adj=${1:-1}
  =history-goto $((HIPOS + adj))
}

last() {
  local adj=${1:-0}
  =history-goto $((${#HISTACK[*]} - adj))
}

first() {
  local adj=${1:-0}
  =history-goto $((1 + adj))
}

load() {
  if [ -n "$1" ]; then
    cp "$1" $PAYLOAD
  else
    cat > $PAYLOAD
  fi
}

use() {
  if [ -n "$1" ]; then
    PAYLOAD=$(readlink -f "$1")
  else
    echo "Usage: use <file>"
  fi
}

=payload-file() {
  local source

  if [ -t 0 ]; then
    source="$PAYLOAD"
  else
    source="-"
  fi

  if [ -n "$input_filter" ]; then
    [ "$source" = '-' ] && cat > "$TMINPUT" && source="$TMINPUT"

    $input_filter "$source" "$OUTPUT" > "$TMPAYLOAD" &&
      source="$TMPAYLOAD"
  fi
  echo "$source"
}

_call() {
  local f="$1"
  shift

  local OPTIND opt dp

  dp=false
  while getopts "dn" opt; do
    case "$opt" in
      d) dp=true; ;;
      n) dp=false; ;;
    esac
  done

  shift $((OPTIND-1))

  local args=()
  if $dp; then
    args+=("--data-binary" "@$(=payload-file)")
  fi

  if [ -n "$1" ]; then
    (cq "$1"; shift; "$f" "${args[@]}" "$@";)
  else
    "$f" "${args[@]}" "$@"
  fi

  =history-append
}
_get() {
  curl "$@"
}
get() {
  _call _get "$@"
}

_head() {
  curl -I "$@"
}
head() {
  _call _head "$@"
}

_post() {
  curl -XPOST "$@"
}
post() {
  _call _post -d "$@"
}

_put() {
  curl -XPUT "$@"
}
put() {
  _call _put -d "$@"
}

_options() {
  curl -XOPTIONS "$@"
}
options() {
  _call _options "$@"
}

_patch() {
  curl -XPATCH "$@"
}
patch() {
  _call _patch -d "$@"
}

_delete() {
  curl -XDELETE "$@"
}
delete() {
  _call _delete "$@"
}

default-settings

reload-cookbook() {
  [ -r ~/.rest.bashrc ] && source ~/.rest.bashrc
  if [ -d ~/.rest.bashrc.d ]; then
    for f in ~/.rest.bashrc.d/*; do
      source "$f"
    done
  fi
}

if [ -n "$_SCRIPT" ]; then
  source "$_SCRIPT"
else
  reload-cookbook
fi

