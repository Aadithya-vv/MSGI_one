#!/bin/sh
# Fixed read-only routes for the isolated GoTrue rendering test. No logging.
IFS= read -r request
case "$request" in
  'GET /confirmation.html HTTP/'*) file=/drafts/confirmation.html ;;
  'GET /recovery.html HTTP/'*) file=/drafts/recovery.html ;;
  'GET /email-change.html HTTP/'*) file=/drafts/email-change.html ;;
  *) printf 'HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\n\r\n'; exit 0 ;;
esac
cr=$(printf '\r')
while IFS= read -r header; do [ "$header" = "$cr" ] && break; done
printf 'HTTP/1.0 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n'
cat "$file"
