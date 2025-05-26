#!/usr/bin/env bash

# again totally not stolen from https://github.com/ErrorNoInternet/rpm-packages/blob/main/update.sh
# thank you!!!!

declare -A anitya_ids=(
    ["legcord/legcord.spec"]=378363
)



for file in "${!anitya_ids[@]}"; do
    name=$(sed -n "s|^Name:\s\+\(.*\)$|\1|p" "$file" | head -1)
    if grep -q "pypi_name" "$file"; then
        pypi_name=$(sed -n "s|^%global\s\+pypi_name\s\+\(.*\)\$|\1|p" "$file")
        name=${name//%\{pypi_name\}/$pypi_name}
    fi
    echo "> querying versions for $name ($file)..."

    if ! api_response=$(curl -fsSL "https://release-monitoring.org/api/v2/versions/?project_id=${anitya_ids[$file]}") ||
        [[ -z "$api_response" ]]; then
        echo -e "couldn't query anitya api for $name! api response: $api_response"
        continue
    fi

    if ! latest_version=$(echo "$api_response" | jq -r .latest_version) || [[ -z "$latest_version" ]]; then
        echo -e "couldn't parse versions for $name! api response: $api_response"
        continue
    fi

    latest_version=${latest_version//-/\~}
    current_version=$(sed -n "s|^Version:\s\+\(.*\)$|\1|p" "$file" | head -1)

    if [[ "$current_version" != "$latest_version" ]]; then
        if (git log -1 --pretty="format:%B" "$file" | grep -qE "^update.sh: override.*$latest_version.*$"); then
            echo "ignoring $latest_version for $name as it has been manually overridden"
            continue
        fi

        echo "$name is not up-to-date ($current_version -> $latest_version)! modifying attributes..."
        sed -i "s|^Version:\(\s\+\)$current_version$|Version:\1$latest_version|" "$file"
        sed -i "s|^Release:\(\s\+\)[0-9]\+%{?dist}|Release:\11%{?dist}|" "$file"

        git add "$file"
        git commit -m "$name: $current_version -> $latest_version"
    fi
done

git pull
git push
