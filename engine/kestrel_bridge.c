/* kestrel_bridge.c — Tier 1 seam between Gullwing and colibrì's glm.c.
 *
 * STUB MODE (default): compiles standalone, returns canned replies so the
 * LuaJIT FFI path, registry selection and CI gate can be tested BEFORE the
 * engine wiring lands.
 *
 * EMBEDDED MODE (-DCOLIBRI_EMBEDDED): wire colibrì's forward pass in at the
 * ADAPT blocks below. glm.c is a self-contained program with its own main();
 * embedding means either (a) refactoring a kestrel_* entry set out of it —
 * a candidate upstream contribution to colibrì — or (b) compiling glm.c
 * with KESTREL_AS_LIB defined to rename/skip main().
 */
#include "kestrel_bridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef COLIBRI_EMBEDDED
/* ADAPT: include colibrì internals for the embedded build:
 *   #include "../vendor/colibri/c/glm.c"   (single-file engine)
 * and expose: shards_open(), forward(), sample() equivalents.
 */
#endif

struct kestrel {
    kestrel_cfg_t cfg;
    int           ready;
#ifdef COLIBRI_EMBEDDED
    /* ADAPT: engine state — Cfg, shards, ESlot cache, KVState, etc. */
    void *engine;
#endif
};

const char *kestrel_version(void) {
#ifdef COLIBRI_EMBEDDED
    return "kestrel 0.2.0 (embedded/colibri)";
#else
    return "kestrel 0.1.0 (stub)";
#endif
}

kestrel_t *kestrel_open(const kestrel_cfg_t *cfg) {
    if (!cfg || !cfg->model_dir) return NULL;
    kestrel_t *k = calloc(1, sizeof(*k));
    if (!k) return NULL;
    k->cfg = *cfg;

#ifdef COLIBRI_EMBEDDED
    /* ADAPT: load config + resident tensors within ram_budget_mb:
     *   - parse config.json, tokenizer
     *   - mmap shards from cfg->model_dir
     *   - size LRU expert cache + hot-store from remaining budget
     */
    k->ready = 1;
#else
    /* Stub mode: pretend success if the directory exists */
    FILE *probe = fopen(cfg->model_dir, "r");
    if (probe) { fclose(probe); k->ready = 1; }
    else {
        /* directories: fopen fails; treat as ok in stub mode */
        k->ready = 1;
    }
#endif
    return k;
}

void kestrel_close(kestrel_t *k) {
    if (!k) return;
#ifdef COLIBRI_EMBEDDED
    /* ADAPT: free expert slots, unmap shards, drop KV cache */
#endif
    free(k);
}

int kestrel_ask(kestrel_t *k, const char *prompt, kestrel_reply_t *out) {
    if (!k || !k->ready || !prompt || !out) return -1;
    clock_t t0 = clock();

#ifdef COLIBRI_EMBEDDED
    /* ADAPT: tokenize prompt -> prefill (teacher-forced path exists in
     * glm.c) -> decode loop with router-lookahead expert prefetch ->
     * detokenize into out->text. Honour cfg.max_tokens, temperature. */
    (void)prompt;
    out->text = strdup("(embedded engine not yet wired)");
#else
    /* Stub: echo a grounded placeholder so the FFI path is testable */
    char buf[512];
    snprintf(buf, sizeof buf,
             "[kestrel-stub] prompt received (%zu bytes); embedded engine "
             "not wired — see ADAPT blocks in kestrel_bridge.c",
             strlen(prompt));
    out->text = strdup(buf);
#endif

    out->tokens = 0;
    out->elapsed_ms = (clock() - t0) * 1000 / CLOCKS_PER_SEC;
    return out->text ? 0 : -1;
}

void kestrel_free_reply(kestrel_reply_t *reply) {
    if (reply && reply->text) { free((void *)reply->text); reply->text = NULL; }
}

int kestrel_stats_json(kestrel_t *k, char *buf, size_t cap) {
    if (!k || !buf || cap == 0) return -1;
#ifdef COLIBRI_EMBEDDED
    /* ADAPT: expert hit-rate, resident bytes, streamed bytes, prefetch
     * misses — the numbers auditors love. */
    return snprintf(buf, cap, "{\"engine\":\"kestrel\",\"mode\":\"embedded\"}");
#else
    return snprintf(buf, cap, "{\"engine\":\"kestrel\",\"mode\":\"stub\"}");
#endif
}
