#!/bin/sh

DATASET="NIXROOT/home"
PATTERN='^[0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]:[0-9][0-9]$'
MAX_COUNT=48 # 2 hours
# for safety purpouses
check_snap_name() {
  if [ "$1" = "" ]; then
    echo "ERROR THIS SHOULD NEVER HAPPEN ENPTY SNAPSHOT NAME"
    exit 1
  fi
}
list_snap() {
  zfs list -t snapshot "$DATASET" | awk '{print $1}' | grep "$DATASET@" | awk -F'@' '{print $2}' | grep "$PATTERN"
}
create_snap() {
  echo "creating snapshot $1"
  check_snap_name "$1"
  sudo zfs snapshot "$DATASET@$1"
}
delete_snap() {
  echo "deleting snapshot $1"
  check_snap_name "$1"
  sudo zfs destroy "$DATASET@$1"
}
snap_count() {
  list_snap | grep -c "$PATTERN"
}
create() {
  list_snap
  snapshot_name=$(date +%y-%m-%d_%H:%M)
  if [ "$(echo "$snapshot_name" | grep "$PATTERN")" != "$snapshot_name" ]; then
    echo "snapshot_name not matching pattern"
    exit 1
  fi
  create_snap "$snapshot_name"
  
  count=$(snap_count)
  
  while [ "$count" -gt $MAX_COUNT ]
  do
      oldest=$(list_snap | sort | head -n 1)
      delete_snap "$oldest"
      count=$(snap_count)
  done
  list_snap
}
help_msg() {
  echo "create for creating a snapshot"
}
list() {
  list_snap
}

case $1 in
  "create" ) 
    create ;;
  "list")
   list;; 
  * ) 
  help_msg;;
esac

