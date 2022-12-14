#!/bin/sh -l

function is_in_remote() {
    local branch=${1}
    local existed_in_remote=$(git ls-remote --heads origin ${branch})

    if [[ -z ${existed_in_remote} ]]; then
        echo "-- Conan Cache: ${branch} is NOT in remote"
        return 0
    else
        echo "-- Conan Cache: ${branch} is in remote"
        return 1
    fi
}

INPUT_TARGET_OS=${INPUT_TARGET_OS:-$RUNNER_OS}
REPO_BRANCH=main

echo "-- Conan Cache: $GITHUB_EVENT_NAME : Commit by $GITHUB_ACTOR with SHA $GITHUB_SHA on $GITHUB_REF"
echo "-- Conan Cache: Using cache $INPUT_CACHE_NAME"

# Make sure path exists and change dir to it
mkdir -p $CONAN_USER_HOME
cd $CONAN_USER_HOME

# Check out cache
echo "-- Conan Cache: Checking out at CONAN_USER_HOME: $CONAN_USER_HOME"
git clone https://${INPUT_BOT_NAME}:${INPUT_BOT_TOKEN}@github.com/${INPUT_CACHE_NAME}.git ${CONAN_USER_HOME} --branch=main

echo "-- Conan Cache: Enable long paths"
git config --global core.longpaths true

hit_cache=0
echo "-- Conan Cache: Setting preliminary cache-hit $hit_cache"
echo "::set-output name=cache-hit::$hit_cache"

# Check if explicit key exits
echo "-- Conan Cache: Trying explicit key $INPUT_KEY"
if [ $(git tag --list "$INPUT_KEY") ]; then
    # If it does - check out explicit and set cache_hit to 1
    git checkout ${INPUT_KEY} || exit 1
    echo "-- Conan Cache: replace CONAN_USER_HOME_SHORT with ${CONAN_USER_HOME_SHORT}"
    find .conan/ -name .conan_link -exec perl -pi -e 's=CONAN_USER_HOME_SHORT=$ENV{CONAN_USER_HOME_SHORT}=g' {} +
    hit_cache=1
else
    # If it doesn't check if fallback exits
    FALLBACK_KEY="host-${RUNNER_OS}-target-${INPUT_TARGET_OS}-${REPO_BRANCH}"
    echo "-- Conan Cache: Trying fallback key $FALLBACK_KEY"

    is_in_remote ${FALLBACK_KEY}
    
    res=$?
    
    echo "-- Conan Cache: is_in_remote returned $res"

    if [ $res -eq 1 ]; then
        # If it does - check out fallback and set cache_hit to 2
        echo "-- Conan Cache: Check out fallback key $FALLBACK_KEY"
        git checkout ${FALLBACK_KEY} || exit 1
        git pull || exit 1
        git lfs pull || exit 1
        echo "-- Conan Cache: replace CONAN_USER_HOME_SHORT with ${CONAN_USER_HOME_SHORT}"
        find .conan/ -name .conan_link -exec perl -pi -e 's=CONAN_USER_HOME_SHORT=$ENV{CONAN_USER_HOME_SHORT}=g' {} +
        hit_cache=2
    else
        # If it doesn't - create the branch and set cache_hit to 0
        echo "-- Conan Cache: Creating fallback key $FALLBACK_KEY"
        git checkout -b ${FALLBACK_KEY} || exit 1
        git push -u origin ${FALLBACK_KEY} || exit 1
        hit_cache=0
    fi
fi

echo "-- Conan Cache: Setting cache-hit $hit_cache"
echo "::set-output name=cache-hit::$hit_cache"
