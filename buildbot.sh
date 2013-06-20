#!/bin/bash
_DEBUG="off"

function DEBUG()
{
 [ "$_DEBUG" == "on" ] &&  $@
}

if [ -r /etc/sysconfig/buildbot.cfg ]; then
  echo "Reading system-wide config...." >&2
  . /etc/sysconfig/buildbot.cfg
fi

if [ -r ./buildbot.cfg ]; then
  echo "Reading user config...." >&2
  . ./buildbot.cfg
fi

# Utility tests
if [ ! -f /usr/bin/rpmlint ]; then
  echo "ERROR: Missing rpmllint...." >&2
  exit 1
fi
if [ ! -f /usr/bin/curl ]; then
  echo "ERROR: Missing curl...." >&2
  exit 1
fi
if [ ! -f /usr/bin/spectool ]; then
  echo "ERROR: Missing spectool...." >&2
  exit 1
fi
if [ ! -f /usr/bin/wget ]; then
  echo "ERROR: Missing wget...." >&2
  exit 1
fi

echo "Using repository at [$REPO]"

cd $REPO
OLD_HEAD=`git rev-parse HEAD`

echo "Getting the commits...." >&2
#git pull --rebase
git pull
COMMITS=`git rev-list $OLD_HEAD..HEAD --reverse`

#echo $COMMITS

if [ -z "$COMMITS" ]; then
  echo "No new commits. Nothing to do...."
else
  for COMMIT in $COMMITS; do
    echo "Working with commit [$COMMIT]"
    SPECS=`git show --name-only --oneline $COMMIT | grep -e ^specs\/.*\.spec$ | sort -r`
    for SPEC in $SPECS; do
      echo "  Working with specfile [$SPEC]"

      RPMLINT=`rpmlint $SPEC | sed 's/\\\/\\\\\\\/g;s/"/\\\"/g' | sed 's/$/\\\r\\\n/' | tr -d '\n' `
      DEBUG echo $RPMLINT
      COMMENT="{ \"body\": \"#### rpmlint status\\r\\n\`\`\`\\r\\n$RPMLINT\`\`\`\"}"
      DEBUG echo $COMMENT
      curl -s -H "Authorization: token $GH_TOKEN" -d "$COMMENT" -X POST https://api.github.com/repos/$GH_USER/$GH_REPO/commits/$COMMIT/comments

      COMMENT=""
      for URL in $(spectool -l $SPEC 2>/dev/null | cut -f2 -d' '); do
        WGET=""
        FILENAME="$(dirname $SPEC)/$(basename $URL)"
        DEBUG echo "  Working with filename [$FILENAME]"
        DEBUG echo "  Working with URL [$URL]"
        if [ ! -s "$FILENAME" ]; then
          echo "  Source \"$(basename $FILENAME)\" not found, downloading [$URL]."
          i=1
          RC=1
          while [ $RC -ne 0 -a $i -lt 4 ]; do
            WGET=`wget -nv --server-response -P /tmp -t30 -T10 "$URL" 2>&1 | sed 's/\\\/\\\\\\\/g;s/"/\\\"/g' | sed 's/$/\\\r\\\n/' | tr -d '\n'`
            #WGET=`wget --server-response -P /tmp -t30 -T10 "$URL" | sed 's/\\\/\\\\\\\/g;s/"/\\\"/g' | sed 's/$/\\\r\\\n/' | tr -d '\n'`
            DEBUG echo "  $WGET"
            RC=$?
            i=$((i+1))
          done
          if [ $RC -ne 0 ]; then
            echo "  ERROR: Troubles downloading source [$URL]."
          fi
        fi
        COMMENT="$COMMENT\\r\\n$WGET"
      done
      COMMENT="{ \"body\": \"#### spectool & wget status\\r\\n\`\`\`$COMMENT\`\`\`\"}"
      DEBUG echo $COMMENT
      curl -s -H "Authorization: token $GH_TOKEN" -d "$COMMENT" -X POST https://api.github.com/repos/$GH_USER/$GH_REPO/commits/$COMMIT/comments


    done
  done

fi
