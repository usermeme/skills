---
name: sql-and-migrations
description: Database discipline — safe schema migrations (expand/contract, lock awareness, reversibility), honest schema design with constraints in the database, and query patterns that survive production data volumes (indexing, N+1, keyset pagination, tight transactions). Use whenever writing SQL, designing or altering a schema, writing a migration, investigating a slow query, or reviewing a diff that contains migrations or query changes.
---

# SQL & Migrations

The database outlives every application version that talks to it, and a bad migration is the most expensive line in most PRs — it can lock a table under production traffic or destroy data with no undo. This skill is ordered by blast radius: migrations first.

**Precedence**: the project's migration tooling and naming conventions win. Postgres is assumed where dialects differ; verify before applying elsewhere.

## 1. Migrations — expand, migrate, contract

Schema changes deploy separately from the code that depends on them, in phases that are each backward-compatible with the running application:

1. **Expand** — add the new nullable column/table/index. Old code ignores it; new code can start writing it.
2. **Migrate** — backfill data (batched, not one giant UPDATE), start reading from the new shape behind the running code.
3. **Contract** — only after nothing reads the old shape: drop the old column/table, in its own later deploy.

Collapsing these into one deploy is how you get the outage where new schema meets old code (or the rollback that can't roll back).

Rules that follow:

- **Destructive operations never ride with the code change that stops using the thing.** `DROP COLUMN`/`DROP TABLE` ships days later, alone, after verification — it's the only part with no undo.
- Every migration states its rollback: a down-migration where possible, or an explicit "irreversible because X, mitigation Y" where not. Untested down-migrations are fiction; if you'd rely on it, try it.
- Migrations are idempotent-guarded (`IF NOT EXISTS` / tracked in a migrations table) — reruns after partial failure must be safe.
- Never edit an applied migration; add a new one. Applied history is immutable by contract with every environment that already ran it.

## 2. Locks — know what your DDL blocks

The migration that's instant on your 200-row dev table takes a table lock on 80M production rows.

- `CREATE INDEX` → use `CONCURRENTLY` (and know it can't run in a transaction; your tool may need it flagged).
- `ADD COLUMN ... DEFAULT` is cheap on modern Postgres (11+), but `ALTER COLUMN TYPE` usually rewrites the whole table under an exclusive lock — plan it as new-column + backfill + swap.
- `ADD NOT NULL` / foreign keys / check constraints on existing data: add as `NOT VALID`, then `VALIDATE CONSTRAINT` separately — validation scans without blocking writes.
- Set a `lock_timeout` for migrations so a blocked DDL fails fast instead of queueing behind a long transaction and stalling every query in the system.

## 3. Schema design — the database enforces truth

Application code changes weekly and has bugs; constraints don't.

- Constraints live in the database, not only in the app: foreign keys, `UNIQUE`, `NOT NULL`, `CHECK`. Every invariant enforced only in code is one deploy away from corrupt data.
- Honest types: `timestamptz` (never naive timestamps), `numeric` for money (never float), `text` over arbitrary `varchar(n)` limits, native `uuid`/`jsonb` over strings. Enum-like values: `CHECK` constraint or lookup table, documented either way.
- Name for the reader: singular-consistent or plural-consistent tables (match the project), `snake_case`, foreign keys as `<entity>_id`. Indexes named so `\d` output explains itself.
- Soft-delete, multi-tenancy, and audit columns are architectural decisions — consistent everywhere or nowhere, not per-table improvisation.

## 4. Queries that survive production

- **N+1 is the default failure of every loop that touches the DB.** A query inside a per-item loop becomes a join, a `WHERE id = ANY($1)` batch, or a preload. If the ORM hides the loop, log the SQL once and count.
- **Index for the query you actually run**: composite index column order follows equality-then-range usage (`WHERE repo = $1 ORDER BY created_at` → `(repo, created_at)`). A leading wildcard `LIKE`, a function on the column, or a type mismatch silently ignores the index.
- Verify with **`EXPLAIN ANALYZE` on realistic data volume**, not by reasoning about what the planner probably does. Optimizing without a plan in hand is guessing.
- **Keyset pagination** (`WHERE (created_at, id) < ($1, $2) ORDER BY ... LIMIT n`) over `OFFSET` for anything that grows — `OFFSET 100000` scans and discards 100k rows every page.
- Transactions: as short as possible, never spanning network calls or user think-time — long transactions hold locks and block vacuum. Choose explicit atomic statements (`ON CONFLICT`, `UPDATE ... RETURNING`) over check-then-act sequences ([TOCTOU](../code-review/references/security.md)).
- `SELECT` only the columns you use — `SELECT *` breaks under schema evolution and drags unneeded bytes through every layer.

## 5. Safety rails

- **Parameterize every value** (`$1`), never interpolate into query text — including identifiers built from config. See the injection checklist in [code-review/references/security.md](../code-review/references/security.md).
- Destructive statements against real data (`UPDATE`/`DELETE` without a fresh, verified `WHERE`… or any `DROP`/`TRUNCATE`): first run the same predicate as a `SELECT count(*)`, look at the number, and have a backup/snapshot story. As an agent, these are confirm-first operations, always.
- Test migrations against a realistic copy, not just an empty schema — the failure modes (locks, constraint violations in old data, timeout on backfill) only exist where data does.
