#!/bin/ksh
#
# Modify this at your own risk. 
# If you need to further filter on filename, you can put a grep between
# the PERL line and the WHILE line in the LIST section.
#
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
        while read FILENAME; do
	   # If VERBOSE, lets see what file we are on
	   if [ ${VERBOSE} -eq 1 ] ; then
	      echo "${FILENAME}"
	   fi

           # Set the immutability
           if [ ${CHANGE_ATTRIBUTES} -eq 1 ] ; then
	      if [ ${CHANGE_APPEND} -eq 1 ] ; then
		 if [[ -f ${FILENAME} ]] ; then
                    /usr/lpp/mmfs/bin/mmchattr -a ${APPEND} -i ${IMMUTABLE} -I yes "${FILENAME}"
		 else
                    /usr/lpp/mmfs/bin/mmchattr -i ${IMMUTABLE} -I yes "${FILENAME}"
		 fi
	      else
                 /usr/lpp/mmfs/bin/mmchattr -i ${IMMUTABLE} -I yes "${FILENAME}"
              fi
	   else
	      if [ ${CHANGE_APPEND} -eq 1 ] ; then
		 if [[ -f ${FILENAME} ]] ; then
                    /usr/lpp/mmfs/bin/mmchattr -a ${APPEND} -I yes "${FILENAME}"
		 fi
	      fi
           fi

           # Set the owner
           if [ ${CHANGE_OWNER} -eq 1 ] ; then
              /bin/chown ${SET_OWNERSHIP} "${FILENAME}"
           fi

           # Set the group
           if [ ${CHANGE_GROUP} -eq 1 ] ; then
              /bin/chgrp ${SET_GROUP} "${FILENAME}"
           fi

           # Set the permission
           if [ ${CHANGE_PERMISSIONS} -eq 1 ] ; then
              /bin/chmod ${SET_PERMISSIONS} "${FILENAME}"
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
