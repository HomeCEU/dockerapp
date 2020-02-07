#!/usr/bin/env bash
function define_global_vars() {
  CONFIG_FILE="config"
  DIR=$(pwd)
  DOCKER_DIR=.docker
  APP_DIR="$(config_get APP_DIR)"
  APP_CONTAINER="$(config_get APP_CONTAINER)"
  HOST_UID=$(id -u);
  HOST_GID=$(id -g);
}

function Help() {
  cat << EOF
Usage: app.sh COMMAND

Commands:
  help|--help     Display this help
  init            clone application,
                  composer install,
                  cp (.+).example $1
                 
  composer        execute any composer command on the app

  exec            execute command as user in container

Initial Setup:
  app.sh init    
EOF
  exit 0;
}

function Composer() {
  local cmd=$1;
  local args="${@:2} --ignore-platform-reqs";
  if [ ${cmd} = "install" ]; then
    args="${args} --no-suggest --prefer-dist";
  fi
  echo "composer ${cmd} ${args}";
  echo "docker run --rm -v \"${DIR}/${APP_DIR}\":/app --user ${HOST_UID}:${HOST_GID} composer:1.8 $cmd $args"
  docker run --rm -v "${DIR}/${APP_DIR}":/app --user ${HOST_UID}:${HOST_GID} composer:1.8 $cmd $args
}

function Init() {
  if [ ! -d "${APP_DIR}" ]; then
    git clone --branch $(config_get GIT_BRANCH) $(config_get GIT_REPO) ${APP_DIR}
  fi
  cpExampleFiles ${APP_DIR}
  cpExampleFiles ${DOCKER_DIR}
  config_set "${DOCKER_DIR}"/.env HOST_UID ${HOST_UID}
  Composer install
}


function Exec() {
  # echo "docker exec --user ${HOST_UID}:${HOST_GID} ${APP_CONTAINER} sh -c \"cd /var/www/html/ && ${@:1}\""
  docker exec --user ${HOST_UID}:${HOST_GID} ${APP_CONTAINER} sh -c "cd /var/www/html/ && ${@:1}";
}

function route() {
  case $1 in
    -h|--help|help)
      Help
      ;;
    composer)
      Composer "${@:2}"
      ;;
    init)
      Init
      ;;
    exec)
      Exec "${@:2}"
      ;;
  esac
}

# cpExampleFiles path
# will copy each .example file removing the .example without overwriting
# Given ./ contains foo.env.example, bar.env.example, bar.env
# When cpExampleFiles ./
# Then ./ contains fpp.env.example, bar.env.example, bar.env, foo.env
# it will not copy bar.env.example because bar.env exists already
function cpExampleFiles() {
  local dir=$(echo "$1" | sed 's:/*$::') # remove trailing slashes
  local newfile
  shopt -s dotglob;
  for f in "$dir"/*.example; do
    if [[ "$f" != *\*.example ]]; then     # so if there are no files it errors, this prevents that error..
      newfile=${f%%.example}
      if [ ! -f "${newfile}" ]; then
        echo "cp \"$f\" \"${newfile}\""
        cp "$f" "${newfile}";
      fi
    fi
  done
}

# https://stackoverflow.com/a/2464883
# Usage: config_set filename key value
function config_set() {
  local file=$1
  local key=$2
  local val=${@:3}

  # create file if not exists
  if [ ! -e "${file}" ] ; then
    touch ${file}
  fi

  # create key if not exists
  if ! grep -q "^${key}=" ${file}; then
    echo "${key}=" >> ${file}
  fi

  # set key
  sed -i "s/\(^${key} *= *\).*/\1${val}/" ${DIR}/${file}
}

# https://unix.stackexchange.com/a/331965/312709
# Usage: local myvar="$(config_get myvar)"
function config_get() {
    val="$(config_read_file ${CONFIG_FILE} "${1}")";
    if [ "${val}" = "__UNDEFINED__" ]; then
        val="$(config_read_file ${CONFIG_FILE}.example "${1}")";
    fi
    printf -- "%s" "${val}";
}
function config_read_file() {
    (grep -E "^${2}=" -m 1 "${1}" 2>/dev/null || echo "VAR=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2-;
}

function main() {
    define_global_vars
    route "$@"
}

main "$@"
