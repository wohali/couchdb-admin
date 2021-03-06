#!/bin/sh -e

# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

if test -n "$1"; then
    branch=$1
else
    echo "error: no branch"
    exit 1
fi

if test -n "$2"; then
    version=$2
else
    echo "error: no version"
    exit 1
fi

log () {
    printf "\033[1;31m$1\033[0m\n"
}

cd `dirname $0`

basename=`basename $0`

if test -n "$3"; then
    tmp_dir=$3
else
    log "Creating temporary directory..."
    tmp_dir=`mktemp -d /tmp/$basename.XXXXXX` || exit 1
    echo $tmp_dir
fi

diff_file=$tmp_dir/diff.txt

cat > $diff_file <<EOF
^Only in $tmp_dir/$branch: .gitignore\$
^Only in $tmp_dir/$branch: .mailmap\$
^Only in $tmp_dir/$branch: .travis.yml\$
^Only in $tmp_dir/$branch: acinclude.m4.in\$
^Only in $tmp_dir/$branch: bootstrap\$
^Only in $tmp_dir/$branch: THANKS.in\$
^Only in $tmp_dir/$branch: Vagrantfile\$
^Only in $tmp_dir/$branch/m4: ac_check_curl.m4.gz\$
^Only in $tmp_dir/$branch/m4: ac_check_icu.m4.gz\$
^Only in $tmp_dir/$branch/m4: pkg.m4.gz\$
^Only in $tmp_dir/apache-couchdb-$version: acinclude.m4\$
^Only in $tmp_dir/apache-couchdb-$version: aclocal.m4\$
^Only in $tmp_dir/apache-couchdb-$version: build-aux\$
^Only in $tmp_dir/apache-couchdb-$version: config.h.in\$
^Only in $tmp_dir/apache-couchdb-$version: configure\$
^Only in $tmp_dir/apache-couchdb-$version: INSTALL\$
^Only in $tmp_dir/apache-couchdb-$version: m4\$
^Only in $tmp_dir/apache-couchdb-$version: Makefile.in\$
^Only in $tmp_dir/apache-couchdb-$version: THANKS\$
^Only in $tmp_dir/apache-couchdb-$version/.*: Makefile.in\$
^Only in $tmp_dir/apache-couchdb-$version/bin: couchdb.1\$
^Only in $tmp_dir/apache-couchdb-$version/build-aux: compile\$
^Only in $tmp_dir/apache-couchdb-$version/build-aux: config.guess\$
^Only in $tmp_dir/apache-couchdb-$version/build-aux: config.sub\$
^Only in $tmp_dir/apache-couchdb-$version/build-aux: depcomp\$
^Only in $tmp_dir/apache-couchdb-$version/build-aux: install-sh\$
^Only in $tmp_dir/apache-couchdb-$version/build-aux: ltmain.sh\$
^Only in $tmp_dir/apache-couchdb-$version/build-aux: missing\$
^Only in $tmp_dir/apache-couchdb-$version/m4: ac_check_curl.m4\$
^Only in $tmp_dir/apache-couchdb-$version/m4: ac_check_icu.m4\$
^Only in $tmp_dir/apache-couchdb-$version/m4: libtool.m4\$
^Only in $tmp_dir/apache-couchdb-$version/m4: lt~obsolete.m4\$
^Only in $tmp_dir/apache-couchdb-$version/m4: ltoptions.m4\$
^Only in $tmp_dir/apache-couchdb-$version/m4: ltsugar.m4\$
^Only in $tmp_dir/apache-couchdb-$version/m4: ltversion.m4\$
^Only in $tmp_dir/apache-couchdb-$version/m4: pkg.m4\$
^Only in $tmp_dir/apache-couchdb-$version/share/doc/build: html\$
^Only in $tmp_dir/apache-couchdb-$version/share/doc/build: latex\$
^Only in $tmp_dir/apache-couchdb-$version/share/doc/build: texinfo\$
^Only in $tmp_dir/apache-couchdb-$version/src/couchdb/priv: couchjs.1\$
EOF

build_file=$tmp_dir/build.mk

cat > $build_file <<EOF
GIR_URL=https://git-wip-us.apache.org/repos/asf/couchdb.git

TMP_DIR=$tmp_dir

GIT_DIR=\$(TMP_DIR)/git

DIFF_FILE=$diff_file

BRANCH=$branch

VERSION=$version

PACKAGE=apache-couchdb-\$(VERSION)

GIT_FILE=\$(GIT_DIR)/\$(PACKAGE).tar.gz

TMP_FILE=\$(TMP_DIR)/\$(PACKAGE).tar.gz

all: \$(TMP_DIR)/\$(PACKAGE).tar.gz

\$(TMP_FILE): \$(TMP_FILE).ish
	cd \$(GIT_DIR) && \
	    ./bootstrap
	cd \$(GIT_DIR) && \
	    ./configure --enable-strictness --disable-tests
	cd \$(GIT_DIR) && \
	    DISTCHECK_CONFIGURE_FLAGS="--disable-tests" make -j distcheck
	mv \$(GIT_FILE) \$(TMP_FILE)

\$(TMP_FILE).ish: \$(GIT_DIR)
	cd \$(GIT_DIR) && git show HEAD | head -n 1 | cut -d " " -f 2 > \$@

\$(GIT_DIR):
	git clone \$(GIR_URL) \$@
	cd \$(GIT_DIR) && git checkout -b \$(BRANCH) origin/\$(BRANCH)

check: check-files

check-files: check-diff
	cd \$(TMP_DIR)/\$(PACKAGE) && \
	    grep "not released" share/doc/src/whatsnew/*.rst; test "\$\$?" -eq 1
	cd \$(TMP_DIR)/\$(PACKAGE) && \
	    grep "build" acinclude.m4; test "\$\$?" -eq 1
	cd \$(TMP_DIR)/\$(PACKAGE) && \
	    grep `date +%Y` NOTICE

check-diff: check-file-size
	cd \$(GIT_DIR) && git archive \
	    --prefix=\$(BRANCH)/ -o ../\$(BRANCH).tar \
	    \`cat \$(TMP_FILE).ish\`
	cd \$(TMP_DIR) && tar -xf \$(TMP_DIR)/\$(BRANCH).tar
	cd \$(TMP_DIR) && tar -xzf \$(TMP_FILE)
	diff -r \$(TMP_DIR)/\$(PACKAGE) \$(TMP_DIR)/\$(BRANCH) \
	    | grep --include= -vEf \$(DIFF_FILE); \
	    test "\$\$?" -eq 1

check-file-size:
	test -s \$(TMP_FILE)
	test -s \$(TMP_FILE).ish
EOF

log_file=$tmp_dir/log.txt

echo "Build started `date`" > $log_file

log "Executing build instructions..."

make -f $build_file | tee -a $log_file

time_finish=`date "+%s"`

echo "Build finished `date`" >> $log_file

log "Checking build..."

make -f $build_file check

log "Check complete..."

echo "Files in: $tmp_dir"
