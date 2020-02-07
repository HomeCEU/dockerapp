#!/usr/bin/env bash
function define_global_vars() {
  CONFIG_FILE="config"
  DIR=$(pwd)
  DOCKER_DIR=.docker
  DOCKER_CONF="$(config_get DOCKER_CONF)"
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
  cpExampleFiles ${DIR}
  cpExampleFiles ${APP_DIR}
  cpExampleFiles ${DOCKER_DIR}
  config_set "${DOCKER_CONF}"/.env HOST_UID ${HOST_UID}
  config_set "${DOCKER_CONF}" APP_CONTAINER ${APP_CONTAINER}
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
    config)
      Config "${@:2}"
      ;;
  esac
}

function Config() {
  case $1 in
    set)
      config_set ${CONFIG_FILE} "${@:2}"
      grep -B 4 -A 2 --color "$2" ${CONFIG_FILE}
      ;;
    *)
      cat ${CONFIG_FILE}
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

  ensureConfigFileExists "${file}"

  # create key if not exists
  if ! grep -q "^${key}=" ${file}; then
    printf "\n${key}=" >> ${file}
  fi

  # set key
  sed -i "s/\(^${key} *= *\).*/\1${val}/" ${DIR}/${file}
}

function ensureConfigFileExists() {
  if [ ! -e "$1" ] ; then
    if [ -e "$1.example" ]; then
      cp "$1.example" "$1";
    else
      touch "$1"
    fi
  fi
}

# https://stackoverflow.com/a/25749716/2683059
function file_ends_with_newline() {
  [[ $(tail -c1 "$1" | wc -l) -gt 0 ]]
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
