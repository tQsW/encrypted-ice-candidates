---
title: Encrypted ICE Candidates with Pre-Shared Key Cipher Suites
docname: draft-ietf-mmusic-encrypted-ice-candidates-latest
abbrev: mdns-ice-candidates
category: info

ipr: trust200902
area: General
workgroup: MMUSIC
keyword: Internet-Draft

stand_alone: yes
pi: [toc, sortrefs, symrefs]

author:
 -
    ins: A. Drake
    name: Alex Drake
    organization: Google
    email: alexdrake@google.com
 -
    ins: J. Uberti
    name: Justin Uberti
    organization: Google
    email: juberti@google.com
 -
    ins: Q. Wang
    name: Qingsi Wang
    organization: Google
    email: qingsi@google.com

normative:
  RFC6052
  RFC8445:
informative:
  ICESDP:
    target: https://tools.ietf.org/html/draft-ietf-mmusic-ice-sip-sdp
    title: Session Description Protocol (SDP) Offer/Answer procedures for
           Interactive Connectivity Establishment (ICE)
    author:
      ins: M. Petit-Huguenin
      ins: S. Nandakumar
      ins: A. Keranen
    date: 2018-04-01
  IPHandling:
    target: https://tools.ietf.org/html/draft-ietf-rtcweb-ip-handling
    title:  WebRTC IP Address Handling Requirements
    author:
      ins: J. Uberti
      ins: G. Shieh
    date: 2018-04-18
  MdnsCandidate:
    target: https://tools.ietf.org/html/draft-ietf-rtcweb-mdns-ice-candidates
    title: Using Multicast DNS to protect privacy when exposing ICE candidates
    author:
      ins: Y. Fablet
      ins: J. de Borst
      ins: J. Uberti
      ins: Q. Wang
    date: 2019-10-16
  Overview:
    target: https://tools.ietf.org/html/draft-ietf-rtcweb-overview
    title: "Overview: Real Time Protocols for Browser-based Applications"
    author:
      ins: H. Alvestrand
    date: 2017-11-12

--- abstract

This document describes a way to share local IP addresses with other clients
without compromising client privacy via pre-shared key cipher suites. A local IP
address is encrypted and authenticated in the connection-address field of an ICE
candidate, and is presented as a hostname with the ".encrypted" pseudo-top-level
domain.

--- middle

Introduction {#problems}
============

The technique detailed in {{MdnsCandidate}} provides a method to share local IP
addresses with other clients without exposing client private IP to applications.
With the possibility of application-controlled signaling servers,
STUN/TURN servers, and even the remote peer implementation, the locality of the
out-of-band mDNS signaling can be considered as the source of trust between
peers in general to share local IPs. However, link-local mDNS messages often
fail to traverse subnets, and this can lead to failure of mDNS name resolution,
which further hinders direct peer-to-peer connections between clients.

This document proposes an complementary solution in managed networks to share
local IP addresses without compromising the client privacy. Specifically,
addresses are encrypted with pre-shared key (PSK) cipher suites, and encoded as
hostnames with the ".encrypted" pseudo-top-level-domain (pseudo-TLD).

WebRTC and WebRTC-compatible endpoints {{Overview}} that receive ICE
candidates with encrypted addresses will authenticate these hostnames in
ciphertext, decrypt them to IP addresses, and perform ICE processing as usual.
In the case where the endpoint is a web application, the WebRTC implementation
will manage this process internally and will not disclose the IP addresses in
plaintext to the application.

Terminology
===========

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in {{RFC2119}}.

Description {#description}
======================

This section uses the concept of ICE agent as defined in {{RFC8445}}.

Pre-Shared Key Cipher Suite {#ciphersuite}
------------------------------------------

ICE agents that implement this proposal pre-share keys for ciphersuites
based on symmetric-key algorithms. The mechanism of sharing such information
is outside the scope of this document. The implementation MUST support the
Advanced Encryption Standard (AES) algorithm and its operation in the CTR, CBC
or GCM mode with message authentication, and SHOULD use the GCM mode whenever it
is supported. The implementation MUST pre-determine a single mode to use as part of
the mechanism to share the information about the cipher suite. When using the
CTR or CBC mode, HMAC with SHA-256 MUST be supported. 

Since the plaintext to encrypt consists of only a single IPv4 or IPv6 address
that fits in a single 128-bit block, the initialization parameter for each mode
can be a cryptographically random number. In particular, this parameter is given
by a 16-byte initial counter block value for CTR, or a 16-byte or 12-byte
initialization vector for CBC or GCM, respectively.

Note the ICE password associated with an ICE agent has at least 128-bit
randomness as defined by {{RFC8445}}. To reduce the overhead in the candidate
encoding that will be detailed in the next section, the initialization paramter
MUST be chosen as the first 16 bytes or 12 bytes in the network order for the
mode in use.

ICE Candidate Gathering {#gathering}
------------------------------------

This section outlines how a pre-shared key (PSK) cipher suite should be used by ICE
agents to conceal local IP addresses.

### Procedure

For each host candidate gathered by an ICE agent as part of the gathering
process described in {{RFC8445}}, Section 5.1.1, the candidate is handled as
described below.

1. Check whether the IP address satisfies the ICE agent’s policy regarding
   whether an address is safe to expose. If so, expose the candidate and abort
   this process.

2. Let *address* be the IP address of the candidate, and embed it as an IPv6
   address if it is an IPv4 address using the "Well-Known Prefix" as described
   in RFC6095. Let *ciphersuite* be the pre-determined cipher suite and its
   initialization parameter, and *key* the PSK. Let
   *EncryptAndAuthenticate(plaintext, ciphersuite, key)* be an operation using
   the given cipher suite to encrypt a given plaintext with authentication, and
   returns concatenated ciphertext and message authentication code (MAC).
   Compute *encrypted_address* as the output of
   EncryptAndAuthenticate(address, algorithm, key).

3. Encode encrypted_address to a hex string, and generate the pseudo-FQDN
   *encrypted_address.encrypted* with the pseudo-TLD *.encrypted*. Replace the
   IP address of the ICE candidate with the pseudo-FQDN, and provide the
   candidate to the application.

### Example

The candidate attribute in the SDP messages to exchange the encrypted candiate
following the abov procedure can be given by

  candidate:1 1 udp 2122262783
  8c9bd03bb7a5a76a5803eebc688f0388fa991acbdf116f6b72fd3a781174cd58.encrypted
  56622 typ host

ICE Candidate Processing {#processing}
-------------------------------------

This section outlines how received ICE candidates with mDNS names are
processed by ICE agents, and is relevant to all endpoints.

### Procedure

For any remote ICE candidate received by the ICE agent, the following procedure
is used:

1. If the connection-address field value of the ICE candidate does not end with
   ".encrypted" or contains more than one ".", then process the candidate as
   defined in {{RFC8445}} or {{MdnsCandidate}}.

2. If the ICE agent has no PSK cipher suite for encrypted candidates,
   proceed to step 5.

3. Let *AuthenticateAndDecrypt(ciphertext_and_mac, ciphersuite, key)* be an
   operation using the given cipher suite to authenticate and decrypt a given
   ciphertext with MAC, and returns the decrypted value upon success, or an
   fail-to-decrypt (FTD) error otherwise. Let *encrypted_address* be the value of the
   connection-address field after removing the trailing ".encrypted". Upon
   success, let *decrypted_address* be given by
   AuthenticateAndDecrypte(encrypted_address). If decrypted_address does not
   represent a valid IPv6 address or an embedded IPv4 address, proceed to step 5.
   Convert decrypted_address to an IPv4 address if it is embedded.

4. Replace the connection-address field of the ICE candidate with
   *decrypted_address*, skip the rest steps and continue processing of the
   candidate as described in {{RFC8445}}.

5. When there is no suitable PSK cipher suite to process an encrypted candidate
   or an FTD error is raised in step 3, discard the candidate, or proceed to
   step 6 if the ICE agent implements {{MdnsCandidate}}.

6. Let *encrypted_address* be the same value defined in step 3, construct an mDNS
   name given by *encrypted_address.local*, and proceed with setp 2 in Section
   3.2.1 in {{MdnsCandidate}}.

ICE agents can implement this procedure in any way as long as it produces
equivalent results.

Security Considerations {#security}
=======================

mDNS Message Flooding via Fallback Resolution
--------------------------------------------

Encrypted candidates can be spoofed and signaled to an ICE agent to trigger the
fallback mDNS resolution as in step 6 in {{processing}}. Note however that the
implementation of {{MdnsCandidate}} is required to have a proper rate
limiting scheme of mDNS messages.


IANA Considerations
===================

This document requires no actions from IANA.
