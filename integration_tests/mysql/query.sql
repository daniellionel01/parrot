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

-- name: AuthorPosts :many
SELECT
  *
FROM
  posts
  INNER JOIN authors on authors.id = posts.author_id
WHERE
  authors.id = ?;
