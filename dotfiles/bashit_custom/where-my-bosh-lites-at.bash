#!/bin/bash

# : "${pool_dir:="/${HOME:-/Users/pivotal}/workspace/capi-env-pool/bosh-lites"}"
pool_dir=$HOME/workspace/cli-pools/bosh-lites

pushd $pool_dir >/dev/null
  git pull
popd

PROJECT_ID=2105761

function build_bosh_lite_output {
  file="$( basename "${file}" )"
  author="$(git log --max-count=1 --pretty='format:%an' "${file}")"
  committer="$(git log --max-count=1 --pretty='format:%cn' "${file}")"
  claimed_since="$(git log --max-count=1 --pretty='format:%ar' "${file}")"
  if [ "${author}" != "${committer}" ]; then
    claimed_by="${author}+${committer}"
  else
    claimed_by="${author}"
  fi

  if $(git log --max-count=1 --pretty='format:%s' ${file} | grep -q CI-claim); then
    ci_name=Spikeline
    if $(git log --max-count=1 --pretty='format:%s' ${file} | grep -q CLI-CI-claim); then
      ci_name=Spikecline
    fi

    claimed_by="$ci_name on behalf of $claimed_by"
    workstation=CI
    # Assume the last field is the story ID and extract it.
    story_id="$(git log --max-count=1 --pretty='format:%s' "${file}" | tr -d '#' | awk '{print $NF}')"
    story="pivotaltracker.com/story/show/${story_id}"
    story_state=$(curl -s "https://www.pivotaltracker.com/services/v5/projects/${PROJECT_ID}/stories/${story_id}" | jq -r ."current_state")
    output="${output}${file}\t${claimed_by}\t${workstation}\t${claimed_since}\t${story} (${story_state})\n"
  else
    workstation="$(git log --max-count=1 --pretty='format:%s' "${file}" | sed -E "s/^manually claim [^[:space:]]+ on ([^[:space:]]+).*$/\1/")"
    story='unknown'
    output="${output}${file}\t${claimed_by}\t${workstation}\t${claimed_since}\t${story}\n"
  fi
}

function where_my_bosh_lites_at() {
  # Colors
  local red blue
  red='\033[0;31m'
  blue='\033[0;34m'
  nc='\033[0m'

  echo -e "${blue}Rounding up claimed environments...${nc}"

  pushd "${pool_dir}/claimed" > /dev/null
    stale_claimed_files="$(git log --reverse --name-only --pretty=format: --until="7 days ago" -- * | sort | uniq | xargs)"
    fresh_claimed_files="$(git log --reverse --name-only --pretty=format: --after="7 days ago" -- * | sort | uniq | xargs)"

    output="${blue}\n* ENV *\t* CLAIMED BY *\t* CLAIMED ON *\t* CLAIMED SINCE *\t* STORY (STATUS) *\n"

    output="${output}${red}\n"
    for file in ${stale_claimed_files}; do
      if [[ !$(echo $file | grep -q "${fresh_claimed_files}") ]]; then
        build_bosh_lite_output ${file}
      fi
    done

    output="${output}${nc}\n"
    for file in ${fresh_claimed_files}; do
      build_bosh_lite_output ${file}
    done

  popd > /dev/null
  echo -e "$output" | column -t -s $'\t'
}

export -f where_my_bosh_lites_at

