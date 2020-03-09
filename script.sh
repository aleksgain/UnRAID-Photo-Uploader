#!/bin/bash
PATH=/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin

## Usage (after configuration):
## 1. Insert camera's memory card into a USB port on your unRAID system
## 2. The system will automatically move (or copy) any images/videos from the memory card to the array
## 3. Wait for the imperial theme to play, then remove the memory card

## Preparation:
## 1. Install jhead (to automatically rotate photos) using the Nerd Pack plugin
## 2. Install the "Unassigned Devices" plugin
## 3. Use that plugin to set this script to run *in the background* when a memory card is inserted
## 4. Configure variables in this script as described below

## --- BEGIN CONFIGURATION ---

## SET THIS FOR YOUR CAMERAS: 
## array of directories under /DCIM/ that contain files you want to move (or copy)
## can contain regex
VALIDDIRS=("/DCIM/[0-9][0-9][0-9]_PANA" "/DCIM/[0-9][0-9][0-9]OLYMP" "/DCIM/[0-9][0-9][0-9]MEDIA" "/DCIM/[0-9][0-9][0-9]GOPRO")
## SET THIS FOR YOUR SYSTEM:
## location to move files to. use date command to ensure unique dir
DESTINATION_PHOTO="/mnt/user/Photo/$(date +"%m-%d-%Y")/"
DESTINATION_VIDEO="/mnt/user/Video/$(date +"%m-%d-%Y")/"

## SET THIS FOR YOUR SYSTEM:
## change to "move" when you are confident everything is working
MOVE_OR_COPY="move"

## set this to 1 and check the syslog for additional debugging info
DEBUG=""

log_all() {
  log_local "$1"
  logger "$PROG_NAME-$1"
}

log_local() {
  echo "`date` $PROG_NAME-$1"
  echo "`date` $PROG_NAME-$1" >> $LOGFILE
}

log_debug() {
  if [ ${DEBUG} ]
  then
    log_local "$1"
  fi
}

case $ACTION in
  'ADD' )
    #
    # Beep that the device is plugged in.
    #
    beep  -l 200 -f 600 -n -l 200 -f 800
    sleep 2

    if [ -d $MOUNTPOINT ]
    then
        log_all "Started"
        log_debug "Logging to $LOGFILE"

        RSYNCFLAG=""
        MOVEMSG="copying"
        if [ ${MOVE_OR_COPY} == "move" ]
        then
          RSYNCFLAG=" --remove-source-files "
          MOVEMSG="moving"
        fi

        # only operate on USB disks that contain a /DCIM directory, everything else will simply be mounted
        if [ -d "${MOUNTPOINT}/DCIM" ]
        then
          log_debug "DCIM exists ${MOUNTPOINT}/DCIM"

          # loop through all the subdirs in /DCIM looking for dirs defined in VALIDDIRS
          for DIR in ${MOUNTPOINT}/DCIM/*; do
            if [ -d "${DIR}" ]; then
              log_debug "checking ${DIR}"
              for element in "${VALIDDIRS[@]}"; do
                if [[ ${DIR} =~ ${element} ]]; then
                  # process this dir
                  log_local "${MOVEMSG} ${DIR}/ to ${DESTINATION_PHOTO}"
                  rsync -a ${RSYNCFLAG} --include="*/" --include="*.RW2" --include="*.ORF" --include="*.jpg" --include="*.jpeg" --exclude="*" "${DIR}/" "${DESTINATION_PHOTO}"
                log_local "${MOVEMSG} ${DIR}/ to ${DESTINATION_VIDEO}"
                  rsync -a ${RSYNCFLAG} --include="*/" --include="*.MP4" --include="*.mov" --exclude="*" "${DIR}/" "${DESTINATION_VIDEO}"
                  # remove empty directory from memory card
                  if [ ${MOVE_OR_COPY} == "move" ]; then
                    rmdir ${DIR}
                  fi
                fi
              done
            fi
          done

          # files were moved (or copied), fix permissions
          if [ -d "${DESTINATION_PHOTO}" ]; then

            log_debug "fixing permissions on ${DESTINATION_PHOTO}"
            newperms "${DESTINATION_PHOTO}"

          fi

          if [ -d "${DESTINATION_VIDEO}" ]; then

            log_debug "fixing permissions on ${DESTINATION_VIDEO}"
            newperms "${DESTINATION_VIDEO}"

          fi

          # sync and unmount USB drive 
          sync
          /usr/local/sbin/rc.unassigned umount $DEVICE

          # send notification
          /usr/local/emhttp/webGui/scripts/notify -e "unRAID Server Notice" -s "Photo Import" -d "Photo Import completed" -i "normal"

        fi  # end check for DCIM directory
	  
    else
      log_all "Mountpoint doesn't exist $MOUNTPOINT"
    fi  # end check for valid mountpoint
  ;;

  'REMOVE' )
    #
    # Beep that the device is unmounted.
    #
    beep  -l 200 -f 800 -n -l 200 -f 600

    log_all "Photo Import drive unmounted, can safely be removed"
  ;;
esac