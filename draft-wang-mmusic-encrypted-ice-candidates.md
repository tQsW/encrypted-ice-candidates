---
title: Encrypting ICE candidates to improve privacy and connectivity
docname: draft-wang-mmusic-encrypted-ice-candidates-latest
abbrev: encrypted-ice-candidates
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
  RFC2119:
  RFC6052:
  RFC6762:
  RFC8445:
informative:
  AES:
    title: Specification for the Advanced Encryption Standard (AES)
    author:
      organization: National Institute of Standards and Technology
    seriesinfo:
      FIPS: 197
    date: 2001-11-26
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
  ICESDP:
    target: https://tools.ietf.org/html/draft-ietf-mmusic-ice-sip-sdp
    title: Session Description Protocol (SDP) Offer/Answer procedures for
           Interactive Connectivity Establishment (ICE)
    author:
      ins: M. Petit-Huguenin
      ins: S. Nandakumar
      ins: A. Keranen
    date: 2019-08-13

--- abstract

WebRTC applications collect ICE candidates as part of the process of creating
peer-to-peer connections. To maximize the probability of a direct peer-to-peer
connection, client private IP addresses can be included in this candidate
collection, but this has privacy implications. This document describes a way to
share local IP addresses with local peers without compromising client privacy.
During the ICE process, local IP addresses are encrypted and authenticated using
a pre-shared key (PSK) and cipher suite. When encoding the candidate attribute
for an encrypted address, the connection-address field is set to 0.0.0.0, and
two extension fields are added to convey informaton related to the encrypted
address. The "ciphertext" field provides the ciphertext of an address and the
"cryptoparams" field signals identifiers that a peer can use to discover the PSK
and cipher suite associated with the ciphertext. Addresses that are shared as
above can be decrypted and used normally in ICE processing by peers that support
the above mechanism.

--- middle

Introduction {#problems}
============

The technique detailed in {{MdnsCandidate}} provides a method to share local IP
addresses with other clients without exposing client private IP to applications.
Given the fact that the application may control the signaling servers,
STUN/TURN servers, and even the remote peer implementation, the locality of the
out-of-band mDNS signaling can be considered the sole source of trust between
peers to share local IPs. However, mDNS messages are by default
scoped to local links {{RFC6762}}, and may not be enabled to traverse subnets
in certain networking environments. These environments may experience
frequent failures in mDNS name resolution and significant connectivity
challenges as a result. On the other hand, endpoints in these environments are
typically managed, in such a way that information can be securely pushed and
shared, including a pre-shared key and its associated cipher suite.

This document proposes a complementary solution for managed networks to share
local IP addresses over the signaling channel without compromising client
privacy. Specifically, addresses are encrypted with pre-shared key (PSK) cipher
suites, and encoded with two extension fields to signal the ciphertext and its
associated PSK and cipher suite, with the connection-address field set to
0.0.0.0.

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

ICE agents that implement this proposal pre-share keys for cipher suites
based on symmetric-key algorithms. The mechanism of sharing such information
is outside the scope of this document, but viable mechanisms exist in browsers
today.

The implementation MUST support the
Advanced Encryption Standard (AES) {{AES}} algorithm and its operation in the
CTR, CBC or GCM mode with message authentication, and SHOULD use the GCM mode
whenever it is supported. The implementation MUST pre-determine a single mode
to use as part of the mechanism to share the information about the cipher suite.
When using the CTR or CBC mode, HMAC with SHA-2 MUST be supported.

Since the plaintext to encrypt consists of only a single IPv4 or IPv6 address
that fits in a single 128-bit block, the initialization parameter for each mode
can be a cryptographically random number. In particular, this parameter is given
by a 16-byte initial counter block value for CTR, or a 16-byte or 12-byte
initialization vector for CBC or GCM, respectively.

Note the ICE password associated with an ICE agent has at least 128-bit
randomness as defined by {{RFC8445}}. To reduce the overhead in the candidate
encoding that will be detailed in the next section, the initialization parameter
MUST be chosen as the first 16 bytes or 12 bytes in the network order for the
mode in use.

ICE Candidate Gathering {#gathering}
------------------------------------

This section outlines how a PSK cipher suite should be used by ICE agents to
conceal local IP addresses.

### Procedure

For each host candidate gathered by an ICE agent as part of the gathering
process described in {{RFC8445}}, Section 5.1.1, the candidate is handled as
described below.

1. Check whether the IP address satisfies the ICE agent’s policy regarding
   whether an address is safe to expose. If so, expose the candidate and abort
   this process.

2. Generate the encrypted address.
   1. Let *address* be the IP address of the candidate, and embed it as an IPv6
      address if it is an IPv4 address, using the "Well-Known Prefix" as
      described in {{RFC6052}}.
   2. Let *ciphersuite* be the pre-determined cipher suite and its
      initialization parameter, and *key* the PSK.
   3. Let *EncryptAndAuthenticate(plaintext, ciphersuite, key)* be an operation
      that uses the given cipher suite to encrypt a given plaintext with
      authentication, and returns concatenated ciphertext and message
      authentication code (MAC).
   4. Compute *encrypted_address* as the output of
      *EncryptAndAuthenticate(address, ciphersuite, key)*.

3. Generate the candidate attribute as defined in {{ICESDP}}, followed by the
   procedure below before providing it to the application.
   1. Reset the connection-address field to 0.0.0.0.
   2. Encode *encrypted_address* from step 2 to a base64 string.
   3. Append a ciphertext field to the candidate attribute with its value given
      by the encoded *encrypted_address*.
   4. Append zero or more crypto parameter fields with values that are
      applicable to the peer to identify the PSK and cipher suite used to
      generate the ciphertext.

### Grammar and Example

This document defines two extension fields for the candidate attribute, namely
the ciphertext and the crypto parameters. Let ciphertext-ext and
cryptoparams-ext be two cand-extensions as defined in {{ICESDP}}.

  ciphertext-ext  = ciphertext SP \<ciphertext-base64\>  
  cryptoparam-ext = cryptoparams SP \<crypto-params\>  
  crypto-params   = \<param-name\> SP 1\*alpha-numeric SP \<param-name\> SP 1\*alpha-numeric ...

\<ciphertext-base64-val\>: is the ciphertext as a base64-encoded string.

\<param-name\>: is the name of a crypto parameter. In this document, we
define two parameters, namely "keyid" and "csid", to convery identifiers to
discover the PSK and cipher suite that generate the ciphertext.

The cryptoparams field MUST NOT be used in the absence of the ciphertext field.

Following the procedure in Section {{gathering}}, the candidate attribute in an
SDP message to exchange an encrypted candidate can be given by

  a=candidate:1 1 udp 2122262783 0.0.0.0 56622 typ host
    ciphertext jJvQO7elp2pYA+68aI8DiPqZGsvfEW9rcv06eBF0zVg=
    cryptoparams keyid icepsk0 csid aes-gcm

This example assumes the use of the GCM mode, in
which case the 256-bit *encrypted_address* consists of 128-bit ciphertext and
128-bit MAC, and can be encoded to 44 base64 characters.

### Implementation Guideline

TODO

ICE Candidate Processing {#processing}
-------------------------------------

This section outlines how received ICE candidates with encrypted addresses are
processed by ICE agents, and is relevant to all endpoints.

For any remote ICE candidate received by the ICE agent, the following procedure
is used.

1. If the connection-address field of the ICE candidate is not given by 0.0.0.0
   or there is no ciphertext field in the candidate, then process the candidate
   as defined in {{RFC8445}} or {{MdnsCandidate}}.

2. If the ICE agent has no default PSK cipher suite for encrypted candidates if
   there is no cipherparams field, or if its value does not refer to a PSK and
   cipher suite, proceed to step 5.

3. Decrypt the address as follows.
   1. Let *AuthenticateAndDecrypt(ciphertext_and_mac, ciphersuite, key)* be an
      operation using the given cipher suite to authenticate and decrypt a given
      ciphertext with MAC, and returns the decrypted value, or an
      fail-to-decrypt (FTD) error.
   2. Let *encrypted_address* be the value of the ciphertext field.
   3. Let *decrypted_address* be given by
      *AuthenticateAndDecrypt(encrypted_address)*. If *decrypted_address* does
      not represent a valid IPv6 address or an embedded IPv4 address, or an FTD
      error is raised, proceed to step 5.
   4. Convert *decrypted_address* to an IPv4 address if it is embedded.

4. Replace the connection-address field of the ICE candidate with
   *decrypted_address*, skip the rest steps and continue processing of the
   candidate as described in {{RFC8445}}.

5. Discard the candidate, or proceed to step 6 if the ICE agent implements
   {{MdnsCandidate}}.

6. Let *encrypted_address* be the same value as defined in step 3. Construct an
   mDNS name given by "*encrypted_address.local*", and proceed to step 2 in
   Section 3.2.1 in {{MdnsCandidate}}.

ICE agents can implement this procedure in any way as long as it produces
equivalent results.

Security Considerations {#security}
=======================

mDNS Message Flooding via Fallback Resolution
--------------------------------------------

Encrypted candidates can be spoofed and signaled to an ICE agent to trigger the
fallback mDNS resolution as described in step 6 in {{processing}}. This can
potentially generate excessive traffic in the subnet. Note however that
implementations of {{MdnsCandidate}} are required to have a proper rate
limiting scheme of mDNS messages.

IANA Considerations
===================

This document requires no actions from IANA.
