#! /bin/sh
#
#  usage:  simp_packer_test.sh <fully-qualified path to test directory>
#  The test directory should contain 3 files:
#    vars.json:  json file created when the iso is made.  This points
#                to the iso file the output directory and the checksum
#                for the iso.  Make sure these are all set correctly.
#    packer.yaml  YAML containing the settings for the rest of the script
#                 and will be used to configure the simp.json
#                 file.  Examples are given in the sample directory.
#    simp_conf.yaml:  YAML generated by simp_cli.  My script will over
#                 write things in simp_conf.yaml from settings
#                 in the packer.yaml file.  See the samples/README for
#                 more information.
#
#  TMPDIR:   When running this script make sure you set the linux
#            environment variable TMPDIR to point to a directory
#            that is writeable and has enough space for packer to
#            create the disk for the machine.
#
#  Example usage   TMPDIR=/var/tmp ./simp_packer_test.sh /var/jmg/packer/nofips
#
#  Where I have copied the sample directory nofips to /var/jmg/packer and
#  have edited the packer and vars files to point to my iso.  I also
#  have already set up in VirtualBox the HOST ONLY network refered to in
#  the packer.yaml file, or changed the network and IP addresses in the
#  packer.yaml file to reference a VirtualBox network I have already setup.
#
#

cleanup() {
  exitcode=${1:0}

  # shellcheck disable=SC2164
  cd "${TESTDIR}"

  case "${SIMP_PACKER_save_WORKINGDIR:-no}" in
    yes)
      ;;
    *)
       rm -rf "${WORKINGDIR}"
      ;;
  esac

  exit "${exitcode}"
}

# BASEDIR should be the simp-packer directory where this executable is.
# TESTDIR should be the directory where the test files exist.  It
# should be writable. The working directory will be (re-)created under here.
# The working directory will be removed when finished so don't put output there.
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in.
BASEDIR=$(dirname "${SCRIPT}")
TESTDIR=$(ruby -e "print File.expand_path('${1}')")
DATE=$(date +%y%m%d%H%M%S)

if [[ ! -d "${TESTDIR}" ]]; then
  echo "${TESTDIR} not found"
  exit -1
fi

WORKINGDIR="${TESTDIR}/working.${DATE}"
logfile="${TESTDIR}/${DATE}.$(basename "$0").log"
if [ -d "${WORKINGDIR}" ]; then
   rm -rf "./${WORKINGDIR}"
fi
mkdir "${WORKINGDIR}"

if [ ! -f "${TESTDIR}/packer.yaml" ]; then
  echo "${TESTDIR}/packer.yaml not found"
  cleanup -1
fi

if [ ! -f "${TESTDIR}/simp_conf.yaml" ]; then
  echo "${TESTDIR}/simp_conf.yaml  not found"
  cleanup -1
fi

if [ ! -f "${TESTDIR}/vars.json" ]; then
  echo "${TESTDIR}/vars.json Not found"
  cleanup -1
fi

for dir in "files" "puppet" "scripts"; do
   if [ -d "${BASEDIR}/${dir}" ]; then
     cp -Rp "${BASEDIR}/${dir}" "${WORKINGDIR}/"
  fi
done

# shellcheck disable=SC2164
cd "${WORKINGDIR}"

# Update config files with packer.yaml setting and copy to working dir
"${BASEDIR}"/simp_config.rb "${WORKINGDIR}" "${TESTDIR}"

#If you use debug you must set header to true or you won't see the debug.
echo "Logs will be written to ${logfile}"

set -x
# shellcheck disable=SC2086
PACKER_LOG="${PACKER_LOG:-1}" \
  PACKER_LOGPATH="${PACKER_LOGPATH:-/tmp/packer.log.$DATE}" \
  packer build -var-file="${WORKINGDIR}/vars.json" ${EXTRA_SIMP_PACKER_ARGS} "${WORKINGDIR}/simp.json" \
  |& tee "${logfile}"
set +x

# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
  mv "${logfile}" "${logfile}.errors"
  echo "ERROR: packer build failed. Check ${logfile}.errors"
  cleanup -1
else
  cleanup 0
fi
