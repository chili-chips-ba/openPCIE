// wavecrux_decoder.h — C-ABI header for the WaveCrux user-contributed
// decoder plugin system.
//
// A "decoder plugin" is a native shared library (.so / .dylib / .dll) built
// against this header. It declares one or more protocol decoders that the
// WaveCrux loader discovers at startup, registers into the
// `DecoderRegistry`, and feeds raw signal samples to.
//
// This file is the binding contract between WaveCrux and any plugin author.
// Compatible plugins can be written in any language that emits a stable C
// ABI (C, C++, Rust, Zig, …). Authors compile against this header and ship
// the resulting library.
//
// Status: Experimental, ABI version 1.1. This contract follows the
// versioning policy described in `CONTRIBUTING.md` ("Contributing a decoder
// plugin"). The short version:
//
//   * MAJOR version: incompatible changes (struct layout, semantics).
//     The loader rejects plugins built against a different MAJOR version.
//   * MINOR version: backward-compatible additions (new trailing struct
//     fields, new optional callbacks). New trailing fields default to
//     zero / NULL when an older plugin is loaded by a newer host. Plugins
//     compiled against an older minor version continue to work without
//     recompilation.
//
// Threading model
// ---------------
// The loader invokes `wavecrux_decoder_register`, `create`, `feed`, `flush`,
// and `destroy` single-threaded **per plugin handle**. Different plugins
// may be invoked concurrently on different threads. A plugin must not
// assume that all its handles share a thread.
//
// Lifetime and memory ownership
// -----------------------------
// All `const char*` strings stored in `WcDecoderDef` (id, display_name,
// manifest_json) are **borrowed by the loader** for the lifetime of the
// plugin's shared library — i.e. until the loader unloads the library at
// app shutdown or via "Reload plugins". The plugin owns these strings and
// must keep them valid for that entire window. Static string literals in
// the plugin's `.rodata` section are the simplest way to satisfy this
// requirement.
//
// Per-call output (transactions returned via `feed` / `flush`) follows a
// different rule. The plugin **owns** every `WcTransaction` it returns
// until the next call (or `destroy`) on the same handle, at which point
// the loader must have copied the transaction's strings out. In practice
// this means: the plugin can reuse a single buffer to emit transactions
// across calls, as long as it does not free or overwrite the previous
// batch before the loader has consumed it.
//
// The loader treats `WcDecoderDef` callbacks as opaque function pointers.
// It will never try to free, copy, or otherwise manipulate the callback
// addresses themselves.
//
// Forward compatibility
// ---------------------
// The host always reads exactly as many trailing struct fields as its own
// MINOR version defines. When an older plugin (compiled against an earlier
// MINOR version) returns a smaller struct, the host fills the missing
// trailing fields with zero. New optional callbacks added in a MINOR bump
// must therefore tolerate being NULL.
//
// Conversely, a newer plugin loaded by an older host: the host only reads
// the prefix of the struct it knows about; trailing fields the plugin
// added are silently ignored. Any feature the host doesn't know about is
// inert.
//
// MAJOR version bumps are rare and accompanied by a migration guide.

#ifndef WAVECRUX_DECODER_H
#define WAVECRUX_DECODER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ── ABI version ────────────────────────────────────────────────────────────
//
// Plugins must publish the ABI version they were built against via the
// `wavecrux_decoder_abi_version` entry point. The loader rejects plugins
// whose MAJOR component does not match the host's MAJOR.

#define WAVECRUX_DECODER_ABI_MAJOR 1
#define WAVECRUX_DECODER_ABI_MINOR 1

// The combined version word: (MAJOR << 16) | MINOR. Returned by
// `wavecrux_decoder_abi_version`. Use the helper macros
// `WAVECRUX_DECODER_ABI_GET_MAJOR(v)` / `_MINOR(v)` to decode.
#define WAVECRUX_DECODER_ABI_VERSION \
    ((((uint32_t)WAVECRUX_DECODER_ABI_MAJOR) << 16) | \
     ((uint32_t)WAVECRUX_DECODER_ABI_MINOR))

#define WAVECRUX_DECODER_ABI_GET_MAJOR(v) (((uint32_t)(v) >> 16) & 0xFFFFu)
#define WAVECRUX_DECODER_ABI_GET_MINOR(v) ((uint32_t)(v) & 0xFFFFu)

// ── return codes ──────────────────────────────────────────────────────────
//
// Used by `wavecrux_decoder_register` and the lifecycle callbacks. The
// loader treats any non-zero value from a callback as a fatal error for
// the affected handle (it will not be invoked further); the registration
// entry point reports success with 0 and an out-of-buffer condition with
// `WC_DECODER_NEED_MORE_SLOTS`.

#define WC_DECODER_OK                  0
#define WC_DECODER_ERR                 1
#define WC_DECODER_NEED_MORE_SLOTS     2

// ── opaque types ──────────────────────────────────────────────────────────

// Per-decoder-instance handle returned by `WcDecoderCreateFn`. The
// loader treats this as an opaque pointer; only the plugin's own
// callbacks dereference it.
typedef void* WcDecoderHandle;

// ── value types crossing the FFI boundary ──────────────────────────────────

// One sample of bit-level signal data.
//
// `bits_ptr` points to a packed-LSB-first bit array of length `bit_width`.
// Each byte holds up to 8 bits; the trailing high bits of the final byte
// are unspecified for `bit_width` not divisible by 8 — plugins must mask
// them when reading. Special values (0/1/x/z) for VCD-style 4-state data
// are encoded by the loader using two bits per signal bit (low bit =
// value, high bit = "unknown"), but plugin authors can treat the buffer
// as opaque and only consume what their decoder needs.
//
// The pointer is valid only for the duration of the `feed` call. The
// loader may reuse the buffer after the call returns.
typedef struct WcSample {
    uint64_t       timestamp_fs;  // Sample timestamp, femtoseconds.
    const uint8_t* bits_ptr;      // Packed bit data, LSB-first.
    uint32_t       bit_width;     // Number of valid bits.
    uint32_t       _reserved0;    // Pad to 8-byte alignment; must be zero.
} WcSample;

// One decoded transaction emitted by the plugin.
//
// `label` is a short user-facing label (e.g. "MWr32 [0x1000] DW=0xDEAD").
// `fields_json` is a UTF-8 JSON object string describing structured
// fields — the same shape the open-core decoders emit through
// `DecodedTransaction.fields`. Both strings are owned by the plugin and
// must remain valid until the next call on the same handle.
typedef struct WcTransaction {
    uint64_t    start_fs;     // Transaction start time, femtoseconds.
    uint64_t    end_fs;       // Transaction end time, femtoseconds.
    const char* label;        // Short display label, UTF-8 NUL-terminated.
    const char* fields_json;  // Structured fields, UTF-8 JSON object.
    uint32_t    is_error;     // Non-zero if this transaction is a flagged
                              // protocol violation.
    uint32_t    _reserved0;   // Pad to 8-byte alignment; must be zero.
} WcTransaction;

// ── lifecycle callback signatures ─────────────────────────────────────────
//
// All callbacks are invoked single-threaded per handle. A handle returned
// by `create` is passed back to `feed` / `flush` / `destroy` until
// `destroy` is invoked, after which the loader will not touch the handle
// again.
//
// `feed` and `flush` write decoded transactions through the
// `out_transactions` / `inout_count` out-parameters. The loader passes a
// buffer of length `*inout_count`; the plugin writes up to that many
// transactions and updates `*inout_count` to the number actually emitted.
// To emit more transactions than fit, the plugin returns
// `WC_DECODER_NEED_MORE_SLOTS` and the loader will retry with a larger
// buffer.

// Construct a decoder instance. `config_json` carries the JSON-encoded
// configuration for this instance:
//
//   {"decoder_id": "<WcDecoderDef.id>",
//    "signal_bindings": {"<signal name>": "<waveform signal path>", ...},
//    "parameters": {"<parameter name>": <value>, ...},
//    "options": {"<parameter name>": <value>, ...}}
//
// `decoder_id` names the decoder being instantiated, so one `create`
// shared by several decoders can tell them apart. `options` repeats
// `parameters`. Returns NULL on construction failure.
typedef WcDecoderHandle (*WcDecoderCreateFn)(const char* config_json);

// Feed one sample to the instance. The plugin may write zero or more
// transactions to `out_transactions`.
typedef int32_t (*WcDecoderFeedFn)(
    WcDecoderHandle handle,
    const WcSample* sample,
    WcTransaction*  out_transactions,
    size_t*         inout_count);

// Flush any pending state at end-of-stream. The plugin may emit final
// transactions. Called once after the last `feed` for this handle.
typedef int32_t (*WcDecoderFlushFn)(
    WcDecoderHandle handle,
    WcTransaction*  out_transactions,
    size_t*         inout_count);

// Destroy a decoder instance. The loader will not invoke any further
// callbacks on this handle after `destroy` returns.
typedef void (*WcDecoderDestroyFn)(WcDecoderHandle handle);

// ── decoder definition ────────────────────────────────────────────────────
//
// A plugin returns one or more `WcDecoderDef` entries from
// `wavecrux_decoder_register`. Each entry describes one decoder.

typedef struct WcDecoderDef {
    // Unique decoder identifier. Convention: lowercase, dot-separated,
    // namespaced under the plugin's own name (e.g. "examples.onewire").
    // Two decoders with the same id collide; the loader logs a warning
    // and the second registration is rejected.
    const char* id;

    // User-facing decoder name. UTF-8. Localization is the host's job —
    // plugins can ship a single English label or extend this in a future
    // MINOR bump if needed.
    const char* display_name;

    // JSON manifest declaring signal bindings, parameters, and protocol
    // metadata. Same shape the open-core `DecoderDefinition.toJson`
    // emits. Required keys: "signals" (array of {name, bit_width?,
    // optional?}), "parameters" (array of {name, kind, default?}).
    // Additional keys are reserved for forward extension.
    const char* manifest_json;

    // Lifecycle callbacks. All are required in ABI 1.0.
    WcDecoderCreateFn  create;
    WcDecoderFeedFn    feed;
    WcDecoderFlushFn   flush;
    WcDecoderDestroyFn destroy;

    // Reserved trailing fields default to NULL/zero in older plugins.
    // ABI 1.0 reserves these for future MINOR additions — plugins should
    // initialize them to zero.
    void*    _reserved0;
    uint64_t _reserved1;
} WcDecoderDef;

// ── required entry points ─────────────────────────────────────────────────
//
// Every plugin must export both of these symbols.

// Returns the ABI version the plugin was built against, encoded as
// `WAVECRUX_DECODER_ABI_VERSION`. The loader compares MAJOR components
// and rejects mismatches with a diagnostic in the Settings panel.
uint32_t wavecrux_decoder_abi_version(void);

// Populate `out_defs` (an array of `*inout_count` slots) with the
// decoders the plugin contributes. On entry, `*inout_count` is the
// number of slots the loader has provided. On return, `*inout_count` is
// the number of decoders actually written.
//
// Returns:
//   * `WC_DECODER_OK` on success.
//   * `WC_DECODER_NEED_MORE_SLOTS` when the plugin has more decoders
//     than slots provided. `*inout_count` is set to the total required
//     count, the buffer is left untouched, and the loader will retry.
//   * `WC_DECODER_ERR` on internal error; the loader will skip the
//     plugin and log the failure.
int32_t wavecrux_decoder_register(WcDecoderDef* out_defs,
                                  size_t*       inout_count);

// ── optional entry points (ABI 1.1+) ──────────────────────────────────────
//
// These symbols are OPTIONAL. The host resolves them by name and tolerates
// their absence — a plugin built against ABI 1.0 (or one that simply
// chooses not to export them) continues to load and behave exactly as
// before. They let a plugin that contributes many decoders present a
// single, meaningful identity in the Settings → Decoders plugin card,
// instead of the host falling back to the first decoder's display name.

// Returns a short, user-facing name for the plugin as a whole (e.g.
// "WaveCrux SigRok Bridge"), UTF-8 NUL-terminated. The host shows this as
// the plugin card title. Return NULL — or omit the symbol entirely — to
// let the host fall back to the first contributed decoder's display name.
//
// The returned string is borrowed by the host for the lifetime of the
// plugin's shared library, exactly like the strings in `WcDecoderDef`. A
// static string literal in `.rodata` is the simplest way to satisfy this.
const char* wavecrux_decoder_plugin_name(void);

// Returns a one-line description for the plugin (e.g. an origin or license
// notice), UTF-8 NUL-terminated, shown beneath the plugin name. Return
// NULL — or omit the symbol — to show nothing. Same borrowing rule as
// `wavecrux_decoder_plugin_name`.
const char* wavecrux_decoder_plugin_description(void);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // WAVECRUX_DECODER_H
