#!/bin/sh
# made by: KorG

USER=bot
S=/usr/local/bin/screen
SCREEN_NAME=bot
SCREEN_RC=/dev/null

panic(){ echo "$*" >&2 ;exit 2 ; }

IFS="'"
for arg ;do ARGS="$ARGS '$arg'" ;done
unset IFS

[ x"`/usr/bin/id -u`" = x"`/usr/bin/id -u "$USER"`" ] ||
   exec /usr/bin/su - "$USER" -c "/bin/sh -c '$0 \"$@\"' _ $ARGS"

"$S" -S "$SCREEN_NAME" -q -ls
[ 8 = $? ] || panic some screen found with name "$SCREEN_NAME"

"$S" -c "$SCREEN_RC" -dmS "$SCREEN_NAME" /bin/sh -c "${1:?specify command}"

shift

for cmd ;do
   "$S" -c "$SCREEN_RC" -mS "$SCREEN_NAME" -X screen "/bin/sh -c '$cmd'"
done
