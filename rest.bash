#!/bin/bash
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
#                 value removes the header.
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
#                 'get' and 'delete' will not read $PAYLOAD unless '-d' is set,
#                 whereas 'post' and put *will* read $PAYLOAD unless '-n' is
#                 set. If both '-d' and '-n' are specified and/or multiple
#                 times, the last occurence will take precedence.
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
#                         JSON mode uses Python's json module for pretty
#                         printing and the tool 'joqe' for selections using
#                         'sel' if available.
#                 * xml 
#                         XML mode uses 'xmllint' for pretty printing and
#                         XPath selections using 'sel' if available.
#
#         * sel <query> 
#                 Select data from the previous output. This uses the $OUTPUT
#                 file and can be executed several times without sending new
#                 requests to the service. The query syntax is defined by The
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
#                         =unset-mode
#                 }
#                 =xml-filter() {
#                         xmllint --format "$1"
#                 }
#                 =xml-select() {
#                         xmllint --xpath "$*" $OUTPUT
#                 }
#
#         To enable, use 'mode xml'. '=unset-mode' is a helper function
#         provided by rest.bash to unset common mode overrides, such as the
#         accept header, content-type header, output_filter and sel alias.
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
#                 the cookbook directory in the source tree for examples.
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
#         rest.bash is Copyright (c) 2015 Fredrik Alstromer.
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
}

#NB: IFS is '|' when calling $CURL.
CURL=/usr/bin/curl
CUT=/usr/bin/cut
GREP=/bin/grep
MKTEMP=/bin/mktemp
RM=/bin/rm
SED=/bin/sed
TEE=/usr/bin/tee

HISTFILE=~/.rest.bash_history

if [ -n "$PS1" ]; then
  tPS1='$(resultcode) REST[$(url)]'
  PS1="$tPS1"'\$ '
  color_prompt=false
  case "$TERM" in
    *color*)
      color_prompt=true
      ;;
  esac
  if $color_prompt; then
    PS1='\[$(resultcode-color)\]$(resultcode)\[\e[00m\] REST[$(url)] '
  fi
  case "$TERM" in
    xterm*|rxvt*)
      PS1='\[\e]0;'"$tPS1"'\a\]'"$PS1"
      ;;
  esac
fi

# hook for reacting on new output
_on_output=true

# hook for controlling stdout; evaluate to false to suppress.
_stdout=true

URL_PROTO="http"
URL_HOST="localhost"
URL_PATH=""
URL_SUFFIX=""
url() { echo "$URL_PROTO://$URL_HOST${URL_PATH:-/}"; }
URL_PREV="$(url)"

PAYLOAD=`$MKTEMP /tmp/rest-payload.XXXXXX`
OUTPUT=`$MKTEMP /tmp/rest-output.XXXXXX`
HTTPHEADER=`$MKTEMP /tmp/rest-httpstatus.XXXXXX`

trap "$RM $PAYLOAD $OUTPUT $HTTPHEADER; mode none" EXIT
export OUTPUT PAYLOAD HTTPHEADER

files() {
  echo Payload: $PAYLOAD
  echo Output: $OUTPUT
  echo HTTP Status: $HTTPHEADER
}
resultcode() {
  local line=`$SED -ne 's/[\r\n]*$//' -e1p -eq $HTTPHEADER`
  case $line in
    HTTP/2.0\ *) cut -f2 -d ' '<<<$line; ;;
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
  esac
  return 1
}

declare -A CURL_OPTS

=curl-opts() {
  echo -n "-s|-D|$HTTPHEADER"
  for key in "${!CURL_OPTS[@]}"; do
    echo -n "${CURL_OPTS[$key]}"
  done
}

# HTTP request header functions, call without value to clear.

header() {
  if [ -n "$1" ]; then
    local header="$1"
    local key="head:$header"
    shift
    unset CURL_OPTS[$key]
    [ -n "$1" ] && CURL_OPTS[$key]="|-H|$header: $*"
  else
    for key in "${!CURL_OPTS[@]}"; do
      if [ "${key#head:}" != "$key" ]; then
        sed -e 's/.*|//' <<<"${CURL_OPTS[$key]}"
      fi
    done
  fi
}
accept() {
  header Accept "$@"
}

content-type() {
  header Content-Type "$@"
}

cookie() {
  header Cookie "$@"
}

authorization() {
  header Authorization "$@"
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
    local b64=`echo -n $user:$pass|base64`
    authorization Basic $b64
  fi
}

## Set ssl-insecure on to allow self-signed and incorrect certificates.
ssl-insecure() {
  unset CURL_OPTS[SSL_INSECURE]
  =truth "$1" && CURL_OPTS[SSL_INSECURE]='|-k'
}

# I/O mode switching functions

MODE=none

mode() {
  if [ "`type -t -- "+$1"`" == function ]; then
    if [ "`type -t -- "-$MODE"`" == function ]; then
      "-$MODE"
    fi
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
  content-type
  output_filter='cat'
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
  =unset-mode
}

## JSON mode

JSONPP="/usr/bin/python -m json.tool"
JOQE="`which joqe`"

=json-filter() {
  $JSONPP "$1" || =plain-filter "$1"
}

=joqe-filter() {
  $JOQE -ffqr / "$1" || =plain-filter "$1"
}
=joqe-select() {
  $JOQE -ffr "$*" "$OUTPUT"
}

+json() {
  accept 'application/json,*/*;q=0.9'
  content-type application/json


  if [ -x "$JOQE" ]; then
    alias sel='=joqe-select'
    output_filter='=joqe-filter'
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
  =unset-mode
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
  =unset-mode
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
  TMPOUT=`/bin/mktemp /tmp/rest-output-tmp.XXXXXX`
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
    $CURL $(=curl-opts) "$@" -o $TMPOUT "$url"
  )
  code=$?

  $output_filter "$TMPOUT" > "$OUTPUT"
  rm -f "$TMPOUT"

  $_on_output
  $_stdout && cat $OUTPUT

  if [[ $code -gt 0 ]]; then
    return $code
  elif [[ $(resultcode) -ge 400 ]]; then
    return 22
  fi
  return 0
}

load() {
  if [ -n "$1" ]; then
    cp "$1" $PAYLOAD
  else
    cat > $PAYLOAD
  fi
}

=payload-file() {
  [ -t 0 ] && echo $PAYLOAD || echo -
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

_delete() {
  curl -XDELETE "$@"
}
delete() {
  _call _delete "$@"
}

default-settings

if [ -n "$_SCRIPT" ]; then
  source "$_SCRIPT"
else
  [ -r ~/.rest.bashrc ] && source ~/.rest.bashrc
  if [ -d ~/.rest.bashrc.d ]; then
    for f in ~/.rest.bashrc.d/*; do
      source "$f"
    done
  fi
fi

