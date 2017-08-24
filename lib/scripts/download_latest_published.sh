#!/bin/sh
usage() { echo "Usage: $0 -u <user> -h <host> -f <folder> -a <app>" 1>&2; exit 1; }

while getopts ":u:h:f:a:" o; do
  case "${o}" in
    u)
      USER=${OPTARG}
      ;;
    h)
      HOST=${OPTARG}
      ;;
    f)
      FOLDER=${OPTARG}
      ;;
    a)
      APP=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [ -z "${USER}" ] || [ -z "${HOST}" ] || [ -z "${FOLDER}" ] || [ -z "${APP}" ]; then
  usage
fi

scp $USER@$HOST:$FOLDER/latest /tmp/$APP.tar.gz
