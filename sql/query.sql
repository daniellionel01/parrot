-- name: GetAuthor :one
SELECT
  *
FROM
  authors
WHERE
  id = ?
LIMIT
  1;

-- name: ListAuthors :many
-- additional comments!
SELECT
  *
FROM
  authors
ORDER BY
  name;

-- name: NewAuthorsSince :many
SELECT
  *
FROM
  authors
WHERE
  authors.created_at > ?
ORDER BY
  name;

-- name: CreateAuthor :execresult
INSERT INTO
  authors (name, bio)
VALUES
  (?, ?);

-- name: DeleteAuthor :exec
DELETE FROM authors
WHERE
  id = ?;

-- name: CountAuthors :many
SELECT
  count(*)
FROM
  authors;
