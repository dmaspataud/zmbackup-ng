#!/bin/bash

### VARIABLES
zimbra_user="zimbra"
version="0.3b"
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
  users_backups_list=$(ls $backup_folder/*/ | grep -v "$(ls $backup_folder)" | sed -e "s/.tar.gz//g" | sort | uniq)
  backup_list=$(ls $backup_folder)
  echo -e "Choose which account you need to restore : $users_backups_list"
  echo -n "> "
  read user_choice
    if [[ " $users_backups_list " =~ $user_choice ]];then
      date_backup_list=$(ls $backup_folder/*/$user_choice.tar.gz | sed -e "s/\\$backup_folder\///g" | sed -e "s/\/$user_choice.tar.gz//g" | sort)
      echo -e "\nBackups for user $user_choice exist at the following dates :\n $date_backup_list\n"
      echo -e "Please select a date to restore the backup from (YYYY-MM-DD) :"
      echo -n "> "
      read date_choice
      if [[ " $date_backup_list " =~ $date_choice ]];then
        echo -e "\nThe following restorations are available, please select the one that suits your needs (modify/skip/reset): \n"
        echo "Modify : restore deleted items, and reset existing mail to backup status (Unread/Read flags will be applied)"
        echo "Skip : Only restore deleted items."
        echo "Reset : [CAUTION] replace the mailbox with the content of the backup. ITEMS WILL BE LOST !"
        echo -n "> "
        read type_choice
        case $type_choice in
          modify)
          start_time=$SECONDS
          zmmailbox -z -m $user_choice postRestURL "/?fmt=tgz&resolve=modify" $backup_folder/$date_choice/$user_choice.tar.gz
          elapsed_time=$(($SECONDS - $start_time))
          echo -e "\n[DONE] Restoration of $user_choice's mailbox finished in $elapsed_time."
          exit 0
          ;;
          skip)
          start_time=$SECONDS
          zmmailbox -z -m $user_choice postRestURL "/?fmt=tgz&resolve=skip" $backup_folder/$date_choice/$user_choice.tar.gz
          elapsed_time=$(($SECONDS - $start_time))
          echo -e "\n[DONE] Restoration of $user_choice's mailbox finished in $elapsed_time."
          exit 0
          ;;
          reset)
          start_time=$SECONDS
          zmmailbox -z -m $user_choice postRestURL "/?fmt=tgz&resolve=reset" $backup_folder/$date_choice/$user_choice.tar.gz
          elapsed_time=$(($SECONDS - $start_time))
          echo -e "\n[DONE] Restoration of $user_choice's mailbox finished in $(($elapsed_time/60)) min $(($elapsed_time%60)) sec."
          exit 0
          ;;
          *)
          echo "[FAILED] Wrong restoration type."
          exit 1
          ;;
        esac
      else
        echo "[FAILED] No backups for user $user_choice for the date $date_choice."
        exit 1
      fi
    else
      echo "[FAILED] No backups for user $user_choice."
      exit 1
    fi
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
