/* SPDX-License-Identifier: MIT */
#include <stdint.h>
#include <string.h>
#include "bearssl.h"

typedef struct {
    const br_x509_class *vtable;
    br_x509_decoder_context decoder;
    br_sha256_context hash;
    unsigned count;
    uint32_t leaf_length;
} pinned_certificate;

static pinned_certificate certificate;
static br_ssl_client_context client;
static br_x509_minimal_context unused_validator;
static unsigned char buffers[BR_SSL_BUFSIZE_BIDI];
static unsigned char entropy[32];
static unsigned char expected_pin[32];
static unsigned char peer_pin[32];
static unsigned char websocket_nonce[24];
static unsigned char websocket_digest[20];
static unsigned certificate_pinned;
static size_t buffer_length;

static void start_chain(const br_x509_class **ctx, const char *name)
{
    pinned_certificate *cert = (pinned_certificate *)ctx;
    (void)name;
    cert->count = 0;
    cert->leaf_length = 0;
    br_x509_decoder_init(&cert->decoder, NULL, NULL);
    br_sha256_init(&cert->hash);
}

static void start_cert(const br_x509_class **ctx, uint32_t length)
{
    pinned_certificate *cert = (pinned_certificate *)ctx;
    if (++cert->count == 1) cert->leaf_length = length;
}

static void append_cert(const br_x509_class **ctx, const unsigned char *data, size_t length)
{
    pinned_certificate *cert = (pinned_certificate *)ctx;
    if (cert->count == 1 && cert->leaf_length <= 16384) {
        br_x509_decoder_push(&cert->decoder, data, length);
        br_sha256_update(&cert->hash, data, length);
    }
}

static void end_cert(const br_x509_class **ctx)
{
    (void)ctx;
}

static unsigned end_chain(const br_x509_class **ctx)
{
    pinned_certificate *cert = (pinned_certificate *)ctx;
    if (!cert->leaf_length || cert->leaf_length > 16384) return BR_ERR_X509_LIMIT_EXCEEDED;
    if (!br_x509_decoder_get_pkey(&cert->decoder)) return BR_ERR_X509_INVALID_VALUE;
    br_sha256_out(&cert->hash, peer_pin);
    if (certificate_pinned && memcmp(peer_pin, expected_pin, sizeof peer_pin)) {
        return BR_ERR_X509_NOT_TRUSTED;
    }
    return 0;
}

static const br_x509_pkey *get_pkey(const br_x509_class *const *ctx, unsigned *usages)
{
    (void)ctx;
    if (usages) *usages = BR_KEYTYPE_SIGN;
    return br_x509_decoder_get_pkey(&certificate.decoder);
}

static const br_x509_class certificate_vtable = {
    sizeof certificate, start_chain, start_cert, append_cert, end_cert, end_chain, get_pkey
};

unsigned char *tls_entropy(void) { return entropy; }
unsigned char *tls_expected_pin(void) { return expected_pin; }
unsigned char *tls_peer_pin(void) { return peer_pin; }
unsigned char *tls_websocket_nonce(void) { return websocket_nonce; }

unsigned char *tls_websocket_digest(void)
{
    static const char magic[] = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    br_sha1_context hash;
    br_sha1_init(&hash);
    br_sha1_update(&hash, websocket_nonce, sizeof websocket_nonce);
    br_sha1_update(&hash, magic, sizeof magic - 1);
    br_sha1_out(&hash, websocket_digest);
    return websocket_digest;
}

int tls_init(int use_pin)
{
    static const uint16_t suites[] = {
        BR_TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,
        BR_TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
        BR_TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
        BR_TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
        BR_TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
        BR_TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
        BR_TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,
        BR_TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,
        BR_TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,
        BR_TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,
        BR_TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,
        BR_TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,
        BR_TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,
        BR_TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
    };

    certificate.vtable = &certificate_vtable;
    certificate_pinned = use_pin;
    memset(peer_pin, 0, sizeof peer_pin);
    br_ssl_client_init_full(&client, &unused_validator, NULL, 0);
    br_ssl_engine_set_x509(&client.eng, &certificate.vtable);
    br_ssl_engine_set_versions(&client.eng, BR_TLS12, BR_TLS12);
    br_ssl_engine_set_suites(&client.eng, suites, sizeof suites / sizeof suites[0]);
    br_ssl_engine_add_flags(&client.eng, BR_OPT_NO_RENEGOTIATION);
    br_ssl_engine_set_buffer(&client.eng, buffers, sizeof buffers, 1);
    br_ssl_engine_inject_entropy(&client.eng, entropy, sizeof entropy);
    memset(entropy, 0, sizeof entropy);
    return br_ssl_client_reset(&client, NULL, 0);
}

unsigned tls_state(void) { return br_ssl_engine_current_state(&client.eng); }
int tls_error(void) { return br_ssl_engine_last_error(&client.eng); }
size_t tls_size(void) { return buffer_length; }

unsigned char *tls_buffer(unsigned state)
{
    buffer_length = 0;
    switch (state) {
    case BR_SSL_SENDREC: return br_ssl_engine_sendrec_buf(&client.eng, &buffer_length);
    case BR_SSL_RECVREC: return br_ssl_engine_recvrec_buf(&client.eng, &buffer_length);
    case BR_SSL_SENDAPP: return br_ssl_engine_sendapp_buf(&client.eng, &buffer_length);
    case BR_SSL_RECVAPP: return br_ssl_engine_recvapp_buf(&client.eng, &buffer_length);
    default: return NULL;
    }
}

void tls_ack(unsigned state, size_t length)
{
    switch (state) {
    case BR_SSL_SENDREC: br_ssl_engine_sendrec_ack(&client.eng, length); break;
    case BR_SSL_RECVREC: br_ssl_engine_recvrec_ack(&client.eng, length); break;
    case BR_SSL_SENDAPP:
        br_ssl_engine_sendapp_ack(&client.eng, length);
        br_ssl_engine_flush(&client.eng, 0);
        break;
    case BR_SSL_RECVAPP: br_ssl_engine_recvapp_ack(&client.eng, length); break;
    }
}
