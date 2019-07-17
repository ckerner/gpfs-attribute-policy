#!/bin/bash
#===============================================================================#
# This script will can be called on all of the nodes in the cluster to execute  #
# a command, but it will only execute on the manager node.                      #
#-------------------------------------------------------------------------------#
# Source: https://github.com/ckerner/gpfs-shell-functions.git                   #
#-------------------------------------------------------------------------------#
# Chad Kerner - ckerner@illinois.edu - chad.kerner@gmail.com                    #
# Senior Storage Engineer, Storage Enabling Technologies                        #
# National Center for Supercomputing Applications                               #
# University of Illinois, Urbana-Champaign                                      #
#===============================================================================#

PID=$$
MYDIR=`dirname $0`
if [[ ${MYDIR} == .* ]] ; then
   MYDIR=`pwd`
fi

DEFAULT_CALLOUT=${MYDIR}/attributes.sh
DEFAULT_POLICY=${MYDIR}/policy.in
DEFAULT_IMMUTABILITY="yes"
DEFAULT_WORK_DIR=/cforge/admin/chad/tmp
MMAPPLYPOLICY=`which mmapplypolicy`

# Print the usage screen
function print_usage {
   PRGNAME=`basename $0`

   cat << EOHELP

   Usage: ${PRGNAME} [-d|--debug] [-v|--verbose] [-h|--help] 
                     [-i|--immutable yes|no]
		     [-u|--uid UID]
		     [-g|--gid GID]
		     [-p|--perms PERMISSIONS]
		     [-s|--search PATH]
		     [-m|--match PATH]

   OPTION          USAGE
   -i|--immutable  Toggle immutability: YES or NO
   -u|--uid        Set the UID on the specified path
   -g|--gid        Set the GID on the specified path
   -p|--perms      Set the permissions on the specified path. Ex: -p 2770
   -D|--debug      Execute in debug mode. Very verbose(set -x).

   -h|--help       This help screen

   Don't mess with this if you don't understand what you are doing, you WILL break
   things in a bad way.

   OPTION          USAGE
   -v|--verbose    Execute the callout script in verbose mode.
   -c|--callout    Specifies the path to a callout script executed by mmapplypolicy
   -P|--policy     Specifies the path to the policy file
   -w|--work       Specifies the path to use as a work directory.

EOHELP
}

function print_error {
   MSG=$@
   printf "\n\tERROR: %s\n" "${MSG}"
   exit 1
}

function process_options {
   while [ $# -gt 0 ]
      do case $1 in
         -w|--work)       shift ; WORK_DIR=$1 ;;
         -s|--search)     shift ; SEARCH_PATH=$1 ;;
         -m|--match)      shift ; MATCH_PATTERN=$1 ;;
         -i|--immutable)  shift ; NEWIMM=$1 ; SETIMM=1 ;;
         -u|--uid)        shift ; NEWUID=$1 ; SETUID=1 ;;
         -g|--gid)        shift ; NEWGID=$1 ; SETGID=1 ;;
         -p|--perms)      shift ; NEWPERMS=$1 ; SETPERMS=1 ;;
         -P|--policy)     shift ; POLICY_FILE=$1 ;;
         -c|--callout)    shift ; CALLOUT_FILE=$1 ;;
         -v|--verbose)    VERBOSE=1 ;;
         -D|--debug)      DEBUG=1 ;;
         -h|--help)       print_usage ; exit 1 ;;
      esac
      shift
   done
}

function validate_options {
   if [ "x${MMAPPLYPOLICY}" == "x" ] ; then
      print_error "GPFS is not installed properly."
   fi

   # Validate some of the options
   [[ ${DEBUG:=0} ]]
   [[ ${VERBOSE:=0} ]]
   [[ ${SETIMM:=0} ]]
   [[ ${SETUID:=0} ]]
   [[ ${SETGID:=0} ]]
   [[ ${SETPERMS:=0} ]]
   [[ ${NEWIMM:=$DEFAULT_IMMUTABILITY} ]]
   [[ ${POLICY_FILE:=$DEFAULT_POLICY} ]]
   [[ ${CALLOUT_FILE:=$DEFAULT_CALLOUT} ]]
   [[ ${WORK_DIR:=$DEFAULT_WORK_DIR} ]]

   if [ ${SETIMM} -eq 1 ] ; then
      if [ "x${NEWIMM}" == "x" ] ; then
         print_error "You must specify a immutability as YES or NO."
      fi
   fi

   if [ ${SETUID} -eq 1 ] ; then
      if [ "x${NEWUID}" == "x" ] ; then
         print_error "You must specify a UID."
      fi
   fi

   if [ ${SETGID} -eq 1 ] ; then
      if [ "x${NEWGID}" == "x" ] ; then
         print_error "You must specify a GID."
      fi
   fi

   if [ ${SETPERMS} -eq 1 ] ; then
      if [ "x${NEWPERMS}" == "x" ] ; then
         print_error "You must specify valid permissions."
      fi
   fi

   if [ "x${SEARCH_PATH}" == "x" ] ; then
      print_error "You must specify a search path."
   fi

   if [ "x${MATCH_PATTERN}" == "x" ] ; then
      print_error "You must specify a match path."
   fi

   if [[ ! -d ${SEARCH_PATH} ]] ; then
      print_error "Search path does not exist: ${SEARCH_PATH}"
   fi

   OPTIONS_PATH=`dirname ${CALLOUT_FILE}`
   OPTIONS_FILE=${OPTIONS_PATH}/policy.options

   if [[ ! -d ${WORK_DIR} ]] ; then
      mkdir -p ${WORK_DIR}
   fi
}


function write_options_file {
   rm -f ${OPTIONS_FILE} &>/dev/null

   echo "VERBOSE=${VERBOSE}" >> ${OPTIONS_FILE}

   if [ ${SETIMM} -eq 0 ] ; then
      echo "CHANGE_ATTRIBUTES=0" >> ${OPTIONS_FILE}
      echo "IMMUTABLE=${NEWIMM}" >> ${OPTIONS_FILE}
   else
      echo "CHANGE_ATTRIBUTES=1" >> ${OPTIONS_FILE}
      echo "IMMUTABLE=${NEWIMM}" >> ${OPTIONS_FILE}
   fi

   if [ ${SETUID} -eq 0 ] ; then
      echo "CHANGE_OWNER=0" >> ${OPTIONS_FILE}
      echo "SET_OWNERSHIP=${NEWUID}" >> ${OPTIONS_FILE}
   else
      echo "CHANGE_OWNER=1" >> ${OPTIONS_FILE}
      echo "SET_OWNERSHIP=${NEWUID}" >> ${OPTIONS_FILE}
   fi

   if [ ${SETGID} -eq 0 ] ; then
      echo "CHANGE_GROUP=0" >> ${OPTIONS_FILE}
      echo "SET_GROUP=${NEWGID}" >> ${OPTIONS_FILE}
   else
      echo "CHANGE_GROUP=1" >> ${OPTIONS_FILE}
      echo "SET_GROUP=${NEWGID}" >> ${OPTIONS_FILE}
   fi

   if [ ${SETPERMS} -eq 0 ] ; then
      echo "CHANGE_PERMISSIONS=0" >> ${OPTIONS_FILE}
      echo "SET_PERMISSIONS=${NEWPERMS}" >> ${OPTIONS_FILE}
   else
      echo "CHANGE_PERMISSIONS=1" >> ${OPTIONS_FILE}
      echo "SET_PERMISSIONS=${NEWPERMS}" >> ${OPTIONS_FILE}
   fi
}

function write_policy_file {
cat << EOPOLICY > ${POLICY_FILE}
RULE external list 'listall' exec '${CALLOUT_FILE}'
RULE 'listall' LIST 'listall' DIRECTORIES_PLUS
     WHERE PATH_NAME LIKE '${MATCH_PATTERN}%'

EOPOLICY
}

# Main Code Block
{
   # If no parameters specified, show the help screen.
   if [ $# -lt 1 ] ; then
      print_usage
      exit
   fi

   # Process the command line options
   process_options $*

   # Do some sanity checks
   validate_options

   # Turn on debugging if it was specified
   if [ ${DEBUG} -eq 1 ] ; then
      set -x
   fi

   # Write out the options for the external callout script
   write_options_file

   # Write out the necessary policy file for the run
   write_policy_file

   # OK, lets execute it
   ${MMAPPLYPOLICY} ${SEARCH_PATH} -f ${WORK_DIR} -s ${WORK_DIR} -P ${POLICY_FILE}
}

# Exit gracefully
exit 0

