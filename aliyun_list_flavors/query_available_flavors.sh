#!/usr/bin/env bash

# Description:
#   Get a list of available flavors.
#
# Dependence:
#   aliyun - CLI tool for Alibaba Cloud
#   jq     - Command-line JSON processor

function show_usage() {
    echo "Get a list of available flavors."
    echo "$(basename $0) <-o OUTPUT_FILE> [-r REGION_LIST]"
}

while getopts :ho:r: ARGS; do
    case $ARGS in
    h)
        # Help option
        show_usage
        exit 0
        ;;
    o)
        # Output file option
        file=$OPTARG
        ;;
    r)
        # Region list option
        regions=$OPTARG
        ;;
    "?")
        echo "$(basename $0): unknown option: $OPTARG" >&2
        ;;
    ":")
        echo "$(basename $0): option requires an argument -- '$OPTARG'" >&2
        echo "Try '$(basename $0) -h' for more information." >&2
        exit 1
        ;;
    *)
        # Unexpected errors
        echo "$(basename $0): unexpected error -- $ARGS" >&2
        echo "Try '$(basename $0) -h' for more information." >&2
        exit 1
        ;;
    esac
done

if [ -z $file ]; then
    show_usage
    exit 1
fi

# Main
: >$file

# Get all regions if not specified
if [ -z "$regions" ]; then
    x=$(aliyun ecs DescribeRegions | jq -r '.Regions.Region[].RegionId')
    [ "$?" != "0" ] && echo $x && exit 1
    regions=$x
fi

# Query flavors in each region
for region in $regions; do
    # Get AvailableResource
    echo -e "\nQuerying available resource in $region ..."
    x=$(aliyun ecs DescribeAvailableResource --RegionId $region \
        --DestinationResource InstanceType)
    if [ "$?" != "0" ]; then
        echo "$(basename $0): warning: aliyun ecs DescribeAvailableResource --RegionId $region" >&2
        echo $x >&2
        continue
    fi

    # Filter eligible AvailableZones
    x=$(echo $x | jq -r ".AvailableZones.AvailableZone[] | \
        select(.StatusCategory==\"WithStock\") | select(.Status==\"Available\")")
    zones=$(echo $x | jq -r '.ZoneId')

    for zone in $zones; do
        # Filter eligible Flavors
        flavors=$(echo $x | jq -r "select(.ZoneId==\"$zone\") | \
            .AvailableResources.AvailableResource[].SupportedResources.SupportedResource[] | \
            select(.Status==\"Available\") | select(.StatusCategory==\"WithStock\") | .Value")

        # Dump results
        for flavor in $flavors; do
            echo "$zone,$flavor" >>$file
        done
    done
done

exit 0
