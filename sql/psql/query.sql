-- name: GetAuthor :one
SELECT
  *
FROM
  authors
WHERE
  id = $1
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
  authors.created_at > sqlc.arg (after)
ORDER BY
  name;

-- name: CreateAuthor :execresult
INSERT INTO
  authors (name, bio)
VALUES
  ($1, $2);

-- name: DeleteAuthor :exec
DELETE FROM authors
WHERE
  id = $1;

-- name: CountAuthors :many
SELECT
  count(*)
FROM
  authors;
