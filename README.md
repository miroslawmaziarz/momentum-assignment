# Library Management API

A JSON API for library staff to track the books the library owns, the readers who borrow
them, and the loans that connect the two — including automatic return reminders three days
before and on the due date.

Built for the Momentum Ruby on Rails recruitment task. Ruby 3.4 / Rails 8.1 (API-only) /
PostgreSQL 16 / RSpec, delivered as a `docker compose up` one-liner.

---

## Quick start

```bash
docker compose up
```

That builds the image, waits for PostgreSQL, creates and migrates the database, seeds demo
data and boots the API on <http://localhost:3000>. No host Ruby or PostgreSQL needed.

```bash
curl localhost:3000/health          # {"status":"ok","database":"connected"}
curl localhost:3000/books           # the seeded catalogue
```

Ports are configurable if 3000 or 5434 are taken: `APP_PORT=3001 DB_PORT=5555 docker compose up`.

### Seeded data

Seeds exist so every endpoint and both reminder types can be exercised immediately. They
are idempotent — re-running `db:seed`, or booting on an existing volume, changes nothing.

| Serial   | Title                         | State                              |
| -------- | ----------------------------- | ---------------------------------- |
| `100001` | The Pragmatic Programmer      | available, never borrowed          |
| `100002` | Clean Code                    | borrowed by `200001`, **due in 3 days** |
| `100003` | The Design of Everyday Things | borrowed by `200002`, **due today** |
| `100004` | Domain-Driven Design          | available, one completed loan in its history |
| `100005` | Refactoring                   | available, never borrowed          |

Readers: `200001` Ada Lovelace, `200002` Grace Hopper, `200003` Alan Turing.

### Tests

```bash
docker compose exec app bin/rails spec
```

`bin/ci` additionally runs RuboCop, Brakeman and bundler-audit alongside the suite.

---

## API

Books and readers are addressed by the numbers physically printed on them — the six-digit
serial number and library card number

| Verb     | Path                                       | Purpose                                            |
| -------- | ------------------------------------------ | -------------------------------------------------- |
| `GET`    | `/books`                                   | Catalogue, each book with `available` / `borrowed` |
| `GET`    | `/books/:serial_number`                    | One book with its full borrowing history            |
| `POST`   | `/books`                                   | Add a book                                          |
| `DELETE` | `/books/:serial_number`                    | Delete a book (refused while it is out on loan)     |
| `PATCH`  | `/books/:serial_number`                    | Set status directly: `borrowed` / `available`       |
| `POST`   | `/books/:serial_number/borrowings`         | Lend the book to a reader                           |
| `POST`   | `/books/:serial_number/borrowings/return`  | Return the open loan                                |
| `GET`    | `/readers`, `/readers/:card_number`        | Find a reader                                       |
| `POST`   | `/readers`                                 | Register a reader                                   |
| `GET`    | `/up`, `/health`                           | Liveness (app booted) / readiness (database reachable) |

### Walkthrough

```bash
# 1. Add a book. Omit serial_number and the system assigns an unused one.
curl -X POST localhost:3000/books -H 'Content-Type: application/json' \
  -d '{"book":{"serial_number":"123456","title":"Dune","author":"Frank Herbert"}}'

# 2. Register a reader.
curl -X POST localhost:3000/readers -H 'Content-Type: application/json' \
  -d '{"reader":{"card_number":"654321","full_name":"Ada Lovelace","email":"ada@example.com"}}'

# 3. Lend it. The 30-day due date is computed server-side; clients cannot set it.
curl -X POST localhost:3000/books/123456/borrowings -H 'Content-Type: application/json' \
  -d '{"card_number":"654321"}'

# 4. The catalogue now shows it as borrowed, and the book shows its history.
curl localhost:3000/books
curl localhost:3000/books/123456

# 5. Return it.
curl -X POST localhost:3000/books/123456/borrowings/return

# The PATCH alias does the same two things through one door:
curl -X PATCH localhost:3000/books/123456 -H 'Content-Type: application/json' \
  -d '{"status":"borrowed","card_number":"654321"}'
curl -X PATCH localhost:3000/books/123456 -H 'Content-Type: application/json' \
  -d '{"status":"available"}'
```

`GET /books/:serial_number` returns the book with its history, most recent loan first:

```json
{
  "serial_number": "100004",
  "title": "Domain-Driven Design",
  "author": "Eric Evans",
  "status": "available",
  "history": [
    {
      "serial_number": "100004",
      "borrowed_at": "2026-07-17T09:00:00.000Z",
      "due_at": "2026-08-16T09:00:00.000Z",
      "returned_at": "2026-08-01T09:00:00.000Z",
      "reader": {
        "card_number": "200003",
        "full_name": "Alan Turing",
        "email": "alan.turing@example.com"
      }
    }
  ]
}
```

### Errors

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Validation failed: Serial number must be exactly six digits",
    "details": { "serial_number": ["must be exactly six digits"] }
  }
}
```

| Status | When                                                                              |
| ------ | --------------------------------------------------------------------------------- |
| `404`  | Unknown serial or card number                                                     |
| `422`  | Validation failures, and rule violations: lending a borrowed book, returning one that is not out, deleting one that is out |
| `400`  | Missing required parameter, or a body that is not parseable JSON                   |

---

## Architecture

### Layers

```
HTTP  →  Controller  →  Service        →  Model / DB
                        (Borrowings::   (Book, Reader,
         thin: find,     LendBook,       Borrowing +
         delegate,       ReturnBook)     constraints)
         serialize
                     ↘  Serializer  →  JSON

Solid Queue (recurring, daily) → ReturnReminderJob → ReminderMailer
```

### Data model

```
books                       borrowings                        readers
─────                       ──────────                        ───────
id            ◄──── FK ──── book_id      (cascade delete)     id  ────┐
serial_number (unique)      reader_id    ──────── FK ────────────────►┘
title                       borrowed_at                       card_number (unique)
author                      due_at                            full_name
                            returned_at  (NULL = still out)   email (unique, case-insensitive)
                            due_soon_reminder_sent_at
                            due_today_reminder_sent_at

         UNIQUE (book_id) WHERE returned_at IS NULL   ← the load-bearing constraint
```

## Repository map

```
app/controllers   thin HTTP layer + the shared error envelope
app/services      Borrowings::LendBook, Borrowings::ReturnBook
app/models        Book, Reader, Borrowing; SixDigitBusinessKey concern
app/serializers   plain-Ruby JSON shaping
app/jobs          ReturnReminderJob
app/mailers       ReminderMailer + views (previews in spec/mailers/previews)
```
