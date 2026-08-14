---
name: python-perf
description: Python design thinking and performance recipes — package defaults (sanic/msgspec/loguru/polars…), class shape, data-structure / string-build / I/O / serialization selection, async patterns, SQL-in-Python. Use whenever writing, refactoring, or reviewing Python code, and before delegating Python implementation to a sub-agent.
---

# Python Performance Recipes

Environment is per-project: the active `.venv` (uv-managed) decides the Python version — 3.13 and 3.14 are both in use, so check before relying on 3.14-only syntax. Lint/format comes from the project's own ruff setup; don't assume a hook or editor config.

Examples are Python, but the selection logic (data-structure / string-build / I/O / SQL trade-offs) generalizes to other languages. When delegating Python implementation to a sub-agent, echo the relevant recipe lines into its prompt — sub-agents without the Skill tool cannot load this file. The 3.14 `except A, B:` red-line lives in the global CLAUDE.md (kept ambient so reviewer sub-agents see it); do not restate it here.

## Syntax

- Walrus `:=` on every get+check+use — single lookup only
- `is not None` for a fallback — `or` drops falsy values; combine with `:=` where applicable
- Native type hints (`dict[str, int]`) on all functions
- `zip(strict=True)` when lengths must match
- `str.removeprefix` / `removesuffix` over slicing or `lstrip` / `rstrip`
- Sort/get by key: `itemgetter('field')` over `lambda x: x['field']`
- Lazy import **only** for: (1) breaking circular imports (2) heavy modules in rarely-called functions — stdlib (`uuid`/`json`) and already-imported siblings don't qualify (the import cache makes lazy slower per call)
- Docstrings: Google style

## Selection

- Top-K (K<<N): `heapq.nlargest(k, items, key=...)` — O(n log k) · Dedupe+order: `list(dict.fromkeys(items))` · Grouping: `defaultdict(list)` · Ordered search: `bisect.bisect_left` — O(log n) · Counting: `fastcounter.Counter` (2× collections.Counter) · Integer sqrt: `math.isqrt(n)` — exact, faster than `math.sqrt`
- Containers: membership check (>2 items) `set` · head/tail ops `deque` · immutable sequence `tuple` · immutable set `frozenset` · numeric array `array.array` · dict merge `a |= b` (in-place) over `a | b` (new)
- Class shape: **msgspec.Struct** for JSON data needing validation · **NamedTuple** immutable + frequently read + no validation · **`__slots__`** for all other classes (add `'__weakref__'` if using WeakValueDictionary)
- String build: **≤10 groups** f-string · **11–100** `"".join()` · **>100** `io.StringIO`. Split via `text.splitlines()` over `split("\n")`; reuse `re.compile()` before use
- Generator vs list: small (≤1000) / multi-iter → list; large / single-iter → generator. In-place first: `data.sort()` over `sorted(data)`. Cache in loops (`n = len(data)`, `func = self.obj.method`); pre-allocate `[None] * size` when size is known
- Concurrency: CPU bound `ProcessPoolExecutor` · I/O bound `async/await` · blocking I/O `asyncio.to_thread()` · CPU+I/O mix async + ProcessPool for the CPU part · <10 tasks `asyncio.gather` · >10 `asyncio.Semaphore(N)` · complex flow Queue+worker · shared data `multiprocessing.shared_memory`
- asyncio Queue+worker shutdown: end via sentinel (never a timeout); on the sentinel, `queue.task_done()` BEFORE `break`
- I/O: large file `open(file, buffering=65536)` · random access `mmap.mmap()` · async `aiofiles`. JSON `msgspec` > stdlib · compression `zstd` > `gzip` · stream `zlib.compressobj()`. Pickle `pickle.HIGHEST_PROTOCOL`; built-in objects only `marshal` (faster than pickle)
- Serialization default is `msgspec.msgpack` (binary): several× faster encode+decode and a smaller file than JSON, and `msgspec.Struct` decodes it with no model change — so reaching for `json` is the deviation that needs a reason, not the default. Drop to JSON only when a human must read/diff the bytes or another system requires it. Reflex to flip when you see `json.dumps`/`msgspec.json.encode` on machine-only data — especially a per-write full-file rewrite (save-on-every-mutation), where the JSON cost compounds every write.
- itertools: flatten `chain.from_iterable(nested)` (or `tkinter._flatten()`, 2-5× faster private API) · unpack args `starmap(func, args_iter)` · batching `batched(data, n)` (3.12+) · stop on condition `takewhile(predicate, iterable)`
- Packages — default to these over their common equivalents: sanic (not FastAPI/Flask; FastAPI acceptable when its ecosystem outweighs raw perf), msgspec (not pydantic nor stdlib json), loguru (not logging), polars (not pandas), psqlpy (not asyncpg/psycopg), aiohttp (not requests/httpx), fastcounter (not collections.Counter), uvloop, zstd (not gzip), aiofiles, cachebox, async-lru, bm25s-j, faiss-cpu, hnswlib, jax[cpu], protobuf

## SQL

- Keep SQL strings comment-free (comments hurt the DB query cache); comment externally via Python concatenation
- SQLAlchemy `text()`: use `CAST(:param AS jsonb)` not `:param::jsonb` — `::` clashes with `:name` bind-parameter syntax
