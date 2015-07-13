#!/bin/bash

### VARIABLES
zimbra_user="zimbra"
version="0.2"
domain=""
accounts_list=$(zmaccts | grep "@$domain" | cut -d" " -f1)
backup_folder="/zimbra_backup"

### FUNCTIONS

function print_usage
{
  echo -e "zmbackup-ng [-a] [-h] [-m account@domain.tld] [-r account@domain.tld] [-v]\n"
  echo "-a :  Automatic full backup."
  echo "-h :  Display help / command usage."
  echo "-m :  Manual backup."
  echo "-af :  Manual backup with force-overwrite. Use with caution."
  echo "-r :  Restore the specified account mailbox."
  echo -e "-v --version :  Display zmbackup-ng current version.\n"
}

function manual_backup
{
  if [[ -z "$1" ]];then
    echo -e "\nPlease, enter the address of the mailbox you want to backup :"
    echo -n "> "
    read backup_target
  else
    backup_target="$1"
  fi
  if [[ " $accounts_list " =~ $backup_target ]];then
    mkdir -p $backup_folder/$(date +%Y-%m-%d)
    check_overwrite
      if [[ $overwrite_yn == "y" ]];then
        zmmailbox -z -m $backup_target getRestURL '/?fmt=tgz' > $backup_folder/$(date +%Y-%m-%d)/$backup_target.tar.gz
        echo "[DONE] $backup_target."
        exit 0
      elif [[ $overwrite_yn == "n" ]];then
        echo "[ABORT] backup aborted for $backup_target."
        exit 1
      else
        echo "[FAILED] Wrong input. Backup aborted for $backup_target."
        exit 1
      fi
  else
    echo "This mailbox does not exist."
    exit 1
  fi
}

function full_backup
{
  start_time=$SECONDS
  mkdir -p $backup_folder
  for i in $accounts_list; do
    export backup_target=$i
    mkdir -p $backup_folder/$(date +%Y-%m-%d)
    if [[ $1 == "--force" ]];then
      zmmailbox -z -m $backup_target getRestURL '/?fmt=tgz' >  $backup_folder/$(date +%Y-%m-%d)/$backup_target.tar.gz
    elif [[ -z $1 ]]; then
      check_overwrite
      if [[ $overwrite_yn == "y" ]];then
        zmmailbox -z -m $backup_target getRestURL '/?fmt=tgz' > $backup_folder/$(date +%Y-%m-%d)/$backup_target.tar.gz
        echo "[DONE] $backup_target."
      elif [[ $overwrite_yn == "n" ]];then
        echo "[ABORT] backup aborted for $backup_target."
      else
        echo "[FAILED] Wrong input. Backup aborted for $backup_target."
      fi
    fi
  done
  elapsed_time=$(($SECONDS - $start_time))
  echo "[DONE] Full backup finished in $(($elapsed_time/60)) min $(($elapsed_time%60)) sec."
}

function manual_restore
{
  backup_list=$(ls $backup_folder)
  echo "manual restore - work in progress"
  echo -e "List of existing backups :\n$backup_list"
}

function check_overwrite
{
  if [[ -f $backup_folder/$(date +%Y-%m-%d)/$backup_target.tar.gz ]];then
    echo -n "File $backup_folder/$(date +%Y-%m-%d)/$backup_target.tar.gz already exist. Overwrite ? (y/n) "
    read overwrite_answer
    export overwrite_yn=$overwrite_answer
  else
    export overwrite_yn="y"
  fi
}

### CHECK ARGS // transformer les IF en CASE pour une meilleure lisibilite
if [[ $USER != "$zimbra_user" ]];then
  echo "This script MUST be run as user $zimbra_user."
  exit 1
fi
case $1 in
  -a)
  full_backup
  exit 0
  ;;

  -af)
  full_backup --force
  exit 0
  ;;

  -h)
  print_usage
  exit 0
  ;;

  -m)
  manual_backup $2
  exit 0
  ;;

  -r)
  manual_restore
  ;;

  -v|--version)
  echo "zmbackup-ng - version $version"
  exit 0
  ;;

  *)
  print_usage
  exit 0
  ;;
esac
