#!/bin/sh

# Copyright (C) 2021 Free Software Foundation, Inc.
# Copyright (C) 2024 Red Hat, Inc.
#
# Author: Daniel Kahn Gillmor, Daiki Ueno
#
# This file is part of GnuTLS.
#
# GnuTLS is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 3 of the License, or (at
# your option) any later version.
#
# GnuTLS is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GnuTLS.  If not, see <https://www.gnu.org/licenses/>.

#set -e

: ${srcdir=.}
: ${CLI=../../src/gnutls-cli${EXEEXT}}
: ${CERTTOOL=../../src/certtool${EXEEXT}}

. "${srcdir}/../scripts/common.sh"
testdir=`create_testdir mldsa`

if ! test -x "${CERTTOOL}"; then
	exit 77
fi

if ! test -x "${CLI}"; then
	exit 77
fi

for variant in 44 65 87; do
    echo "Testing ML-DSA-$variant"

    if ! "${CLI}" --list | grep "^Public Key Systems: .*ML-DSA-$variant.*" >/dev/null; then
	continue
    fi
    algo=mldsa$variant

    TMPFILE=$testdir/$algo-crfg-kx
    TMPCA=$testdir/$algo-mldsa-ca
    TMPCAKEY=$testdir/$algo-mldsa-ca-key
    TMPSUBCA=$testdir/$algo-mldsa-subca
    TMPSUBCAKEY=$testdir/$algo-mldsa-subca-key
    TMPKEY=$testdir/$algo-kx-key
    TMPTEMPL=$testdir/$algo-template
    TMPUSER=$testdir/$algo-user
    VERIFYOUT=$testdir/$algo-verify

    echo ca > $TMPTEMPL
    echo "cn = $algo CA" >> $TMPTEMPL

    "${CERTTOOL}" --generate-privkey --key-type=$algo > $TMPCAKEY 2>/dev/null

    "${CERTTOOL}" -d 2 --generate-self-signed --template $TMPTEMPL \
	          --load-privkey $TMPCAKEY \
	          --outfile $TMPCA >$TMPFILE 2>&1

    if [ $? != 0 ]; then
	cat $TMPFILE
	exit 1
    fi

    echo ca > $TMPTEMPL
    echo "cn = $algo Mid CA" >> $TMPTEMPL

    "${CERTTOOL}" --generate-privkey --key-type=$algo > $TMPSUBCAKEY 2>/dev/null

    "${CERTTOOL}" -d 2 --generate-certificate --template $TMPTEMPL \
	          --load-ca-privkey $TMPCAKEY \
	          --load-ca-certificate $TMPCA \
	          --load-privkey $TMPSUBCAKEY \
	          --outfile $TMPSUBCA >$TMPFILE 2>&1

    if [ $? != 0 ]; then
	cat $TMPFILE
	exit 1
    fi

    echo "cn = End-user" > $TMPTEMPL
    echo email_protection_key >> $TMPTEMPL
    echo encryption_key >> $TMPTEMPL

    "${CERTTOOL}" --generate-privkey --key-type=$algo > $TMPKEY 2>/dev/null

    "${CERTTOOL}" -d 2 --generate-certificate --template $TMPTEMPL \
	          --load-ca-privkey $TMPSUBCAKEY \
	          --load-ca-certificate $TMPSUBCA \
	          --load-privkey $TMPKEY \
	          --outfile $TMPUSER >$TMPFILE 2>&1

    if [ $? != 0 ]; then
	cat $TMPFILE
	exit 1
    fi

    cat $TMPUSER $TMPSUBCA $TMPCA > $TMPFILE
    "${CERTTOOL}" --verify-chain <$TMPFILE > $VERIFYOUT

    if [ $? != 0 ]; then
	cat $VERIFYOUT
	exit 1
    fi

done

rm -rf "${testdir}"

exit 0