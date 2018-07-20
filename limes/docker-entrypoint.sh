#!/bin/bash -x

set -e

JAVA_OPTS="-Xms128m"

if [ -z "${CONFIG_FILE}" ]; then
    echo "Cannot find configuration file (specify CONFIG_FILE in environment)!" 1>&2
    exit 1
fi

#
# Build a custom configuration file based on environment variables and given configuration file
#

config_file=$(mktemp -p /var/local/limes -t config-XXXXXXX.xml)
cp ${CONFIG_FILE} ${config_file}

#
# Determine output format/extension
#

output_format=$(cat ${config_file}| xmlstarlet fo --dropdtd| xmlstarlet sel -t --value-of LIMES/OUTPUT)
output_extension=
case ${output_format} in
NT|N-TRIPLES|N_TRIPLES|nt)
  output_extension="nt"
  ;;
TTL|ttl)
  output_extension="ttl"
  ;;
N3|n3|Notation3)
  output_extension="n3"
  ;;
*)
  output_extension="nt"
  ;;
esac

#
# Edit configuration file according to environment
#

if [ -d "${OUTPUT_DIR}" ]; then
    output_dir="${OUTPUT_DIR%%/}"
    xmlstarlet ed --inplace --update LIMES/ACCEPTANCE/FILE -v "${output_dir}/${ACCEPTED_NAME}.${output_extension}" ${config_file}
    xmlstarlet ed --inplace --update LIMES/REVIEW/FILE -v "${output_dir}/${REVIEW_NAME}.${output_extension}" ${config_file}
fi

if [ -n "${SOURCE_FILE}" ]; then
    xmlstarlet ed --inplace --update LIMES/SOURCE/ENDPOINT -v ${SOURCE_FILE} ${config_file}
fi

if [ -n "${TARGET_FILE}" ]; then
    xmlstarlet ed --inplace --update LIMES/TARGET/ENDPOINT -v ${TARGET_FILE} ${config_file}
fi

#
# Run command
#

MAX_MEMORY_SIZE=$(( 64 * 1024 * 1024 * 1024 ))

memory_size=$(cat /sys/fs/cgroup/memory/memory.memsw.limit_in_bytes)
if (( memory_size > 0 && memory_size < MAX_MEMORY_SIZE )); then
    max_heap_size=$(( memory_size * 80 / 100 ))
    JAVA_OPTS="${JAVA_OPTS} -Xmx$(( max_heap_size / 1024 / 1024 ))m"
fi

exec java ${JAVA_OPTS} -jar limes-standalone.jar ${config_file}
