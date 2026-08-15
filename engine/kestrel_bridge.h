/* kestrel_bridge.h — Gullwing's stable C ABI over the colibrì engine.
 *
 * This header is OWNED BY GULLWING: colibrì internals may churn, this
 * interface may not. LuaJIT FFI binds against this file only.
 *
 * License: MIT (Gullwing additions). colibrì itself remains Apache-2.0.
 */
#ifndef KESTREL_BRIDGE_H
#define KESTREL_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct kestrel kestrel_t;

typedef struct {
    const char *model_dir;     /* e.g. /mnt/d/models/glm-5.2          */
    int         max_tokens;    /* generation cap                      */
    float       temperature;   /* 0.0 for deterministic audit answers */
    int64_t     ram_budget_mb; /* resident budget; rest streams       */
} kestrel_cfg_t;

typedef struct {
    const char *text;          /* generated text (NUL-terminated)     */
    int64_t     tokens;        /* tokens produced                     */
    int64_t     elapsed_ms;
} kestrel_reply_t;

/* Lifecycle */
const char *kestrel_version(void);
kestrel_t  *kestrel_open(const kestrel_cfg_t *cfg);
void        kestrel_close(kestrel_t *k);

/* Single-shot audit question — the Gullwing `ask` path */
int kestrel_ask(kestrel_t *k, const char *prompt, kestrel_reply_t *out);
void kestrel_free_reply(kestrel_reply_t *reply);

/* Diagnostics for the evidence bundle */
int kestrel_stats_json(kestrel_t *k, char *buf, size_t cap);

#ifdef __cplusplus
}
#endif
#endif /* KESTREL_BRIDGE_H */
