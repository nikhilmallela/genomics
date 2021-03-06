#!/bin/sh
#
# log_seq_data.sh <log_file> <seq_data_dir>
#
# Creates a new entry in a log of sequencing data directories
#
function usage() {
    echo "`basename $0` <logging_file> [-d|-u] <seq_data_dir> [<description>]"
    echo ""
    echo "Add, update or delete an entry for <seq_data_dir> in <logging_file>."
    echo
    echo "<seq_data_dir> can be a primary data directory from a sequencer or a"
    echo "directory of derived data (e.g. analysis directory)"
    echo
    echo "By default an entry is added for the specified data directory; each"
    echo "entry is a tab-delimited line with the full path for the data directory"
    echo "followed by the UNIX timestamp and the optional description text."
    echo ""
    echo "If <logging_file> doesn't exist then it will be created; if"
    echo "<seq_data_dir> is already in the log file then it won't be added again."
    echo
    echo "-d deletes an existing entry, while -u updates it (or adds a new one if"
    echo "not found). -u is intended to allow descriptions to be modified."
}
#
# Import external function libraries
. `dirname $0`/../share/functions.sh
. `dirname $0`/../share/lock.sh
#
# Initialise
if [ $# -lt 2 ] ; then
    usage
    exit
fi
MODE=add
#
# Command line
LOG_FILE=$1
if [ "$2" == "-d" ] ; then
    # Delete entry
    MODE=delete
    shift
elif [ "$2" == "-u" ] ; then
    # Update entry
    MODE=update
    shift
fi
SEQ_DATA_DIR=`readlink -m $(abs_path $2)`
DESCRIPTION=$3
#
# Make a lock on the log file
lock_file $LOG_FILE --remove
if [ "$?" != "1" ] ; then
    echo "Couldn't get lock on $LOG_FILE"
    exit 1
fi
#
# Check that the sequencing data directory exists (unless
# in delete mode)
if [ ! -d "$SEQ_DATA_DIR" ] && [ $MODE != "delete" ] ; then
    echo "No directory $SEQ_DATA_DIR"
    unlock_file $LOG_FILE
    exit 1
fi
#
# Add entry
if [ $MODE == add ] ; then
    #
    # Check that log file exists
    if [ ! -e "$LOG_FILE" ] ; then
	echo "Making $LOG_FILE"
	touch $LOG_FILE
	# Write a header
	cat > $LOG_FILE <<EOF
# Log of sequencing data directories
EOF
    fi
    #
    # Check if an entry already exists
    has_entry=`grep ${SEQ_DATA_DIR}$'\t' $LOG_FILE | wc -l`
    if [ $has_entry -gt 0 ] ; then
	echo "Entry already exists for $SEQ_DATA_DIR in $LOG_FILE"
	unlock_file $LOG_FILE
	exit 1
    fi
    #
    # Append an entry to the log file
    echo "Adding entry to $LOG_FILE"
    echo ${SEQ_DATA_DIR}$'\t'$(timestamp $SEQ_DATA_DIR)$'\t'${DESCRIPTION} >> $LOG_FILE
fi
#
# Delete entry
if [ $MODE == delete ] || [ $MODE == update ] ; then
    #
    # Make a temporary file
    tmpfile=`mktemp`
    #
    # Delete the entry
    echo "Removing entry for $SEQ_DATA_DIR"
    grep -v ^${SEQ_DATA_DIR}$'\t' $LOG_FILE > $tmpfile
    #
    # Re-add if updating
    if [ $MODE == update ] ; then
	echo "Recreating entry for $SEQ_DATA_DIR"
	echo ${SEQ_DATA_DIR}$'\t'$(timestamp $SEQ_DATA_DIR)$'\t'${DESCRIPTION} >> $tmpfile
    fi
    #
    # Replace log file with new version
    echo "Updating $LOG_FILE"
    /bin/mv $tmpfile $LOG_FILE
    /bin/rm -f $tmpfile
fi
#
# Sort into order
sortfile=`mktemp`
sort -r -k 2 $LOG_FILE > $sortfile
/bin/mv $sortfile $LOG_FILE
/bin/rm -f $sortfile
#
# Finished
unlock_file $LOG_FILE
exit
##
#
