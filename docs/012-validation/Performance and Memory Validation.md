# Performance and Memory Validation

## Scope

Milestone: Performance, Memory, and Cancellation Hardening

Validated areas:
- Vault Home search cancellation and debounce
- Thumbnail request deduplication
- Bounded in-memory thumbnail cache
- Document import cancellation behavior
- Recovery package staging off the main actor
- Document import cancellation cleanup in SecureVaultKit

## Tested Operations

- Rapid search query changes cancel previous pending search work.
- Empty query cancels pending search and returns to normal listing.
- Concurrent thumbnail requests for the same object share one in-flight request.
- Thumbnail cache evicts older entries by item count and estimated byte limit.
- Document import cancellation avoids publishing imported UI state.
- SecureVaultKit document import checks cancellation between pipeline stages and deletes blobs written before cancellation.

## Simulator / Device

Build validation target:
- iOS Simulator, iPhone 16 Pro when available.
- If unavailable locally, use the installed iPhone simulator reported by Xcode.

## Test File Sizes

Automated tests use small fixture files only.

Manual large-file validation remains recommended with:
- 10 MB PDF
- 25 MB image
- 100 MB document-like binary fixture

## Memory Observations

- Thumbnail cache is now bounded with a default maximum of 128 items and an estimated 16 MB data limit.
- App ViewModels store lightweight view state and thumbnail display data only.
- Recovery package staging now copies files in chunks instead of reading the whole package into `Data` on the SwiftUI path.
- SecureVaultKit blob encryption and file copy paths use file URLs/chunked copy helpers.

## Cancellation Behavior

- Vault Home owns load/search/thumbnail tasks and cancels overlapping work.
- Search uses a 300 ms debounce and request identity checks so stale results cannot overwrite newer state.
- Object Detail cancels stale detail and thumbnail loads.
- Document Import owns inspect/import tasks and treats cancellation as non-failure UI state.
- Recovery Import owns staging/import tasks.
- SecureVaultKit document import checks cancellation between stages and removes blobs written before a cancelled import completes.

## Known Bottlenecks

- Legacy `BlobStore.writeBlob(from:)` remains a fake compatibility path and may still read small plaintext fixtures into memory; document import uses the encrypted file-output path instead.
- Thumbnail generation is fake/generic in this milestone and does not decode real high-resolution image thumbnails.
- Cancellation after a document object has been inserted but before attachment events complete is not fully transactional in all fake/in-memory paths.

## Remaining Risks

- Manual simulator memory profiling is still needed with large real PDFs/images.
- iOS test runner stability depends on the local simulator runtime.
- A future persistent encrypted thumbnail pipeline should keep the same in-memory-only plaintext cache boundary.

## Manual Checklist

- [ ] Rapidly type multiple search queries.
- [ ] Only latest result appears.
- [ ] Navigate away during object loading.
- [ ] No stale state update occurs.
- [ ] Start document import and cancel.
- [ ] No imported object appears.
- [ ] No temporary files remain.
- [ ] Scroll vault list with thumbnails.
- [ ] Memory does not grow continuously.
- [ ] Lock vault during thumbnail loading.
- [ ] Requests/cache are cleared safely.
