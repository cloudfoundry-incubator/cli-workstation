function unclaim_bosh_lite() {

  # ensures we don't remove the current working directory
  if [[ "$PWD" == *capi-env-pool* ]]; then
    cd "$HOME/workspace/capi-env-pool"
  fi
  (
    set -e
    cd ~/workspace/capi-env-pool

    working_pool="bosh-lites"
    broken_pool="bosh-lites-to-be-deleted"

    if [ $# -eq 0 ]; then
      echo "Usage: $0 env_name"
      return 1
    fi

    git pull -r --quiet --no-verify

    function mark_broken {
      env=$1
      file="$(find "${working_pool}" -name "${env}")"

      if [ "$file" == "" ]; then
        echo "$env does not exist in ${working_pool}"
        return 1
      fi

      read -r -p "Hit enter to release ${env} "

      git mv "${file}" "${broken_pool}/unclaimed/"

      echo "Updating the trigger file to run delete boshlite task"
      date +%s > .trigger-bosh-lites-destroy

      git add .trigger-bosh-lites-destroy

      if [ -d "${env}" ]; then
        git rm -rf "${env}" && \rm -rf "${env}"
      fi

      git commit --quiet -m"releasing $env on ${HOSTNAME} [nostory]" --no-verify
      echo "Pushing the release commit to $( basename "$PWD" )..."
      git push --quiet
    }

    for env in "$@"; do
      mark_broken "${env}"
    done
  )

  unset BOSH_CA_CERT BOSH_CLIENT BOSH_CLIENT_SECRET BOSH_ENVIRONMENT \
    BOSH_GW_USER BOSH_GW_HOST BOSH_LITE_DOMAIN BOSH_GW_PRIVATE_KEY_CONTENTS \
    BOSH_GW_PRIVATE_KEY

  echo "Done"
}


_unclaim_bosh_lite_completions() {
  COMPREPLY=($(compgen -W "$(ls ~/workspace/capi-env-pool/bosh-lites/claimed)" "${COMP_WORDS[1]}"))
}

export -f unclaim_bosh_lite
complete -F _unclaim_bosh_lite_completions unclaim_bosh_lite
