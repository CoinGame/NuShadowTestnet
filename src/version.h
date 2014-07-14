// Copyright (c) 2014 The Nu developers
// Copyright (c) 2013-2014 The Peershares developers
// Copyright (c) 2012 The Bitcoin developers
// Copyright (c) 2012-2013 The PPCoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.
#ifndef NU_VERSION_H
#define NU_VERSION_H

#include <string>

//
// client versioning
//

// These need to be macro's, as version.cpp's voodoo requires it

// nu version
#define CLIENT_VERSION_MAJOR       0
#define CLIENT_VERSION_MINOR       1
#define CLEINT_VERSION_REVISION    0
#define CLIENT_VERSION_BUILD       0

static const int CLIENT_VERSION =
                           1000000 * NU_VERSION_MAJOR
                         +   10000 * NU_VERSION_MINOR
                         +     100 * NU_VERSION_REVISION
                         +       1 * NU_VERSION_BUILD;

// peercoin version 0.3.0.0 - reference for code tracking

// bitcoin version 0.6.3.0 - reference for code tracking


extern const std::string CLIENT_NAME;
extern const std::string CLIENT_BUILD;
extern const std::string CLIENT_DATE;


//
// network protocol versioning
//

static const int PROTOCOL_VERSION = 60001;

// earlier versions not supported as of Feb 2012, and are disconnected
// NOTE: as of bitcoin v0.6 message serialization (vSend, vRecv) still
// uses MIN_PROTO_VERSION(209), where message format uses PROTOCOL_VERSION
static const int MIN_PROTO_VERSION = 209;

// nTime field added to CAddress, starting with this version;
// if possible, avoid requesting addresses nodes older than this
static const int CADDR_TIME_VERSION = 31402;

// only request blocks from nodes outside this range of versions
static const int NOBLKS_VERSION_START = 32000;
static const int NOBLKS_VERSION_END = 32400;

// BIP 0031, pong message, is enabled for all versions AFTER this one
static const int BIP0031_VERSION = 60000;

#endif
