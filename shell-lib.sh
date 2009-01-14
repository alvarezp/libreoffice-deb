# vim:set ai et sts=2 sw=2 tw=0:

# Query the terminal to establish a default number of columns to use for
# displaying messages to the user.  This is used only as a fallback in the
# event the COLUMNS variable is not set.  ($COLUMNS can react to SIGWINCH while
# the script is running, and this cannot, only being calculated once.)
DEFCOLUMNS=$(stty size 2> /dev/null | awk '{print $2}') || true
if ! expr "$DEFCOLUMNS" : "[[:digit:]]\+$" > /dev/null 2>&1; then
  DEFCOLUMNS=80
fi

message() {
	echo "$*" | fmt -t -w ${COLUMNS:-$DEFCOLUMNS} >&2
}

# Prepare to move a conffile without triggering a dpkg question
prep_rm_conffile() {
    CONFFILE="$1"

    if [ -e "$CONFFILE" ]; then
        md5sum="`md5sum \"$CONFFILE\" | sed -e \"s/ .*//\"`"
        old_md5sum="`dpkg-query -W -f='${Conffiles}' $2 | grep $CONFFILE | awk '{print $2}'`"
        if [ "$md5sum" = "$old_md5sum" ]; then
            mv "$CONFFILE" "$CONFFILE.${THIS_PACKAGE}-tmp"
        fi
    fi
}

rm_conffile_commit() {
  CONFFILE="$1"

  if [ -e $CONFFILE.${THIS_PACKAGE}-tmp ]; then
    rm $CONFFILE.${THIS_PACKAGE}-tmp
  fi
}

# Remove a no-longer used conffile
rm_conffile() {
    CONFFILE="$1"

    if [ -e "$CONFFILE" ]; then
        md5sum="`md5sum \"$CONFFILE\" | sed -e \"s/ .*//\"`"
        old_md5sum="`dpkg-query -W -f='${Conffiles}' $2 | grep $CONFFILE | awk '{print $2}'`"
        if [ "$md5sum" != "$old_md5sum" ]; then
            echo "Obsolete conffile $CONFFILE has been modified by you."
            echo "Saving as $CONFFILE.dpkg-bak ..."
            mv -f "$CONFFILE" "$CONFFILE".bak
        else
            echo "Removing obsolete conffile $CONFFILE ..."
            rm -f "$CONFFILE"
        fi
    fi
}

flush_unopkg_cache() {
	/usr/lib/openoffice/program/unopkg list --shared > /dev/null 2>&1
}

remove_extension() {
  if /usr/lib/openoffice/program/unopkg list --shared $1 >/dev/null; then
    echo -n "Removing extension $1..."
    INSTDIR=`mktemp -d`
    /usr/lib/openoffice/program/unopkg remove --shared $1 \
      "-env:UserInstallation=file://$INSTDIR" \
      '-env:UNO_JAVA_JFW_INSTALL_DATA=$ORIGIN/../share/config/javasettingsunopkginstall.xml' \
      "-env:JFW_PLUGIN_DO_NOT_CHECK_ACCESSIBILITY=1"
    if [ -n $INSTDIR ]; then rm -rf $INSTDIR; fi
    echo " done."
    flush_unopkg_cache
  fi
}

add_extension() {
  echo -n "Adding extension $1..."
  INSTDIR=`mktemp -d`
  /usr/lib/openoffice/program/unopkg add --shared $1 \
    "-env:UserInstallation=file:///$INSTDIR" \
    '-env:UNO_JAVA_JFW_INSTALL_DATA=$ORIGIN/../share/config/javasettingsunopkginstall.xml' \
    "-env:JFW_PLUGIN_DO_NOT_CHECK_ACCESSIBILITY=1"
  if [ -n $INSTDIR ]; then rm -rf $INSTDIR; fi
  echo " done."
}

VER=

