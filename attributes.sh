#!/bin/ksh

PROGDIR=`dirname $0`


source ${PROGDIR}/policy.options

case $1 in
     NOLIST)
        cat $2 | \
        grep -vE "^\[I\]" | \
        perl -ne '@f = split(" -- ", $_); print"$f[1]";'
        rc=0
        ;;
     LIST)      # Simply cat the filelist to stdout
        cat $2 | \
        grep -vE "^\[I\]" | \
        perl -ne '@f = split(" -- ", $_); print"$f[1]";' | \
        while read DATAIN; do
	   # If VERBOSE, lets see what file we are on
	   if [ ${VERBOSE} -eq 1 ] ; then
	      echo "${DATAIN}"
	   fi

           # Set the immutability
           if [ ${CHATTR} -eq 1 ] ; then
              /usr/lpp/mmfs/bin/mmchattr -i ${IMMUT} -I yes "${DATAIN}"
           fi

           # Set the owner
           if [ ${CHOWN} -eq 1 ] ; then
                /bin/chown ${SETOWN} "${DATAIN}"
           fi

           # Set the group
           if [ ${CHGRP} -eq 1 ] ; then
              /bin/chgrp ${SETGRP} "${DATAIN}"
           fi

           # Set the permission
           if [ ${CHMOD} -eq 1 ] ; then
              /bin/chmod ${SETMOD} "${DATAIN}"
           fi
        done
        rc=0
        ;;
     TEST)     # Respond with success
        rc=0
        ;;
     *)       # Command not supported by this script
        rc=1
        ;;
esac
exit $rc
